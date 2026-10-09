package app.lifebase.mobile

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import app.lifebase.mobile.widget.LifeBaseWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "app.lifebase.mobile/platform"
    private val calendarRequestCode = 4201

    override fun onCreate(savedInstanceState: Bundle?) {
        showOverLockScreenForDoseAlarm(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        showOverLockScreenForDoseAlarm(intent)
        super.onNewIntent(intent)
    }

    /**
     * Only a dose alarm may appear above the lock screen; the rest of the app
     * (wallet, cards) stays behind it. Dart turns this off when the alarm closes.
     */
    private fun showOverLockScreenForDoseAlarm(intent: Intent?) {
        if (intent?.getStringExtra("payload")?.startsWith("med|") == true) setShowOverLockScreen(true)
    }

    private fun setShowOverLockScreen(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestCalendarAccess" -> requestCalendarAccess(result)
                    "requestNotificationAccess" -> requestNotificationAccess(result)
                    "requestOnboardingPermissions" -> requestOnboardingPermissions(result)
                    "calendarWritable" -> result.success(hasCalendarAccess())
                    "scheduleSync" -> {
                        schedulePeriodicSync()
                        result.success(true)
                    }
                    "syncNow" -> {
                        WorkManager.getInstance(this).enqueue(CalendarSyncer.oneTimeRequest())
                        result.success(true)
                    }
                    "clearSession" -> {
                        SessionCleaner.clear(this)
                        result.success(true)
                    }
                    "setShowOverLockScreen" -> {
                        setShowOverLockScreen(call.argument<Boolean>("enabled") == true)
                        result.success(true)
                    }
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "googleAccounts" -> result.success(CalendarSyncer(this).googleAccounts())
                    "googleStatus" -> result.success(CalendarSyncer(this).googleStatus())
                    "connectGoogle" -> {
                        val connected = CalendarSyncer(this).connectGoogle(call.argument<String>("account").orEmpty())
                        if (connected) WorkManager.getInstance(this).enqueue(CalendarSyncer.oneTimeRequest())
                        result.success(connected)
                    }
                    "projectLocalEvents" -> {
                        val items = org.json.JSONArray(call.argument<String>("items") ?: "[]")
                        Thread {
                            runCatching { CalendarSyncer(this).projectLocal(items) }
                            runOnUiThread { result.success(true) }
                        }.start()
                    }
                    "deviceEvents" -> {
                        val from = call.argument<Number>("from")!!.toLong()
                        val to = call.argument<Number>("to")!!.toLong()
                        // Calendar provider queries can be slow; keep them off the UI thread.
                        Thread {
                            val events = runCatching { CalendarSyncer(this).deviceEvents(from, to) }.getOrDefault(emptyList())
                            runOnUiThread { result.success(events) }
                        }.start()
                    }
                    "saveSyncConfig" -> {
                        CredentialVault(this).save(
                            call.argument<String>("serverUrl").orEmpty(),
                            call.argument<String>("token").orEmpty(),
                        )
                        result.success(true)
                    }
                    "updateWidgetSnapshot" -> {
                        CredentialVault(this).saveWidget(call.argument<String>("payload").orEmpty())
                        LifeBaseWidget.requestUpdate(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Android 14+ lets the user withhold alarm-style full-screen alerts. */
    private fun canUseFullScreenIntent(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            getSystemService(NotificationManager::class.java).canUseFullScreenIntent()

    private fun hasCalendarAccess(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private var pendingCalendarResult: MethodChannel.Result? = null

    /** Answers only after the user has responded to the permission dialog. */
    private fun requestCalendarAccess(result: MethodChannel.Result) {
        if (hasCalendarAccess()) {
            result.success(true)
            return
        }
        pendingCalendarResult?.success(false)
        pendingCalendarResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            calendarRequestCode,
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == calendarRequestCode) {
            pendingCalendarResult?.success(hasCalendarAccess())
            pendingCalendarResult = null
        }
    }

    private fun requestNotificationAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4202)
        result.success(false)
    }

    private fun requestOnboardingPermissions(result: MethodChannel.Result) {
        val permissions = mutableListOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) permissions += Manifest.permission.POST_NOTIFICATIONS
        val missing = permissions.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) ActivityCompat.requestPermissions(this, missing.toTypedArray(), 4203)
        result.success(missing.isEmpty())
    }

    private fun schedulePeriodicSync() {
        val request = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES).addTag(SyncWorker.workTag).build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            SyncWorker.uniqueName,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }
}
