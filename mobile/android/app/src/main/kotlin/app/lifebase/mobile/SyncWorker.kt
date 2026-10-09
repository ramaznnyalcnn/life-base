package app.lifebase.mobile

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import app.lifebase.mobile.widget.LifeBaseWidget
import java.net.HttpURLConnection
import java.net.URL

class SyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val operation = inputData.getString("operation")
        if (operation != null) {
            when (postOperation(operation)) {
                PostOutcome.retry -> return Result.retry()
                PostOutcome.authFailure -> {
                    SessionCleaner.clear(applicationContext)
                    return Result.success()
                }
                PostOutcome.accepted,
                PostOutcome.refresh,
                PostOutcome.rejected -> Unit
            }
        }
        val refreshed = CalendarSyncer(applicationContext).sync()
        LifeBaseWidget.requestUpdate(applicationContext)
        return if (operation == null && !refreshed) Result.retry() else Result.success()
    }

    private fun postOperation(payload: String): PostOutcome {
        val vault = CredentialVault(applicationContext)
        val server = vault.serverUrl() ?: return PostOutcome.rejected
        val token = vault.token() ?: return PostOutcome.rejected
        return try {
            val connection = URL("$server/api/v2/operations/execute").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 8_000
            connection.readTimeout = 10_000
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            connection.outputStream.use { it.write(payload.toByteArray()) }
            when (connection.responseCode) {
                in 200..299 -> PostOutcome.accepted
                401, 403 -> PostOutcome.authFailure
                409 -> PostOutcome.refresh
                in 500..599 -> PostOutcome.retry
                else -> PostOutcome.rejected
            }
        } catch (_: Exception) {
            PostOutcome.retry
        }
    }

    private enum class PostOutcome { accepted, refresh, authFailure, rejected, retry }

    companion object {
        const val uniqueName = "lifebase-periodic-sync"
        const val workTag = "lifebase-sync"
    }
}
