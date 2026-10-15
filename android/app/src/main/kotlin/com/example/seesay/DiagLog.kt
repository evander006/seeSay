package com.example.seesay

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Diagnostic log of the app: every BLE packet in/out (hex), sessions, uploads, errors.
 * Two files of 1 MB at most (seesay.log + seesay.1.log), so it never grows beyond ~2 MB.
 * Also mirrored to logcat under the tag "SeeSay".
 */
object DiagLog {
    private const val MAX_BYTES = 1_000_000L
    private var dir: File? = null
    private val time = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)

    fun init(context: Context) {
        if (dir == null) dir = File(context.filesDir, "logs").apply { mkdirs() }
    }

    fun i(tag: String, message: String) = write("I", tag, message)

    fun w(tag: String, message: String) = write("W", tag, message)

    fun e(tag: String, message: String, error: Throwable? = null) =
        write("E", tag, if (error == null) message else "$message: ${error.javaClass.simpleName}: ${error.message}")

    @Synchronized
    fun write(level: String, tag: String, message: String) {
        val line = "${time.format(Date())} $level $tag $message"
        Log.println(if (level == "E") Log.ERROR else Log.INFO, "SeeSay", "$tag $message")
        val folder = dir ?: return
        try {
            val file = File(folder, "seesay.log")
            if (file.length() > MAX_BYTES) {
                val old = File(folder, "seesay.1.log")
                old.delete()
                file.renameTo(old)
            }
            File(folder, "seesay.log").appendText(line + "\n")
        } catch (_: Exception) {
            // Logging must never break the app.
        }
    }

    /** Both files glued oldest-first, for upload or sharing. */
    @Synchronized
    fun export(context: Context): File {
        init(context)
        val folder = dir!!
        val out = File(context.cacheDir, "seesay-log.txt")
        out.writeText("")
        for (name in listOf("seesay.1.log", "seesay.log")) {
            val part = File(folder, name)
            if (part.exists()) out.appendBytes(part.readBytes())
        }
        return out
    }
}
