package app.lifebase.mobile.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import app.lifebase.mobile.CredentialVault
import app.lifebase.mobile.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * 3×1 "Bugün": the next two or three things today, e.g. `09:00 Toplantı · 1sa`.
 *
 * The app writes a snapshot of today and tomorrow (see `widgetSnapshot` in
 * Dart); the widget refreshes itself every half hour and drops what has
 * ended, so it needs neither the network nor the app to be open.
 */
class LifeBaseWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val raw = CredentialVault(context).widget()
        val rows = todayRows(raw, LocalDate.now(), System.currentTimeMillis())
        val openToday = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("lifebase://open/today"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        provideContent { WidgetContent(rows, LocalDate.now(), openToday) }
    }

    companion object {
        fun requestUpdate(context: Context) {
            CoroutineScope(Dispatchers.Default).launch {
                GlanceAppWidgetManager(context).getGlanceIds(LifeBaseWidget::class.java)
                    .forEach { LifeBaseWidget().update(context, it) }
            }
        }

        /** Today's entries still ahead; null when the app has not written today yet. */
        fun todayRows(raw: String, today: LocalDate, nowMs: Long): List<Pair<String, String>>? {
            val days = runCatching { JSONObject(raw).getJSONObject("days") }.getOrNull() ?: return null
            val items = days.optJSONArray(today.toString()) ?: return null
            return (0 until items.length()).map { items.getJSONObject(it) }
                .filter { it.isNull("until") || it.optLong("until") > nowMs }
                .map { item ->
                    val detail = item.optString("detail")
                    item.optString("time") to (item.optString("title") + if (detail.isNotBlank()) " · $detail" else "")
                }
        }
    }
}

private val background = Color(0xFF161C24)
private val ink = Color(0xFFF2F4F7)
private val muted = Color(0xFF9AA4B2)
private val accent = Color(0xFFF2C14E)

@Composable
private fun WidgetContent(rows: List<Pair<String, String>>?, today: LocalDate, open: Intent) {
    val date = today.format(DateTimeFormatter.ofPattern("d MMMM EEEE", Locale.forLanguageTag("tr-TR")))
    Column(
        modifier = GlanceModifier.fillMaxSize().cornerRadius(20.dp).background(ColorProvider(background))
            .padding(horizontal = 16.dp, vertical = 10.dp).clickable(actionStartActivity(open)),
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text("Bugün", style = TextStyle(color = ColorProvider(accent), fontWeight = FontWeight.Bold, fontSize = 14.sp))
            Spacer(GlanceModifier.width(8.dp))
            Text(date, style = TextStyle(color = ColorProvider(muted), fontSize = 12.sp), maxLines = 1)
        }
        Spacer(GlanceModifier.height(4.dp))
        when {
            rows == null -> Line("Programı görmek için uygulamayı aç", muted)
            rows.isEmpty() -> Line("Bugün başka plan yok", muted)
            else -> rows.take(3).forEach { (time, title) ->
                Row(modifier = GlanceModifier.fillMaxWidth()) {
                    Text(time, style = TextStyle(color = ColorProvider(ink), fontWeight = FontWeight.Bold, fontSize = 13.sp), maxLines = 1)
                    Spacer(GlanceModifier.width(8.dp))
                    Text(title, style = TextStyle(color = ColorProvider(ink), fontSize = 13.sp), maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun Line(text: String, color: Color) {
    Text(text, style = TextStyle(color = ColorProvider(color), fontSize = 13.sp), maxLines = 1)
}

class LifeBaseWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = LifeBaseWidget()
}
