package app.lifebase.mobile.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Button
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import app.lifebase.mobile.CredentialVault
import app.lifebase.mobile.SyncWorker
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

class LifeBaseWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val raw = CredentialVault(context).widget()
        provideContent { WidgetContent(raw) }
    }

    companion object {
        fun requestUpdate(context: Context) {
            CoroutineScope(Dispatchers.Default).launch {
                GlanceAppWidgetManager(context).getGlanceIds(LifeBaseWidget::class.java)
                    .forEach { LifeBaseWidget().update(context, it) }
            }
        }
    }
}

@Composable
private fun WidgetContent(raw: String) {
    val json = runCatching { JSONObject(raw) }.getOrNull()
    val next = json?.optString("next")?.takeIf { it.isNotBlank() } ?: "Plan beklemiyor"
    val count = json?.optInt("count") ?: 0
    val action = json?.optJSONObject("action")
    Column(
        modifier = GlanceModifier.fillMaxSize().background(ColorProvider(Color(0xFF101719))).padding(16.dp),
    ) {
        Text("BUGÜN", style = TextStyle(color = ColorProvider(Color(0xFF2DD4BF)), fontWeight = FontWeight.Bold))
        Text(next, style = TextStyle(color = ColorProvider(Color(0xFFF2F7F6)), fontWeight = FontWeight.Bold))
        Text("$count öğe", style = TextStyle(color = ColorProvider(Color(0xFFA8B5B2))))
        if (action != null) {
            Button(
                text = if (action.optString("kind") == "medication") "Alındı" else "Tamamla",
                onClick = actionRunCallback<WidgetActionCallback>(
                    actionParametersOf(
                        WidgetActionCallback.kindKey to action.optString("kind"),
                        WidgetActionCallback.idKey to action.optString("id"),
                        WidgetActionCallback.scheduledKey to action.optString("scheduled_for"),
                        WidgetActionCallback.versionKey to action.optInt("entity_version"),
                    ),
                ),
            )
        }
    }
}

class LifeBaseWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = LifeBaseWidget()
}

class WidgetActionCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val kind = parameters[kindKey] ?: return
        val id = parameters[idKey] ?: return
        val scheduled = parameters[scheduledKey].orEmpty()
        val version = parameters[versionKey] ?: return
        val requestId = UUID.randomUUID().toString()
        val operation = if (kind == "medication") {
            """{"request_id":"$requestId","operation_key":"health.medication.take","medication_id":$id,"scheduled_for":"$scheduled"}"""
        } else {
            """{"request_id":"$requestId","operation_key":"planning.task.complete","task_id":$id,"expected_version":$version}"""
        }
        val request = OneTimeWorkRequestBuilder<SyncWorker>()
            .setInputData(Data.Builder().putString("operation", operation).build())
            .addTag(SyncWorker.workTag)
            .build()
        WorkManager.getInstance(context).enqueue(request)
    }

    companion object {
        val kindKey = ActionParameters.Key<String>("kind")
        val idKey = ActionParameters.Key<String>("id")
        val scheduledKey = ActionParameters.Key<String>("scheduled")
        val versionKey = ActionParameters.Key<Int>("version")
    }
}
