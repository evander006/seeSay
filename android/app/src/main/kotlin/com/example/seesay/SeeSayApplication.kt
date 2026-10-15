package com.example.seesay

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns the Flutter engine for the whole process instead of the screen.
 *
 * The glasses pipeline (button → photo → server → speech) lives in Dart. While the glasses are
 * connected the foreground service keeps the process alive, so with a process-wide engine that
 * pipeline keeps running after the user leaves or swipes away the app.
 */
class SeeSayApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DiagLog.init(this)
        DiagLog.i("App", "process start")
        val engine = FlutterEngine(this)
        GlassesChannels.attach(this, engine)
        com.example.seesay.translator.TranslatorChannels.attach(this, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "seesay"
    }
}
