package com.example.seesay.events

import org.json.JSONObject

data class GlassesDeviceEvent(
    val eventId: String,
    val type: String,
    val timestamp: String,
    val source: String,
    val status: String,
    val text: String? = null,
    val batteryPercent: Int? = null,
    val error: String? = null,
    val acknowledged: Boolean = false,
) {
    fun toJson(): JSONObject {
        return JSONObject()
            .put("eventId", eventId)
            .put("type", type)
            .put("timestamp", timestamp)
            .put("source", source)
            .put("status", status)
            .put("text", text ?: JSONObject.NULL)
            .put("batteryPercent", batteryPercent ?: JSONObject.NULL)
            .put("error", error ?: JSONObject.NULL)
            .put("acknowledged", acknowledged)
    }

    fun toMap(): Map<String, Any?> {
        return mapOf(
            "event" to "glassesEvent",
            "eventId" to eventId,
            "type" to type,
            "timestamp" to timestamp,
            "source" to source,
            "status" to status,
            "text" to text,
            "batteryPercent" to batteryPercent,
            "error" to error,
            "acknowledged" to acknowledged,
        )
    }

    companion object {
        fun fromJson(raw: JSONObject): GlassesDeviceEvent {
            return GlassesDeviceEvent(
                eventId = raw.getString("eventId"),
                type = raw.getString("type"),
                timestamp = raw.getString("timestamp"),
                source = raw.optString("source", "mock"),
                status = raw.optString("status", "completed"),
                text = raw.optString("text").takeIf { raw.has("text") && !raw.isNull("text") },
                batteryPercent = if (raw.has("batteryPercent") && !raw.isNull("batteryPercent")) {
                    raw.getInt("batteryPercent")
                } else {
                    null
                },
                error = raw.optString("error").takeIf { raw.has("error") && !raw.isNull("error") },
                acknowledged = raw.optBoolean("acknowledged", false),
            )
        }
    }
}

class GlassesEventLog(private val limit: Int = 100) {
    private val items = mutableListOf<GlassesDeviceEvent>()

    fun snapshot(): List<GlassesDeviceEvent> = items.toList()

    fun replace(events: List<GlassesDeviceEvent>) {
        items.clear()
        items.addAll(events.take(limit))
    }

    fun save(event: GlassesDeviceEvent): Boolean {
        if (items.any { it.eventId == event.eventId }) return false
        items.add(0, event)
        while (items.size > limit) items.removeAt(items.lastIndex)
        return true
    }

    fun pending(): List<GlassesDeviceEvent> = items.filter { !it.acknowledged }

    fun acknowledge(eventId: String): Boolean {
        val index = items.indexOfFirst { it.eventId == eventId }
        if (index < 0) return false
        val current = items[index]
        items[index] = current.copy(acknowledged = true)
        return true
    }
}
