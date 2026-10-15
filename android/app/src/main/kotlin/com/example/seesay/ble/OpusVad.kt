package com.example.seesay.ble

import android.media.MediaCodec
import android.media.MediaFormat
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

/**
 * Loudness of each Opus packet from the glasses, decoded with the Android Opus decoder.
 * Used only to notice the end of the question early; the server decodes the audio itself.
 * Call from one background thread.
 */
class OpusVad {
    private val codec: MediaCodec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_AUDIO_OPUS)
    private var pts = 0L

    init {
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_OPUS, 48_000, 1)
        format.setByteBuffer("csd-0", opusHead())
        format.setByteBuffer("csd-1", longLe(0L))
        format.setByteBuffer("csd-2", longLe(80_000_000L))
        codec.configure(format, null, null, 0)
        codec.start()
    }

    /** RMS of the decoded samples (16-bit scale), or null when the decoder had no output yet. */
    fun rms(packet: ByteArray): Int? {
        val input = codec.dequeueInputBuffer(20_000)
        if (input < 0) return null
        codec.getInputBuffer(input)!!.apply {
            clear()
            put(packet)
        }
        codec.queueInputBuffer(input, 0, packet.size, pts, 0)
        pts += 80_000
        var sum = 0.0
        var count = 0
        val info = MediaCodec.BufferInfo()
        repeat(4) {
            val output = codec.dequeueOutputBuffer(info, 15_000)
            when {
                output >= 0 -> {
                    val buffer = codec.getOutputBuffer(output)!!
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    val samples = buffer.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                    while (samples.hasRemaining()) {
                        val s = samples.get().toDouble()
                        sum += s * s
                        count += 1
                    }
                    codec.releaseOutputBuffer(output, false)
                    if (count > 0) return sqrt(sum / count).toInt()
                }
                output == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                else -> return null
            }
        }
        return if (count > 0) sqrt(sum / count).toInt() else null
    }

    fun release() {
        runCatching { codec.stop() }
        runCatching { codec.release() }
    }

    private fun opusHead(): ByteBuffer {
        val head = ByteBuffer.allocate(19).order(ByteOrder.LITTLE_ENDIAN)
        head.put("OpusHead".toByteArray())
        head.put(1) // version
        head.put(1) // channels
        head.putShort(0) // pre-skip
        head.putInt(16_000) // input sample rate
        head.putShort(0) // output gain
        head.put(0) // mapping family
        head.flip()
        return head
    }

    private fun longLe(value: Long): ByteBuffer =
        ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(value).apply { flip() }
}
