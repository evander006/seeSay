package com.example.seesay.events

import java.time.Instant

class MockGlassesEventSource(
    private val intervalMs: Long = 30_000L,
    private val now: () -> String = { Instant.now().toString() },
    private val schedule: (delayMs: Long, action: () -> Unit) -> () -> Unit,
    private val emit: (GlassesDeviceEvent) -> Unit,
) {
    private var cancel: (() -> Unit)? = null
    private var running = false
    private var sequence = 0

    val isRunning: Boolean get() = running

    fun start() {
        if (running) return
        running = true
        arm()
    }

    fun stop() {
        running = false
        cancel?.invoke()
        cancel = null
    }

    fun trigger(type: String): GlassesDeviceEvent? {
        if (!running) return null
        val event = build(type, sequence++)
        emit(event)
        return event
    }

    private fun arm() {
        cancel?.invoke()
        cancel = schedule(intervalMs) {
            if (running) {
                val type = cycle[sequence % cycle.size]
                sequence += 1
                emit(build(type, sequence))
                arm()
            }
        }
    }

    private fun build(type: String, index: Int): GlassesDeviceEvent {
        val text = when (type) {
            "TEXT_RECOGNIZED" -> "Выход к платформам направо"
            "SCENE_ANALYSIS_READY" -> "Перед вами вход в аптеку. Дверь справа."
            else -> null
        }
        return GlassesDeviceEvent(
            eventId = "mock-$index-${now()}",
            type = type,
            timestamp = now(),
            source = "mock",
            status = if (type == "DEVICE_ERROR") "failed" else "completed",
            text = text,
            batteryPercent = if (type == "BATTERY_CHANGED") 86 - (index % 5) * 4 else null,
            error = if (type == "DEVICE_ERROR") "Нет ответа от очков." else null,
        )
    }

    companion object {
        val cycle = listOf(
            "GLASSES_CONNECTED",
            "BATTERY_CHANGED",
            "TEXT_RECOGNIZED",
            "SCENE_ANALYSIS_READY",
            "PHOTO_CAPTURED",
            "DEVICE_ERROR",
            "GLASSES_DISCONNECTED",
        )
    }
}
