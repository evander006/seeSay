package com.example.seesay

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

class AndroidTtsEngine(context: android.content.Context) : TextToSpeech.OnInitListener {
    private val tts = TextToSpeech(context.applicationContext, this)
    private val main = Handler(Looper.getMainLooper())
    private var ready = false
    private var rate = 1f
    private var language: Locale = Locale.forLanguageTag("ru-RU")
    private var pending: Pending? = null

    override fun onInit(status: Int) {
        main.post {
            ready = status == TextToSpeech.SUCCESS
            if (!ready) {
                pending?.result?.error("speech", "Синтез речи недоступен", null)
                pending = null
                return@post
            }
            tts.setAudioAttributes(
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            tts.setOnUtteranceProgressListener(
                object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit

                    override fun onDone(utteranceId: String?) {
                        finish(null)
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        finish("TTS error")
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        finish("TTS error $errorCode")
                    }
                },
            )
            applyVoice()
            pending?.let { start(it) }
        }
    }

    fun speak(text: String, speechRate: Float, languageTag: String?, result: MethodChannel.Result) {
        main.post {
            pending?.result?.success(null)
            val next = Pending(text, speechRate, languageTag ?: language.toLanguageTag(), result)
            pending = next
            rate = speechRate
            language = Locale.forLanguageTag(next.language)
            if (ready) start(next)
        }
    }

    fun setRate(speechRate: Float) {
        main.post {
            rate = speechRate
            if (ready) tts.setSpeechRate(speechRate)
        }
    }

    fun setLanguage(languageTag: String) {
        main.post {
            language = Locale.forLanguageTag(languageTag)
            if (ready) tts.language = language
        }
    }

    fun speakLocally(text: String) {
        main.post {
            if (!ready || text.isBlank()) return@post
            applyVoice()
            val id = UUID.randomUUID().toString()
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), id)
        }
    }

    fun stop() {
        main.post {
            if (ready) tts.stop()
            pending?.result?.success(null)
            pending = null
        }
    }

    fun shutdown() {
        main.post {
            pending?.result?.success(null)
            pending = null
            tts.shutdown()
        }
    }

    private fun applyVoice() {
        tts.setSpeechRate(rate)
        tts.language = language
    }

    private fun start(request: Pending) {
        applyVoice()
        val id = UUID.randomUUID().toString()
        val params = Bundle()
        params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, id)
        tts.speak(request.text, TextToSpeech.QUEUE_FLUSH, params, id)
    }

    private fun finish(error: String?) {
        main.post {
            val current = pending ?: return@post
            pending = null
            if (error == null) current.result.success(null) else current.result.error("speech", error, null)
        }
    }

    private data class Pending(
        val text: String,
        val rate: Float,
        val language: String,
        val result: MethodChannel.Result,
    )
}
