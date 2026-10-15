package com.example.seesay

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer

/**
 * Plays the demo pitch (res/raw/pitch.mp3, 17.8 s, neural voice) into the glasses at full volume
 * and puts the media volume back afterwards.
 */
object PitchPlayer {
    private var player: MediaPlayer? = null
    private var savedVolume = -1

    fun play(context: Context, onDone: (Boolean) -> Unit) {
        stop(context)
        val audio = context.getSystemService(AudioManager::class.java)
        GlassesRuntime.tts?.stop()
        if (audio != null) {
            savedVolume = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)
        }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val created = MediaPlayer.create(context, R.raw.pitch, attributes, audio?.generateAudioSessionId() ?: 0)
        if (created == null) {
            DiagLog.e("Pitch", "MediaPlayer.create failed")
            restoreVolume(context)
            onDone(false)
            return
        }
        player = created
        created.setVolume(1f, 1f)
        created.setOnCompletionListener {
            DiagLog.i("Pitch", "finished")
            stop(context)
            onDone(true)
        }
        created.setOnErrorListener { _, what, extra ->
            DiagLog.e("Pitch", "playback error $what/$extra")
            stop(context)
            onDone(false)
            true
        }
        DiagLog.i("Pitch", "start, ${created.duration} ms at max volume (was $savedVolume)")
        created.start()
    }

    fun stop(context: Context) {
        player?.let {
            runCatching { it.stop() }
            it.release()
        }
        player = null
        restoreVolume(context)
    }

    private fun restoreVolume(context: Context) {
        if (savedVolume < 0) return
        context.getSystemService(AudioManager::class.java)?.setStreamVolume(AudioManager.STREAM_MUSIC, savedVolume, 0)
        savedVolume = -1
    }
}
