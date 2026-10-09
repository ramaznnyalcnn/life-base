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

    /** Google accounts that have calendars on this device. */
    fun googleAccounts(): List<String> {
        if (!hasPermission()) return emptyList()
        val accounts = sortedSetOf<String>()
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars.ACCOUNT_NAME),
            "${CalendarContract.Calendars.ACCOUNT_TYPE}=?",
            arrayOf(googleType),
            null,
        )?.use { cursor -> while (cursor.moveToNext()) cursor.getString(0)?.let(accounts::add) }
        return accounts.toList()
    }

    /**
     * Uses only calendars the Google account itself owns: holidays, birthdays,
     * subscribed/shared calendars and other accounts are left out. LifeBase
     * writes into that account's primary calendar.
     */
    fun connectGoogle(account: String): Boolean {
        val target = ownCalendars(account).firstOrNull { it.writable } ?: return false
        if (vault.calendarId() != target.id) clearProjectedEvents()
        vault.saveGoogleAccount(account)
        vault.saveCalendar(target.id)
        return true
    }

    fun googleStatus(): Map<String, Any?> = mapOf(
        "account" to vault.googleAccount(),
        "permission" to hasPermission(),
    )

    /** Events from the connected account's own calendars, minus LifeBase's projections. */
    fun deviceEvents(fromMillis: Long, toMillis: Long): List<Map<String, Any?>> {
        val account = vault.googleAccount() ?: return emptyList()
        if (!hasPermission()) return emptyList()
        val calendars = ownCalendars(account).map { it.id }.toSet()
        if (calendars.isEmpty()) return emptyList()
        val projected = vault.mappings().all.filterKeys { it.startsWith("calendar_mapping:") }.values.mapNotNull { it as? Long }.toSet()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.DISPLAY_COLOR,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.STATUS,
        )
        val result = mutableListOf<Map<String, Any?>>()
        CalendarContract.Instances.query(context.contentResolver, projection, fromMillis, toMillis)?.use { cursor ->
            while (cursor.moveToNext()) {
                val eventId = cursor.getLong(0)
                if (cursor.getLong(1) !in calendars || eventId in projected) continue
                if (cursor.getInt(8) == CalendarContract.Instances.STATUS_CANCELED) continue
                result += mapOf(
                    "id" to "$eventId:${cursor.getLong(3)}",
                    "title" to (cursor.getString(2) ?: ""),
                    "begin" to cursor.getLong(3),
                    "end" to cursor.getLong(4),
                    "all_day" to (cursor.getInt(5) == 1),
                    "color" to cursor.getInt(6),
                    "location" to cursor.getString(7),
                )
            }
        }
        return result.sortedBy { it["begin"] as Long }
    }

    private data class OwnCalendar(val id: Long, val writable: Boolean)

    private fun ownCalendars(account: String): List<OwnCalendar> {
        if (!hasPermission()) return emptyList()
        val result = mutableListOf<OwnCalendar>()
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
                CalendarContract.Calendars.IS_PRIMARY,
            ),
            "${CalendarContract.Calendars.ACCOUNT_TYPE}=? AND ${CalendarContract.Calendars.ACCOUNT_NAME}=? AND ${CalendarContract.Calendars.OWNER_ACCOUNT}=?",
            arrayOf(googleType, account, account),
            "${CalendarContract.Calendars.IS_PRIMARY} DESC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                result += OwnCalendar(cursor.getLong(0), cursor.getInt(1) >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR)
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
        private const val googleType = "com.google"

        fun oneTimeRequest(): OneTimeWorkRequest = OneTimeWorkRequestBuilder<SyncWorker>().addTag(SyncWorker.workTag).build()
    }
}
