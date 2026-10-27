package dev.chandra.data_pack_meter

import android.content.Context
import java.time.Instant
import java.time.ZoneId

/** Mobile data used so far in the current pack period. */
data class PackUse(val plan: PackPlan?, val period: PackPeriod, val usedBytes: Long, val now: Instant)

/** Reads pack use and raises the 80% and 100% alerts. Runs off the main thread. */
object PackCheck {
    /**
     * Today's use when no pack is set, the pack period's otherwise.
     * Null without Usage Access.
     */
    fun currentUse(context: Context): PackUse? {
        val stats = UsageStats(context)
        if (!stats.hasUsageAccess()) return null
        val plan = Prefs(context).plan
        val now = Instant.now()
        val zone = ZoneId.systemDefault()
        val period = if (plan != null) PackMath.currentPeriod(plan, now, zone) else PackMath.today(now, zone)
        return try {
            PackUse(plan, period, stats.mobileBytes(period.start.toEpochMilli(), now.toEpochMilli()), now)
        } catch (_: NoUsageAccessException) {
            null
        }
    }

    /** Shows an alert if usage crossed 80% or 100% since the last one. */
    fun alertIfNeeded(context: Context, use: PackUse?) {
        val plan = use?.plan ?: return
        val prefs = Prefs(context)
        if (!prefs.alertsEnabled) return
        val periodStart = use.period.start.toEpochMilli()
        val level = AlertPolicy.alertToShow(use.usedBytes, plan.limitBytes, prefs.alertShown(periodStart)) ?: return
        Notifications.showPackAlert(context, level, use.usedBytes, plan.limitBytes, use.period.timeLeft(use.now))
        prefs.setAlertShown(periodStart, level)
    }

    fun run(context: Context): PackUse? = currentUse(context).also { alertIfNeeded(context, it) }
}
