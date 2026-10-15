package com.example.seesay

import io.flutter.embedding.android.FlutterActivity

/** Shows the process-wide engine from [SeeSayApplication]; closing the screen does not stop Dart. */
class MainActivity : FlutterActivity() {
    override fun getCachedEngineId(): String = SeeSayApplication.ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
