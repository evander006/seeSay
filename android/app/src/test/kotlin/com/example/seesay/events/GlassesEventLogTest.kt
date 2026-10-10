package com.example.seesay.events

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GlassesEventLogTest {
    @Test
    fun saveDeduplicatesAndKeepsNewest() {
        val log = GlassesEventLog(limit = 2)
        assertTrue(log.save(event("a")))
        assertFalse(log.save(event("a")))
        assertTrue(log.save(event("b")))
        assertTrue(log.save(event("c")))
        assertEquals(listOf("c", "b"), log.snapshot().map { it.eventId })
    }

    @Test
    fun acknowledgeRemovesEventFromPending() {
        val log = GlassesEventLog()
        log.save(event("a"))
        assertEquals(1, log.pending().size)
        assertTrue(log.acknowledge("a"))
        assertTrue(log.pending().isEmpty())
        assertFalse(log.acknowledge("missing"))
    }

    @Test
    fun mockSourceStaysIdleUntilStarted() {
        val emitted = mutableListOf<GlassesDeviceEvent>()
        var scheduled = 0
        val source = MockGlassesEventSource(
            now = { "2026-10-09T12:00:00Z" },
            schedule = { _, _ ->
                scheduled += 1
                {}
            },
            emit = { emitted += it },
        )
        assertNull(source.trigger("TEXT_RECOGNIZED"))
        assertEquals(0, scheduled)
        source.start()
        assertEquals(1, scheduled)
        val event = source.trigger("TEXT_RECOGNIZED")
        assertEquals("mock", event?.source)
        assertEquals("Выход к платформам направо", event?.text)
        source.stop()
        assertNull(source.trigger("TEXT_RECOGNIZED"))
        assertFalse(source.isRunning)
    }

    private fun event(id: String) = GlassesDeviceEvent(
        eventId = id,
        type = "TEXT_RECOGNIZED",
        timestamp = "2026-10-09T12:00:00Z",
        source = "mock",
        status = "completed",
        text = "текст",
    )
}
