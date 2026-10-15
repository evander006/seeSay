package com.example.seesay.translator

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Flutter ↔ interpreter bridge, its own channels: nothing of the glasses bridge is shared. */
object TranslatorChannels {
    private const val METHODS = "com.example.seesay/translator"
    private const val EVENTS = "com.example.seesay/translator_events"

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(app: Context, engine: FlutterEngine) {
        val context = app.applicationContext
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val error = TranslatorEngine.start(context) { event -> sink?.success(event) }
                    if (error == null) result.success(true) else result.error("translator", error, null)
                }
                "stop" -> {
                    TranslatorEngine.stop(context)
                    result.success(null)
                }
                "isRunning" -> result.success(TranslatorEngine.isRunning)
                "speakToGlasses" -> TranslatorEngine.speakToGlasses(
                    context,
                    call.argument<String>("text") ?: "",
                    done = { result.success(it) },
                )
                "playOnSpeaker" -> TranslatorEngine.playOnSpeaker(context, call.argument<String>("path") ?: "") {
                    result.success(it)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
    }
}
