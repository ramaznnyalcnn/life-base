package app.lifebase.mobile

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class ReminderScheduler(private val context: Context) {
    private val preferences = CredentialVault(context).mappings()

    fun reconcile(items: List<JSONObject>) {
        val current = mutableSetOf<String>()
        items.forEach { item ->
            val reminders = item.optJSONArray("reminders") ?: return@forEach
            repeat(reminders.length()) { index ->
                val key = "${item.optString("id")}:$index"
                val trigger = runCatching { java.time.ZonedDateTime.parse(reminders.getString(index)).toInstant().toEpochMilli() }.getOrNull()
                if (trigger != null && trigger > System.currentTimeMillis()) {
                    schedule(key, item.optString("title", "LifeBase"), trigger)
                    current += key
                }
            }
        }
        val previous = preferences.getStringSet(alarmKeys, emptySet()).orEmpty()
        (previous - current).forEach(::cancel)
        preferences.edit().putStringSet(alarmKeys, current).apply()
    }

    fun schedule(key: String, title: String, triggerAtMillis: Long) {
        if (triggerAtMillis <= System.currentTimeMillis()) return
        val manager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ReminderReceiver::class.java)
            .putExtra("key", key)
            .putExtra("title", title)
        val pending = PendingIntent.getBroadcast(
            context,
            key.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    fun cancelAll() {
        preferences.getStringSet(alarmKeys, emptySet()).orEmpty().forEach(::cancel)
        preferences.edit().remove(alarmKeys).apply()
    }

    private fun cancel(key: String) {
        val pending = PendingIntent.getBroadcast(
            context,
            key.hashCode(),
            Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    companion object { private const val alarmKeys = "scheduled_alarm_keys" }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(channelId, "LifeBase hatırlatmaları", NotificationManager.IMPORTANCE_HIGH))
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(intent.getStringExtra("title") ?: "LifeBase")
            .setContentText("Planlanan zaman geldi.")
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        // One notification per reminder: two items with the same title must not replace each other.
        manager.notify((intent.getStringExtra("key") ?: intent.getStringExtra("title") ?: "lifebase").hashCode(), notification)
    }

    companion object { private const val channelId = "lifebase_reminders" }
}
