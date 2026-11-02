package app.vercel.justaman045.money_control

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class MoneyControlWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val balance = widgetData.getString("mc_balance", "—") ?: "—"
            // Default true: a widget placed before the setting existed keeps
            // its shortcut instead of silently losing it on upgrade.
            val showQuickAdd = widgetData.getBoolean("mc_show_quick_add", true)

            val views = RemoteViews(context.packageName, R.layout.home_widget)
            views.setTextViewText(R.id.widget_balance, balance)
            views.setViewVisibility(
                R.id.widget_tap_hint,
                if (showQuickAdd) View.VISIBLE else View.GONE
            )

            // Tap widget body → open app home
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingOpen = PendingIntent.getActivity(
                context, 0, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingOpen)

            // Tap "+ Add" → open add transaction screen. Uses the home_widget
            // launch action so HomeWidget.initiallyLaunchedFromHomeWidget() and
            // HomeWidget.widgetClicked() deliver the deep link to Flutter.
            val pendingAdd = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("homeWidget://add_transaction")
            )
            views.setOnClickPendingIntent(R.id.widget_tap_hint, pendingAdd)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
