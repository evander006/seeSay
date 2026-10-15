package com.example.seesay.translator

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.content.ContextCompat
import com.example.seesay.DiagLog
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import java.util.UUID
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Interpreter mode, separate from the glasses assistant: the phone mic listens all the time and cuts
 * the conversation into phrases (loudness, 0.7 s pause); each phrase goes to Flutter as a 16 kHz WAV.
 * Translations are spoken by its own TTS (Russian, into the glasses) or played on the phone speaker
 * (for the partner). While any of them sounds, the mic ignores what it hears, so the interpreter
 * never translates its own voice.
 */
object TranslatorEngine {
    private const val TAG = "Translator"
    private const val RATE = 16_000
    private const val FRAME = 320 // 20 ms
    private const val PRE_ROLL = 15 // 300 ms kept before the first loud frame
    private const val START_FRAMES = 5 // 100 ms of loud frames start a phrase
    private const val END_FRAMES = 35 // 700 ms of quiet end it
    private const val KEEP_TAIL = 10 // 200 ms of that quiet stay in the WAV
    private const val MIN_SPEECH_FRAMES = 15 // shorter than 300 ms of speech is a noise
    private const val MAX_FRAMES = 750 // 15 s at most per phrase
    private const val MIN_RMS = 300.0
    private const val AFTER_PLAY_MS = 350L

    @Volatile private var running = false
    @Volatile private var pausedUntil = 0L
    @Volatile private var playing = 0
    private var thread: Thread? = null
    private var sink: ((Map<String, Any?>) -> Unit)? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val ttsWaiting = HashMap<String, (Boolean) -> Unit>()
    private var wakeLock: PowerManager.WakeLock? = null
    private val main = Handler(Looper.getMainLooper())

    val isRunning: Boolean get() = running

    /** Null when listening started, else a message for the user. */
    fun start(context: Context, events: (Map<String, Any?>) -> Unit): String? {
        if (running) return null
        val app = context.applicationContext
        if (ContextCompat.checkSelfPermission(app, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return "Нет доступа к микрофону."
        }
        sink = events
        ensureTts(app)
        val record = try {
            val min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            @SuppressLint("MissingPermission")
            val r = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                max(min, RATE),
            )
            r
        } catch (error: Exception) {
            DiagLog.e(TAG, "mic init failed", error)
            return "Микрофон недоступен."
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return "Микрофон недоступен."
        }
        // The phone's own mic, not the glasses headset.
        device(app, AudioManager.GET_DEVICES_INPUTS, AudioDeviceInfo.TYPE_BUILTIN_MIC)?.let { record.setPreferredDevice(it) }
        running = true
        keepScreenOn(app, true)
        thread = Thread({ loop(app, record) }, "seesay-translator").apply { start() }
        DiagLog.i(TAG, "started")
        return null
    }

    fun stop(context: Context) {
        if (!running) return
        running = false
        thread = null
        tts?.stop()
        keepScreenOn(context.applicationContext, false)
        DiagLog.i(TAG, "stopped")
    }

    // ---- listening

    private fun loop(context: Context, record: AudioRecord) {
        val frame = ShortArray(FRAME)
        val preRoll = ArrayDeque<ShortArray>()
        var segment: ByteArrayOutputStream? = null
        var loud = 0
        var quiet = 0
        var frames = 0
        var speechFrames = 0
        var floor = -1.0
        var lastLevel = 0L
        try {
            record.startRecording()
            while (running) {
                val n = record.read(frame, 0, FRAME)
                if (n <= 0) continue
                val now = SystemClock.elapsedRealtime()
                if (playing > 0 || now < pausedUntil) {
                    // Our own translation is sounding: do not listen to it.
                    segment = null
                    loud = 0
                    quiet = 0
                    preRoll.clear()
                    continue
                }
                val rms = rms(frame, n)
                floor = when {
                    floor < 0 || rms < floor -> rms
                    else -> floor + (rms - floor) * 0.002 // the background rises slowly, drops at once
                }
                val isLoud = rms >= max(MIN_RMS, floor * 3.0)
                if (now - lastLevel > 150) {
                    lastLevel = now
                    emit(mapOf("event" to "level", "rms" to rms.toInt(), "speaking" to (segment != null)))
                }
                val copy = frame.copyOf(n)
                val current = segment
                if (current == null) {
                    preRoll.addLast(copy)
                    if (preRoll.size > PRE_ROLL) preRoll.removeFirst()
                    loud = if (isLoud) loud + 1 else 0
                    if (loud >= START_FRAMES) {
                        val started = ByteArrayOutputStream()
                        preRoll.forEach { started.write(it.toBytes()) }
                        frames = preRoll.size
                        speechFrames = loud
                        quiet = 0
                        preRoll.clear()
                        segment = started
                        emit(mapOf("event" to "speech", "state" to "start"))
                    }
                } else {
                    current.write(copy.toBytes())
                    frames += 1
                    if (isLoud) {
                        speechFrames += 1
                        quiet = 0
                    } else {
                        quiet += 1
                    }
                    if (quiet >= END_FRAMES || frames >= MAX_FRAMES) {
                        finishPhrase(context, current, speechFrames, quiet, if (quiet >= END_FRAMES) "pause" else "max")
                        segment = null
                        loud = 0
                        quiet = 0
                    }
                }
            }
        } catch (error: Exception) {
            DiagLog.e(TAG, "capture failed", error)
            emit(mapOf("event" to "error", "text" to "Микрофон остановился."))
        } finally {
            runCatching { record.stop() }
            record.release()
        }
    }

    private fun finishPhrase(context: Context, pcm: ByteArrayOutputStream, speechFrames: Int, quiet: Int, why: String) {
        if (speechFrames < MIN_SPEECH_FRAMES) {
            emit(mapOf("event" to "speech", "state" to "noise"))
            return
        }
        val bytes = pcm.toByteArray()
        val cut = (max(0, quiet - KEEP_TAIL) * FRAME * 2).coerceAtMost(bytes.size)
        val body = bytes.copyOf(bytes.size - cut)
        val dir = File(context.cacheDir, "translator").apply { mkdirs() }
        dir.listFiles()?.filter { it.lastModified() < System.currentTimeMillis() - 600_000 }?.forEach { it.delete() }
        val file = File(dir, "phrase_${System.currentTimeMillis()}.wav")
        file.writeBytes(wavHeader(body.size) + body)
        val ms = body.size / 2 * 1000 / RATE
        DiagLog.i(TAG, "phrase $ms ms ($why), speech ${speechFrames * 20} ms")
        emit(mapOf("event" to "phrase", "path" to file.absolutePath, "ms" to ms))
    }

    // ---- speaking

    /** Russian translation into the glasses (media → Bluetooth). [done] when it was said. */
    fun speakToGlasses(context: Context, text: String, done: (Boolean) -> Unit, attempt: Int = 0) {
        ensureTts(context.applicationContext)
        main.post {
            val engine = tts
            if (text.isBlank()) {
                done(false)
                return@post
            }
            if (engine == null || !ttsReady) {
                // The speech engine needs a moment after the first start.
                if (attempt < 12) {
                    main.postDelayed({ speakToGlasses(context, text, done, attempt + 1) }, 250)
                } else {
                    done(false)
                }
                return@post
            }
            val id = UUID.randomUUID().toString()
            ttsWaiting[id] = done
            playing += 1
            val params = Bundle()
            params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, id)
            engine.speak(text, TextToSpeech.QUEUE_ADD, params, id)
        }
    }

    /** Partner's translation (MP3 from the server) on the phone's own speaker. */
    fun playOnSpeaker(context: Context, path: String, done: (Boolean) -> Unit) {
        val app = context.applicationContext
        main.post {
            playing += 1
            val player = MediaPlayer()
            var finished = false
            fun finish(ok: Boolean) {
                if (finished) return
                finished = true
                runCatching { player.release() }
                released()
                done(ok)
            }
            try {
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                player.setDataSource(path)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    device(app, AudioManager.GET_DEVICES_OUTPUTS, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
                        ?.let { player.setPreferredDevice(it) }
                }
                player.setVolume(1f, 1f)
                player.setOnCompletionListener { finish(true) }
                player.setOnErrorListener { _, what, extra ->
                    DiagLog.w(TAG, "speaker playback error $what/$extra")
                    finish(false)
                    true
                }
                player.prepare()
                player.start()
            } catch (error: Exception) {
                DiagLog.e(TAG, "speaker playback failed", error)
                finish(false)
            }
        }
    }

    private fun released() {
        playing = max(0, playing - 1)
        pausedUntil = SystemClock.elapsedRealtime() + AFTER_PLAY_MS
    }

    private fun ensureTts(context: Context) {
        if (tts != null) return
        main.post {
            if (tts != null) return@post
            tts = TextToSpeech(context) { status ->
                main.post {
                    ttsReady = status == TextToSpeech.SUCCESS
                    tts?.language = Locale.forLanguageTag("ru-RU")
                    tts?.setSpeechRate(1.1f)
                    tts?.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build(),
                    )
                    DiagLog.i(TAG, "tts ready=$ttsReady")
                }
            }.apply {
                setOnUtteranceProgressListener(
                    object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) = Unit

                        override fun onDone(utteranceId: String?) = said(utteranceId, true)

                        @Deprecated("Deprecated in Java")
                        override fun onError(utteranceId: String?) = said(utteranceId, false)

                        override fun onStop(utteranceId: String?, interrupted: Boolean) = said(utteranceId, false)
                    },
                )
            }
        }
    }

    private fun said(id: String?, ok: Boolean) {
        main.post {
            val done = ttsWaiting.remove(id ?: return@post) ?: return@post
            released()
            done(ok)
        }
    }

    // ---- helpers

    private fun emit(event: Map<String, Any?>) {
        main.post { sink?.invoke(event) }
    }

    private fun device(context: Context, flags: Int, type: Int): AudioDeviceInfo? {
        val audio = context.getSystemService(AudioManager::class.java) ?: return null
        return audio.getDevices(flags).firstOrNull { it.type == type }
    }

    @Suppress("DEPRECATION")
    private fun keepScreenOn(context: Context, on: Boolean) {
        // The interpreter listens with the phone mic, which Android silences for apps in background.
        if (on) {
            if (wakeLock?.isHeld == true) return
            wakeLock = context.getSystemService(PowerManager::class.java)
                ?.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK, "SeeSay:translator")
                ?.apply { acquire(2 * 60 * 60 * 1000L) }
        } else {
            wakeLock?.takeIf { it.isHeld }?.release()
            wakeLock = null
        }
    }

    private fun rms(frame: ShortArray, n: Int): Double {
        var sum = 0.0
        for (i in 0 until n) sum += frame[i].toDouble() * frame[i]
        return sqrt(sum / n)
    }

    private fun ShortArray.toBytes(): ByteArray {
        val buffer = ByteBuffer.allocate(size * 2).order(ByteOrder.LITTLE_ENDIAN)
        forEach { buffer.putShort(it) }
        return buffer.array()
    }

    private fun wavHeader(dataSize: Int): ByteArray {
        val b = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        b.put("RIFF".toByteArray()).putInt(36 + dataSize).put("WAVE".toByteArray())
        b.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1).putInt(RATE).putInt(RATE * 2)
            .putShort(2).putShort(16)
        b.put("data".toByteArray()).putInt(dataSize)
        return b.array()
    }
}
