package com.example.seesay.ble

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import com.example.seesay.DiagLog
import com.example.seesay.GlassesRuntime
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * What the glasses buttons do, over BLE only (checked on the user's AIMB S2 Max):
 *
 *  black x1 → 1204 RequestAI. We answer Allow once, the glasses stream the question as Opus (1206).
 *             The end of the question is found by loudness (OpusVad), by 1205 02/03 or by a timeout;
 *             then StopRecord, the voice goes to Flutter (→ server) and a photo is requested at once
 *             (120A 01 → 120B, ~2 s) in case the question is about what the user sees.
 *  black x2 → the glasses send 120A 02 and a photo (120B) by themselves → "what is in front of me".
 *  red      → 120F per press (the glasses also save a photo/video to their card); Flutter counts presses.
 *
 * Everything runs on the main thread; only the Opus loudness check runs on its own thread.
 */
class GlassesSession(
    private val context: Context,
    private val send: (Int, ByteArray) -> Boolean,
) {
    private val main = Handler(Looper.getMainLooper())
    private val assembler = BkAssembler()
    private val vadThread = HandlerThread("seesay-vad").apply { start() }
    private val vadHandler = Handler(vadThread.looper)
    private var vad: OpusVad? = null
    private var vadBroken = false

    private var linked = false
    private var allowedAt = 0L
    private var endedAt = 0L
    private var voice: ByteArrayOutputStream? = null
    private var voiceToken = 0
    private var voicePackets = 0
    private var voiceStartedAt = 0L
    private var speechPackets = 0
    private var quietAfterSpeech = 0
    private var noiseFloor = Int.MAX_VALUE
    private var loudnessCount = 0
    private val loudnessTrace = StringBuilder()
    private var photoReason: String? = null
    private var photoRequestedAt = 0L
    private var lastBattery = -1

    fun onLinkReady() {
        linked = true
        assembler.reset()
        DiagLog.i(TAG, "link ready")
        send(BkProtocol.DEVICE_INITIALIZED, ByteArray(0))
        send(BkProtocol.GET_BATTERY, ByteArray(0))
        send(BkProtocol.GET_FIRMWARE, ByteArray(0))
    }

    fun onLinkLost() {
        linked = false
        assembler.reset()
        if (voice != null) finishVoice("link lost")
        photoReason = null
    }

    fun onBytes(bytes: ByteArray) {
        for (packet in assembler.feed(bytes)) {
            try {
                onPacket(packet)
            } catch (error: Exception) {
                DiagLog.e(TAG, "packet ${BkProtocol.name(packet.cmd)} failed", error)
            }
        }
    }

    /** Photo from the glasses camera over BLE; the answer comes as a glassesPhoto event. */
    fun requestPhoto(reason: String): Boolean {
        if (!linked) {
            DiagLog.w(TAG, "photo request ($reason) while glasses are not linked")
            return false
        }
        photoReason = reason
        photoRequestedAt = SystemClock.elapsedRealtime()
        DiagLog.i(TAG, "-> photo request ($reason)")
        return send(BkProtocol.AI_INTENT, byteArrayOf(BkProtocol.INTENT_VISUAL_QA.toByte()))
    }

    fun release() {
        vadHandler.post {
            vad?.release()
            vad = null
        }
        vadThread.quitSafely()
    }

    private fun onPacket(p: BkPacket) {
        if (p.cmd != BkProtocol.RECORD_DATA) DiagLog.i(TAG, "<- ${p.describe()}")
        if (p.isReply) {
            if (p.cmd == BkProtocol.GET_BATTERY) battery(p.payload)
            return
        }
        when (p.cmd) {
            BkProtocol.REQUEST_AI -> onRequestAi()
            BkProtocol.RECORD_CONTROL -> onRecordControl(p.payload.firstOrNull()?.toInt() ?: -1)
            BkProtocol.RECORD_DATA -> onVoice(p.payload)
            BkProtocol.AI_INTENT -> if (p.payload.firstOrNull()?.toInt() == BkProtocol.INTENT_PHOTO_RECOGNITION) {
                // Black button pressed twice: the glasses take the photo themselves.
                photoReason = "recognition"
                photoRequestedAt = SystemClock.elapsedRealtime()
                button("black", "double")
            }
            BkProtocol.INTENT_IMAGE -> onImage(p.payload)
            BkProtocol.PHOTO_BUTTON -> button("red", "press")
            BkProtocol.GET_BATTERY -> battery(p.payload)
            BkProtocol.WEARING -> GlassesRuntime.emit(
                mapOf("event" to "glassesWearing", "worn" to (p.payload.firstOrNull()?.toInt() == 1)),
            )
        }
    }

    // ---- voice

    private fun onRequestAi() {
        val now = SystemClock.elapsedRealtime()
        // The glasses repeat 1204 until the session is answered; Allow twice breaks the session.
        if (voice != null || now - allowedAt < REPEAT_IGNORE_MS || now - endedAt < AFTER_END_IGNORE_MS) {
            DiagLog.i(TAG, "1204 repeat ignored")
            return
        }
        allowedAt = now
        send(BkProtocol.REQUEST_AI, byteArrayOf(0, 0)) // Allow, VAD on the glasses
        startVoice()
        button("black", "press")
    }

    private fun startVoice() {
        voice = ByteArrayOutputStream()
        voiceToken += 1
        voicePackets = 0
        speechPackets = 0
        quietAfterSpeech = 0
        noiseFloor = Int.MAX_VALUE
        loudnessCount = 0
        loudnessTrace.setLength(0)
        voiceStartedAt = SystemClock.elapsedRealtime()
        GlassesRuntime.emit(mapOf("event" to "voiceState", "state" to "listening"))
        val token = voiceToken
        main.postDelayed({
            if (token == voiceToken && voice != null && voicePackets == 0) finishVoice("no voice from glasses")
        }, NO_VOICE_MS)
        main.postDelayed({ if (token == voiceToken && voice != null) finishVoice("max length") }, MAX_VOICE_MS)
    }

    private fun onRecordControl(code: Int) {
        when (code) {
            0, 1 -> if (voice == null && !justEnded()) startVoice()
            2 -> if (voice != null) finishVoice("glasses: end of phrase", stopGlasses = false)
            3 -> if (voice != null) finishVoice("glasses: cancelled", stopGlasses = false)
        }
    }

    private fun onVoice(payload: ByteArray) {
        val buffer = voice ?: run {
            if (justEnded()) return // tail of the question we already closed
            startVoice()
            voice!!
        }
        // 00 00 <len> + one Opus packet (SILK, 2 × 40 ms), padded to 160 bytes.
        val opus = if (payload.size > 3 && (payload[2].toInt() and 0xFF) in 1..payload.size - 3) {
            payload.copyOfRange(3, 3 + (payload[2].toInt() and 0xFF))
        } else {
            payload
        }
        buffer.write(opus.size shr 8)
        buffer.write(opus.size and 0xFF)
        buffer.write(opus)
        voicePackets += 1
        if (voicePackets == 1) DiagLog.i(TAG, "<- voice starts, packet ${payload.size} B: ${payload.copyOf(12).hex()}")
        checkLoudness(opus, voiceToken)
    }

    private fun checkLoudness(opus: ByteArray, token: Int) {
        if (vadBroken) return
        vadHandler.post {
            val rms = try {
                if (vad == null) vad = OpusVad()
                vad!!.rms(opus)
            } catch (error: Exception) {
                vadBroken = true
                DiagLog.e(TAG, "Opus loudness check off", error)
                null
            }
            if (rms != null) main.post { onLoudness(rms, token) }
        }
    }

    private fun onLoudness(rms: Int, token: Int) {
        if (token != voiceToken || voice == null) return
        loudnessCount += 1
        if (loudnessTrace.length < 600) loudnessTrace.append(rms).append(' ')
        // Background = the quietest packet so far (pauses between words), not the first packets:
        // the user often starts talking at once, and then the first packets are already speech.
        if (loudnessCount > 1 && rms > 0) noiseFloor = minOf(noiseFloor, rms)
        val floor = noiseFloor.takeIf { it != Int.MAX_VALUE } ?: 0
        val threshold = (floor * 3).coerceIn(SPEECH_RMS_MIN, SPEECH_RMS_MAX)
        if (rms >= threshold) {
            speechPackets += 1
            quietAfterSpeech = 0
        } else if (speechPackets >= MIN_SPEECH_PACKETS) {
            quietAfterSpeech += 1
            val long = SystemClock.elapsedRealtime() - voiceStartedAt >= MIN_VOICE_MS
            if (quietAfterSpeech >= QUIET_PACKETS_TO_END && long) {
                finishVoice("silence after speech (rms $rms < $threshold, floor $floor)")
            }
        }
        if (speechPackets == 0 && SystemClock.elapsedRealtime() - voiceStartedAt > NO_SPEECH_MS) {
            finishVoice("no speech heard (floor $floor)")
        }
    }

    private fun finishVoice(reason: String, stopGlasses: Boolean = true) {
        val buffer = voice ?: return
        voice = null
        voiceToken += 1
        endedAt = SystemClock.elapsedRealtime()
        val ms = SystemClock.elapsedRealtime() - voiceStartedAt
        if (stopGlasses && linked) send(BkProtocol.STOP_RECORD, byteArrayOf(0))
        DiagLog.i(TAG, "voice end: $reason; $voicePackets packets, ${buffer.size()} B, $ms ms, speech packets $speechPackets")
        DiagLog.i(TAG, "voice loudness: $loudnessTrace")
        if (voicePackets == 0) {
            GlassesRuntime.emit(mapOf("event" to "voiceState", "state" to "idle", "reason" to reason))
            return
        }
        val file = File(mediaDir(), "voice_${System.currentTimeMillis()}.opus")
        file.writeBytes(buffer.toByteArray())
        GlassesRuntime.emit(
            mapOf(
                "event" to "voiceCaptured",
                "path" to file.absolutePath,
                "packets" to voicePackets,
                "durationMs" to ms.toInt(),
                "speechPackets" to speechPackets,
                "reason" to reason,
            ),
        )
        // In case the question is about what the user sees: the photo arrives while the server listens.
        if (linked) main.postDelayed({ requestPhoto("voice") }, 150)
    }

    private fun justEnded() = SystemClock.elapsedRealtime() - endedAt < AFTER_END_IGNORE_MS

    // ---- photo

    private fun onImage(payload: ByteArray) {
        if (payload.size < 12) return
        val width = (payload[2].toInt() and 0xFF) shl 8 or (payload[3].toInt() and 0xFF)
        val height = (payload[4].toInt() and 0xFF) shl 8 or (payload[5].toInt() and 0xFF)
        var start = 10
        if (!(payload[start].toInt() and 0xFF == 0xFF && payload[start + 1].toInt() and 0xFF == 0xD8)) {
            // Not where expected: look for the JPEG start marker.
            start = (0 until payload.size - 1).firstOrNull {
                payload[it].toInt() and 0xFF == 0xFF && payload[it + 1].toInt() and 0xFF == 0xD8
            } ?: run {
                DiagLog.w(TAG, "photo without JPEG marker, ${payload.size} B")
                return
            }
        }
        val reason = photoReason ?: "glasses"
        photoReason = null
        val waited = if (photoRequestedAt > 0) SystemClock.elapsedRealtime() - photoRequestedAt else -1
        val file = File(mediaDir(), "glasses_${System.currentTimeMillis()}.jpg")
        file.writeBytes(payload.copyOfRange(start, payload.size))
        DiagLog.i(TAG, "photo $reason ${width}x$height ${file.length()} B after $waited ms")
        GlassesRuntime.emit(
            mapOf(
                "event" to "glassesPhoto",
                "path" to file.absolutePath,
                "reason" to reason,
                "width" to width,
                "height" to height,
                "waitedMs" to waited.toInt(),
            ),
        )
    }

    private fun button(button: String, kind: String) {
        GlassesRuntime.emit(mapOf("event" to "glassesButton", "button" to button, "kind" to kind))
    }

    private fun battery(payload: ByteArray) {
        val level = payload.firstOrNull()?.toInt()?.and(0xFF) ?: return
        if (level in 0..100 && level != lastBattery) {
            lastBattery = level
            GlassesRuntime.emitBattery(level)
        }
    }

    private fun mediaDir(): File {
        val dir = File(context.cacheDir, "glasses")
        dir.mkdirs()
        // Keep the folder small: drop files older than an hour.
        val old = System.currentTimeMillis() - 3_600_000L
        dir.listFiles()?.filter { it.lastModified() < old }?.forEach { it.delete() }
        return dir
    }

    companion object {
        private const val TAG = "Glasses"
        private const val REPEAT_IGNORE_MS = 4_000L
        private const val AFTER_END_IGNORE_MS = 2_500L
        private const val NO_VOICE_MS = 4_000L
        private const val NO_SPEECH_MS = 6_000L
        private const val MAX_VOICE_MS = 10_000L
        private const val SPEECH_RMS_MIN = 120
        private const val SPEECH_RMS_MAX = 900
        private const val MIN_SPEECH_PACKETS = 3
        private const val QUIET_PACKETS_TO_END = 15 // 15 × 80 ms = 1.2 s of quiet after speech
        private const val MIN_VOICE_MS = 2_000L // from the Allow: the voice starts ~0.5 s later
    }
}
