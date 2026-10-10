package com.example.seesay

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object BeepPlayer {
    fun play(kind: String) {
        val tone = when (kind) {
            "error" -> ToneGenerator.TONE_PROP_NACK
            "success", "connection" -> ToneGenerator.TONE_PROP_ACK
            else -> ToneGenerator.TONE_PROP_BEEP
        }
        val generator = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
        generator.startTone(tone, 160)
        Handler(Looper.getMainLooper()).postDelayed({ generator.release() }, 280)
    }
}

object HapticPlayer {
    fun play(context: Context, kind: String) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = when (kind) {
            "success" -> longArrayOf(0, 40, 40, 40)
            "error" -> longArrayOf(0, 80, 50, 80, 50, 80)
            "connection" -> longArrayOf(0, 60, 40, 30)
            "capture" -> longArrayOf(0, 90)
            else -> longArrayOf(0, 30)
        }
        vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
    }
}
