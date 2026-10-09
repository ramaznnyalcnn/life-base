package app.lifebase.mobile

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import androidx.work.OneTimeWorkRequest
import androidx.work.OneTimeWorkRequestBuilder
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class CalendarSyncer(private val context: Context) {
    private val vault = CredentialVault(context)

    fun writableCalendars(): List<Map<String, Any>> {
        if (!hasPermission()) return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
        )
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            "${CalendarContract.Calendars.VISIBLE}=1 AND ${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL}>=?",
            arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                result += mapOf(
                    "id" to cursor.getLong(0),
                    "name" to cursor.getString(1),
                    "account" to cursor.getString(2),
                    "selected" to (cursor.getLong(0) == vault.calendarId()),
                )
            }
        }
        return result
    }

    fun sync(): Boolean {
        val today = LocalDate.now(ZoneId.of("Europe/Istanbul"))
        val ranges = listOf(
            today.minusDays(30) to today.plusDays(60),
            today.plusDays(61) to today.plusDays(151),
            today.plusDays(152) to today.plusDays(180),
        )
        val items = ranges.flatMap { (from, to) -> fetch(from, to) ?: return false }
        updateWidgetSnapshot(today, items)
        ReminderScheduler(context).reconcile(items)
        val calendarId = vault.calendarId() ?: return true
        if (!hasPermission()) return true
        val seen = mutableSetOf<String>()
        items.forEach { item ->
            val sourceKey = item.getString("id")
            if (!item.optBoolean("calendar_exportable", true)) return@forEach
            upsert(calendarId, sourceKey, item)
            seen += sourceKey
        }
        removeMissing(seen)
        return true
    }

    fun clearProjectedEvents() {
        if (!hasPermission()) return
        val editor = vault.mappings().edit()
        vault.mappings().all
            .filterKeys { it.startsWith("calendar_mapping:") }
            .forEach { (key, value) ->
                (value as? Long)?.let { eventId ->
                    context.contentResolver.delete(
                        ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
                        null,
                        null,
                    )
                }
                editor.remove(key)
            }
        editor.apply()
    }

    private fun fetch(from: LocalDate, to: LocalDate): List<org.json.JSONObject>? {
        val server = vault.serverUrl() ?: return null
        val token = vault.token() ?: return null
        return runCatching {
            val url = URL("$server/api/v2/agenda/range?from=$from&to=$to&timezone=Europe%2FIstanbul")
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 8_000
            connection.readTimeout = 12_000
            connection.setRequestProperty("Authorization", "Bearer $token")
            if (connection.responseCode !in 200..299) return null
            val array = org.json.JSONObject(connection.inputStream.bufferedReader().use { it.readText() }).getJSONArray("items")
            List(array.length()) { index -> array.getJSONObject(index) }
        }.getOrNull()
    }

    private fun upsert(calendarId: Long, sourceKey: String, item: org.json.JSONObject) {
        val key = "calendar_mapping:$sourceKey"
        val existing = vault.mappings().getLong(key, -1)
        val start = if (item.isNull("starts_at")) {
            LocalDate.parse(item.getString("day")).atStartOfDay(ZoneId.of("Europe/Istanbul"))
        } else {
            ZonedDateTime.parse(item.getString("starts_at"))
        }
        val end = if (item.isNull("ends_at")) start.plusHours(1) else ZonedDateTime.parse(item.getString("ends_at"))
        val completed = item.optBoolean("is_completed")
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, (if (completed) "✓ " else "") + item.getString("title").removePrefix("✓ "))
            put(CalendarContract.Events.DESCRIPTION, "LifeBase · $sourceKey")
            put(CalendarContract.Events.DTSTART, start.toInstant().toEpochMilli())
            put(CalendarContract.Events.DTEND, end.toInstant().toEpochMilli())
            put(CalendarContract.Events.EVENT_TIMEZONE, "Europe/Istanbul")
            put(CalendarContract.Events.ALL_DAY, if (item.optBoolean("is_all_day")) 1 else 0)
            put(CalendarContract.Events.CUSTOM_APP_PACKAGE, context.packageName)
            put(CalendarContract.Events.CUSTOM_APP_URI, "lifebase://agenda/$sourceKey")
        }
        val eventId = if (existing >= 0) {
            context.contentResolver.update(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, existing), values, null, null)
            existing
        } else {
            context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)?.lastPathSegment?.toLongOrNull() ?: return
        }
        vault.mappings().edit().putLong(key, eventId).apply()
        replaceReminders(eventId, start, item.optJSONArray("reminders") ?: JSONArray())
    }

    private fun replaceReminders(eventId: Long, startsAt: ZonedDateTime, reminders: JSONArray) {
        context.contentResolver.delete(CalendarContract.Reminders.CONTENT_URI, "${CalendarContract.Reminders.EVENT_ID}=?", arrayOf(eventId.toString()))
        repeat(reminders.length()) { index ->
            val remindAt = ZonedDateTime.parse(reminders.getString(index))
            val minutes = java.time.Duration.between(remindAt, startsAt).toMinutes().coerceAtLeast(0).toInt()
            context.contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, ContentValues().apply {
                put(CalendarContract.Reminders.EVENT_ID, eventId)
                put(CalendarContract.Reminders.MINUTES, minutes)
                put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
            })
        }
    }

    private fun updateWidgetSnapshot(today: LocalDate, items: List<org.json.JSONObject>) {
        val current = items.filter { it.optString("day") == today.toString() && !it.optBoolean("is_completed") }
            .sortedBy { if (it.isNull("starts_at")) "9999" else it.optString("starts_at") }
        val next = current.firstOrNull()
        val actionable = current.firstOrNull { it.optString("kind") == "task" || it.optString("kind") == "medication" }
        val snapshot = org.json.JSONObject().apply {
            put("next", next?.optString("title").orEmpty())
            put("count", current.size)
            put("action", actionable?.let { item -> org.json.JSONObject().apply {
                put("kind", item.optString("kind"))
                put("id", item.opt("source_id"))
                put("scheduled_for", item.optJSONObject("metadata")?.optString("scheduled_for").orEmpty())
                put("entity_version", item.optJSONObject("metadata")?.optInt("entity_version") ?: 0)
            }})
        }
        vault.saveWidget(snapshot.toString())
    }

    private fun removeMissing(seen: Set<String>) {
        val editor = vault.mappings().edit()
        vault.mappings().all.filterKeys { it.startsWith("calendar_mapping:") }.forEach { (key, value) ->
            if (key.removePrefix("calendar_mapping:") !in seen) {
                (value as? Long)?.let { context.contentResolver.delete(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, it), null, null) }
                editor.remove(key)
            }
        }
        editor.apply()
    }

    private fun hasPermission() =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    companion object {
        fun oneTimeRequest(): OneTimeWorkRequest = OneTimeWorkRequestBuilder<SyncWorker>().addTag(SyncWorker.workTag).build()
    }
}
