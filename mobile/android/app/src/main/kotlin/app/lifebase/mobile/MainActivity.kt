package app.lifebase.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
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
                    "listCalendars" -> result.success(CalendarSyncer(this).writableCalendars())
                    "selectCalendar" -> {
                        CredentialVault(this).saveCalendar(call.argument<Number>("id")!!.toLong())
                        WorkManager.getInstance(this).enqueue(CalendarSyncer.oneTimeRequest())
                        result.success(true)
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

    private fun hasCalendarAccess(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun requestCalendarAccess(result: MethodChannel.Result) {
        if (!hasCalendarAccess()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
                4201,
            )
        }
        result.success(hasCalendarAccess())
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
