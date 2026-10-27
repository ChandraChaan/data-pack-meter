package dev.chandra.data_pack_meter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.util.concurrent.Executors

/** Home-screen widget: today's (or this month's) use against the pack. */
class PackWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        executor.execute {
            try {
                render(context, manager, ids, WidgetModel.from(PackCheck.currentUse(context)))
            } finally {
                pending.finish()
            }
        }
    }

    override fun onEnabled(context: Context) {
        // Keeps the widget fresh every 15 minutes even without a pack or alerts.
        UsageCheckWorker.schedule(context)
    }

    companion object {
        private val executor = Executors.newSingleThreadExecutor()

        /** Redraws every placed widget. Call off the main thread with fresh numbers. */
        fun refresh(context: Context, use: PackUse?) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PackWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids, WidgetModel.from(use))
        }

        /** Reads fresh numbers in the background, then redraws. */
        fun refreshAsync(context: Context) {
            val app = context.applicationContext
            executor.execute { refresh(app, PackCheck.currentUse(app)) }
        }

        fun hasWidgets(context: Context): Boolean = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, PackWidget::class.java)).isNotEmpty()

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray, model: WidgetModel) {
            val views = RemoteViews(context.packageName, R.layout.widget_pack)
            views.setOnClickPendingIntent(R.id.widget_root, Notifications.openAppIntent(context))
            when (model) {
                WidgetModel.NoAccess -> {
                    views.setTextViewText(R.id.widget_title, context.getString(R.string.app_name))
                    views.setTextViewText(R.id.widget_used, context.getString(R.string.widget_no_access))
                    views.setViewVisibility(R.id.widget_progress, View.GONE)
                    views.setTextViewText(R.id.widget_detail, context.getString(R.string.widget_open_app))
                }
                is WidgetModel.NoPack -> {
                    views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_title_today))
                    views.setTextViewText(R.id.widget_used, ByteFormat.bytes(model.todayBytes))
                    views.setViewVisibility(R.id.widget_progress, View.GONE)
                    views.setTextViewText(R.id.widget_detail, context.getString(R.string.widget_set_up))
                }
                is WidgetModel.Pack -> {
                    val title = if (model.daily) R.string.widget_title_daily else R.string.widget_title_monthly
                    views.setTextViewText(
                        R.id.widget_title,
                        context.getString(title) + " · " + context.getString(R.string.widget_percent, model.percentUsed),
                    )
                    views.setTextViewText(
                        R.id.widget_used,
                        context.getString(
                            R.string.widget_used_of,
                            ByteFormat.bytes(model.usedBytes),
                            ByteFormat.bytes(model.limitBytes),
                        ),
                    )
                    views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    views.setProgressBar(R.id.widget_progress, 100, model.progress, false)
                    val amount = if (model.overBytes > 0) {
                        context.getString(R.string.widget_over, ByteFormat.bytes(model.overBytes))
                    } else {
                        context.getString(R.string.widget_left, ByteFormat.bytes(model.remainingBytes))
                    }
                    views.setTextViewText(
                        R.id.widget_detail,
                        context.getString(
                            R.string.widget_detail,
                            amount,
                            Notifications.durationText(context, model.timeLeft),
                        ),
                    )
                }
            }
            manager.updateAppWidget(ids, views)
        }
    }
}
