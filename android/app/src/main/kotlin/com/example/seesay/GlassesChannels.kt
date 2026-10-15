package com.example.seesay

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.example.seesay.camera.PhotoCapturer
import com.example.seesay.service.GlassesForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ Android bridge. Registered once per engine with the application context, so it keeps
 * working while no screen is shown.
 */
object GlassesChannels {
    private const val METHOD_CHANNEL = "com.example.seesay/glasses"
    private const val EVENT_CHANNEL = "com.example.seesay/glasses_events"
    private const val TAG = "GlassesChannels"

    fun attach(app: Context, engine: FlutterEngine) {
        val context = app.applicationContext
        GlassesRuntime.ensureTts(context)
        val camera = PhotoCapturer(context)
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectGlasses" -> guard(result, "Не удалось подключить очки.") {
                    GlassesForegroundService.start(context, call.argument<String>("deviceAddress"))
                }
                "disconnectGlasses" -> guard(result, "Не удалось отключить очки.") {
                    GlassesForegroundService.stop(context)
                }
                "capturePhoto" -> camera.capture { outcome ->
                    outcome.fold(
                        onSuccess = { file -> result.success(file.absolutePath) },
                        onFailure = { error ->
                            result.error("camera", error.message ?: "Камера недоступна.", null)
                        },
                    )
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1f
                    val language = call.argument<String>("language")
                    val engineTts = GlassesRuntime.tts
                    if (engineTts == null) {
                        result.error("speech", "Синтез речи недоступен", null)
                    } else {
                        engineTts.speak(text, rate, language, result)
                    }
                }
                "stopSpeaking" -> {
                    GlassesRuntime.tts?.stop()
                    result.success(null)
                }
                "setSpeechRate" -> {
                    GlassesRuntime.tts?.setRate(call.argument<Double>("rate")?.toFloat() ?: 1f)
                    result.success(null)
                }
                "setLanguage" -> {
                    GlassesRuntime.tts?.setLanguage(call.argument<String>("language") ?: "ru-RU")
                    result.success(null)
                }
                "requestGlassesPhoto" -> result.success(
                    GlassesRuntime.session?.requestPhoto(call.argument<String>("reason") ?: "request") == true,
                )
                "playPitch" -> PitchPlayer.play(context) { ok -> result.success(ok) }
                "stopPitch" -> {
                    PitchPlayer.stop(context)
                    result.success(null)
                }
                "diagLog" -> {
                    DiagLog.write(
                        call.argument<String>("level") ?: "I",
                        "Dart",
                        call.argument<String>("message") ?: "",
                    )
                    result.success(null)
                }
                "exportLog" -> result.success(DiagLog.export(context).absolutePath)
                "getConnectionState" -> result.success(GlassesRuntime.connectionState)
                "isBluetoothEnabled" -> {
                    val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
                    result.success(adapter?.isEnabled == true)
                }
                "haptic" -> {
                    HapticPlayer.play(context, call.argument<String>("kind") ?: "tap")
                    result.success(null)
                }
                "beep" -> {
                    BeepPlayer.play(call.argument<String>("kind") ?: "tap")
                    result.success(null)
                }
                "isBackgroundUnrestricted" -> result.success(isBackgroundUnrestricted(context))
                "requestBackgroundUnrestricted" -> guard(result, "Не удалось открыть настройки батареи.") {
                    requestBackgroundUnrestricted(context)
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

    private fun isBackgroundUnrestricted(context: Context): Boolean {
        val power = context.getSystemService(PowerManager::class.java) ?: return false
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    /** System dialog «Allow SeeSay to always run in the background». */
    @SuppressLint("BatteryLife")
    private fun requestBackgroundUnrestricted(context: Context) {
        if (isBackgroundUnrestricted(context)) return
        val request = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(request)
        } catch (error: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun guard(result: MethodChannel.Result, message: String, action: () -> Unit) {
        try {
            action()
            result.success(true)
        } catch (error: Exception) {
            Log.e(TAG, message, error)
            val text = (error as? IllegalStateException)?.message?.takeIf { it.isNotBlank() } ?: message
            result.error("glasses", text, null)
        }
    }
}
