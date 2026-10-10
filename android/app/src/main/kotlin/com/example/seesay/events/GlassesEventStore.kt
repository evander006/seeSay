package com.example.seesay.events

import android.content.Context
import org.json.JSONArray

class GlassesEventStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val log = GlassesEventLog()

    init {
        val raw = prefs.getString(KEY_EVENTS, null)
        if (!raw.isNullOrBlank()) {
            val array = JSONArray(raw)
            val loaded = buildList {
                for (index in 0 until array.length()) {
                    add(GlassesDeviceEvent.fromJson(array.getJSONObject(index)))
                }
            }
            log.replace(loaded)
        }
    }

    var mockMode: Boolean
        get() = prefs.getBoolean(KEY_MOCK, true)
        set(value) {
            prefs.edit().putBoolean(KEY_MOCK, value).apply()
        }

    var monitoring: Boolean
        get() = prefs.getBoolean(KEY_MONITORING, false)
        set(value) {
            prefs.edit().putBoolean(KEY_MONITORING, value).apply()
        }

    fun save(event: GlassesDeviceEvent): Boolean {
        val saved = log.save(event)
        if (saved) persist()
        return saved
    }

    fun recent(): List<GlassesDeviceEvent> = log.snapshot()

    fun pending(): List<GlassesDeviceEvent> = log.pending()

    fun acknowledge(eventId: String): Boolean {
        val changed = log.acknowledge(eventId)
        if (changed) persist()
        return changed
    }

    private fun persist() {
        val array = JSONArray()
        log.snapshot().forEach { array.put(it.toJson()) }
        prefs.edit().putString(KEY_EVENTS, array.toString()).apply()
    }

    companion object {
        private const val PREFS = "aimb_glasses_events"
        private const val KEY_EVENTS = "events"
        private const val KEY_MOCK = "mock_mode"
        private const val KEY_MONITORING = "monitoring"
    }
}
