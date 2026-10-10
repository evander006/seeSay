package com.example.seesay

import android.bluetooth.BluetoothManager
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.example.seesay.events.GlassesEventStore
import com.example.seesay.service.GlassesForegroundService

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GlassesRuntime.ensureTts(this)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectGlasses" -> guard(result, "Не удалось подключить очки.") {
                    GlassesForegroundService.start(this, call.argument<String>("deviceAddress"))
                }
                "disconnectGlasses" -> guard(result, "Не удалось отключить очки.") {
                    GlassesForegroundService.stop(this)
                }
                "startCapture" -> {
                    GlassesRuntime.emitMedia(android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                    result.success(true)
                }
                "stopCapture" -> result.success(true)
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1f
                    val language = call.argument<String>("language")
                    val engine = GlassesRuntime.tts
                    if (engine == null) {
                        result.error("speech", "Синтез речи недоступен", null)
                    } else {
                        engine.speak(text, rate, language, result)
                    }
                }
                "stopSpeaking" -> {
                    GlassesRuntime.tts?.stop()
                    result.success(null)
                }
                "setSpeechRate" -> {
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1f
                    GlassesRuntime.tts?.setRate(rate)
                    result.success(null)
                }
                "setLanguage" -> {
                    val language = call.argument<String>("language") ?: "ru-RU"
                    GlassesRuntime.tts?.setLanguage(language)
                    result.success(null)
                }
                "getConnectionState" -> result.success(GlassesRuntime.connectionState)
                "isBluetoothEnabled" -> {
                    val adapter = getSystemService(BluetoothManager::class.java)?.adapter
                    result.success(adapter?.isEnabled == true)
                }
                "haptic" -> {
                    HapticPlayer.play(this, call.argument<String>("kind") ?: "tap")
                    result.success(null)
                }
                "beep" -> {
                    BeepPlayer.play(call.argument<String>("kind") ?: "tap")
                    result.success(null)
                }
                "startBackgroundMonitoring" -> guard(result, "Не удалось включить мониторинг.") {
                    GlassesForegroundService.startMonitoring(this)
                }
                "stopBackgroundMonitoring" -> guard(result, "Не удалось остановить мониторинг.") {
                    GlassesForegroundService.stopMonitoring(this)
                }
                "getBackgroundMonitoringStatus" -> {
                    result.success(GlassesEventStore(this).monitoring)
                }
                "enableMockMode" -> guard(result, "Не удалось включить демонстрационный режим.") {
                    GlassesForegroundService.setMock(this, true)
                }
                "disableMockMode" -> guard(result, "Не удалось выключить демонстрационный режим.") {
                    GlassesForegroundService.setMock(this, false)
                }
                "triggerMockEvent" -> guard(result, "Не удалось создать тестовое событие.") {
                    val type = call.argument<String>("type") ?: "TEXT_RECOGNIZED"
                    GlassesForegroundService.trigger(this, type)
                }
                "getPendingGlassesEvents" -> {
                    result.success(GlassesEventStore(this).pending().map { it.toMap() })
                }
                "getRecentGlassesEvents" -> {
                    result.success(GlassesEventStore(this).recent().map { it.toMap() })
                }
                "acknowledgeGlassesEvent" -> {
                    val id = call.argument<String>("eventId") ?: ""
                    result.success(GlassesEventStore(this).acknowledge(id))
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    GlassesRuntime.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    GlassesRuntime.eventSink = null
                }
            },
        )
    }

    private fun guard(result: MethodChannel.Result, message: String, action: () -> Unit) {
        try {
            action()
            result.success(true)
        } catch (error: Exception) {
            Log.e("MainActivity", message, error)
            val text = (error as? IllegalStateException)?.message?.takeIf { it.isNotBlank() }
                ?: message
            result.error("glasses", text, null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    companion object {
        private const val METHOD_CHANNEL = "com.example.seesay/glasses"
        private const val EVENT_CHANNEL = "com.example.seesay/glasses_events"
    }
}
