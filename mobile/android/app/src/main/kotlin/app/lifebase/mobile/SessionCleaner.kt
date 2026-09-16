package app.lifebase.mobile

import android.content.Context
import androidx.work.WorkManager
import app.lifebase.mobile.widget.LifeBaseWidget

object SessionCleaner {
    fun clear(context: Context) {
        CalendarSyncer(context).clearProjectedEvents()
        ReminderScheduler(context).cancelAll()
        CredentialVault(context).clearSession()
        WorkManager.getInstance(context).cancelUniqueWork(SyncWorker.uniqueName)
        WorkManager.getInstance(context).cancelAllWorkByTag(SyncWorker.workTag)
        LifeBaseWidget.requestUpdate(context)
    }
}
