package com.example.seesay

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel

object GlassesRuntime {
    @Volatile
    var eventSink: EventChannel.EventSink? = null

    @Volatile
    var connectionState: String = "disconnected"

    var tts: AndroidTtsEngine? = null

    private val main = Handler(Looper.getMainLooper())

    fun emit(event: Map<String, Any?>) {
        main.post { eventSink?.success(event) }
    }

    fun emitConnection(state: String, message: String? = null, address: String? = null) {
        connectionState = state
        val payload = linkedMapOf<String, Any?>(
            "event" to "bleConnectionChanged",
            "state" to state,
        )
        if (message != null) payload["message"] = message
        if (address != null) payload["deviceAddress"] = address
        emit(payload)
    }

    fun emitPacket(bytes: ByteArray) {
        emit(
            mapOf(
                "event" to "blePacketReceived",
                "bytes" to bytes.map { it.toInt() and 0xFF },
            ),
        )
    }

    fun emitMedia(keyCode: Int) {
        val action = when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
            -> "MEDIA_PLAY_PAUSE"
            KeyEvent.KEYCODE_VOLUME_UP -> "VOLUME_UP"
            KeyEvent.KEYCODE_VOLUME_DOWN -> "VOLUME_DOWN"
            else -> return
        }
        emit(mapOf("event" to "mediaButtonEvent", "action" to action))
    }

    fun emitBattery(level: Int) {
        emit(mapOf("event" to "batteryChanged", "level" to level))
    }

    fun ensureTts(context: Context) {
        if (tts == null) {
            tts = AndroidTtsEngine(context.applicationContext)
        }
    }
}
