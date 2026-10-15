package com.example.seesay.ble

import java.io.ByteArrayOutputStream

/**
 * AIMB S2 (Beken BK7258) packet format, checked against real glasses (see docs/aimb-protocol.md):
 *
 *   ED | flags | seq | crc8(cmd+payload) | len(cmd+payload) u16 BE | cmd u16 BE | payload…
 *
 * flags: 0x40 command / last fragment, 0x80 more fragments follow, 0x20 reply to our command.
 */
object BkProtocol {
    const val HEADER = 0xED
    const val FLAG_MORE = 0x80
    const val FLAG_REPLY = 0x20

    // Outgoing (EA02)
    const val DEVICE_INITIALIZED = 0x100D
    const val GET_BATTERY = 0x1003
    const val GET_FIRMWARE = 0x1004
    const val STOP_RECORD = 0x1207

    // Both directions
    const val REQUEST_AI = 0x1204
    const val AI_INTENT = 0x120A

    // Incoming (EA01)
    const val MEDIA_CHANGES = 0x1203
    const val RECORD_CONTROL = 0x1205
    const val RECORD_DATA = 0x1206
    const val WEARING = 0x1209
    const val INTENT_IMAGE = 0x120B
    const val MEDIA_TRIGGER = 0x120D
    const val PHOTO_BUTTON = 0x120F

    const val INTENT_VISUAL_QA = 1
    const val INTENT_PHOTO_RECOGNITION = 2

    private var seq = 0

    fun crc8(data: ByteArray, from: Int = 0, to: Int = data.size): Int {
        var c = 0xFF
        for (i in from until to) {
            c = c xor (data[i].toInt() and 0xFF)
            repeat(8) { c = if (c and 1 != 0) (c ushr 1) xor 0xB8 else c ushr 1 }
        }
        return c
    }

    @Synchronized
    fun frame(cmd: Int, payload: ByteArray = ByteArray(0)): ByteArray {
        val body = ByteArray(2 + payload.size)
        body[0] = (cmd shr 8).toByte()
        body[1] = cmd.toByte()
        payload.copyInto(body, 2)
        val out = ByteArray(6 + body.size)
        out[0] = HEADER.toByte()
        out[1] = 0x40
        out[2] = seq.toByte()
        out[3] = crc8(body).toByte()
        out[4] = (body.size shr 8).toByte()
        out[5] = body.size.toByte()
        body.copyInto(out, 6)
        seq = (seq + 1) and 0xFF
        return out
    }

    fun name(cmd: Int): String = when (cmd) {
        0x1003 -> "Battery"
        0x1004 -> "Firmware"
        0x100D -> "DeviceInitialized"
        0x1120 -> "NetworkStatus"
        0x1124 -> "ControlWifi"
        0x1126 -> "OTAReady"
        MEDIA_CHANGES -> "MediaChanges(file saved)"
        REQUEST_AI -> "RequestAI(black)"
        RECORD_CONTROL -> "RecordControl"
        RECORD_DATA -> "RecordData(voice)"
        STOP_RECORD -> "StopRecord"
        WEARING -> "Wearing"
        AI_INTENT -> "AIIntent"
        INTENT_IMAGE -> "IntentImage(photo)"
        MEDIA_TRIGGER -> "MediaTrigger"
        PHOTO_BUTTON -> "PhotoButton(red)"
        else -> "0x%04X".format(cmd)
    }
}

class BkPacket(val flags: Int, val cmd: Int, val payload: ByteArray) {
    val isReply: Boolean get() = flags and BkProtocol.FLAG_REPLY != 0

    /** One log line; big payloads (photo, voice) are cut to their head. */
    fun describe(): String {
        val head = if (payload.size > 48) payload.copyOf(16).hex() + "… (${payload.size} B)" else payload.hex()
        return "${if (isReply) "reply" else "event"} ${BkProtocol.name(cmd)} [$head]"
    }
}

/**
 * Rebuilds packets from BLE notifications: one ED packet may span several notifications
 * (checked by LEN), and one payload may span several ED fragments (flag 0x80).
 */
class BkAssembler {
    private val pending = ByteArrayOutputStream()
    private val fragments = HashMap<Int, ByteArrayOutputStream>()
    var dropped = 0
        private set

    fun feed(chunk: ByteArray): List<BkPacket> {
        val out = mutableListOf<BkPacket>()
        if (pending.size() == 0 && (chunk.isEmpty() || (chunk[0].toInt() and 0xFF) != BkProtocol.HEADER)) {
            dropped += 1 // raw bytes outside the ED format (e.g. 03 00 01 01 00 01 on Wi-Fi changes)
            return out
        }
        pending.write(chunk)
        var data = pending.toByteArray()
        while (data.size >= 8) {
            if ((data[0].toInt() and 0xFF) != BkProtocol.HEADER) {
                dropped += 1
                data = ByteArray(0)
                break
            }
            val need = 6 + ((data[4].toInt() and 0xFF) shl 8 or (data[5].toInt() and 0xFF))
            if (data.size < need) break
            val flags = data[1].toInt() and 0xFF
            val cmd = (data[6].toInt() and 0xFF) shl 8 or (data[7].toInt() and 0xFF)
            val buffer = fragments.getOrPut(cmd) { ByteArrayOutputStream() }
            buffer.write(data, 8, need - 8)
            if (flags and BkProtocol.FLAG_MORE == 0) {
                fragments.remove(cmd)
                out += BkPacket(flags, cmd, buffer.toByteArray())
            }
            data = data.copyOfRange(need, data.size)
        }
        pending.reset()
        pending.write(data)
        return out
    }

    fun reset() {
        pending.reset()
        fragments.clear()
    }
}

fun ByteArray.hex(): String = joinToString(" ") { "%02X".format(it.toInt() and 0xFF) }
