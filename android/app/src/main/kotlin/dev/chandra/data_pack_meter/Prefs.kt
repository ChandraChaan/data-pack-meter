package dev.chandra.data_pack_meter

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit

/** Settings shared by the app, the meter service, alerts and the widget. */
class Prefs(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("data_pack_meter", Context.MODE_PRIVATE)

    var plan: PackPlan?
        get() {
            val limit = prefs.getLong(KEY_LIMIT, 0)
            if (limit <= 0) return null
            return when (prefs.getString(KEY_TYPE, null)) {
                "daily" -> PackPlan.Daily(limit)
                "monthly" -> PackPlan.Monthly(limit, prefs.getInt(KEY_RESET_DAY, 1).coerceIn(1, 31))
                else -> null
            }
        }
        set(value) = prefs.edit {
            when (value) {
                null -> remove(KEY_TYPE).remove(KEY_LIMIT)
                is PackPlan.Daily -> putString(KEY_TYPE, "daily").putLong(KEY_LIMIT, value.limitBytes)
                is PackPlan.Monthly -> putString(KEY_TYPE, "monthly")
                    .putLong(KEY_LIMIT, value.limitBytes)
                    .putInt(KEY_RESET_DAY, value.resetDay)
            }
        }

    var alertsEnabled: Boolean
        get() = prefs.getBoolean(KEY_ALERTS, true)
        set(value) = prefs.edit { putBoolean(KEY_ALERTS, value) }

    /** The user wants the status bar meter; the service may still be stopped. */
    var meterEnabled: Boolean
        get() = prefs.getBoolean(KEY_METER, false)
        set(value) = prefs.edit { putBoolean(KEY_METER, value) }

    var meterOnBoot: Boolean
        get() = prefs.getBoolean(KEY_METER_ON_BOOT, false)
        set(value) = prefs.edit { putBoolean(KEY_METER_ON_BOOT, value) }

    /** The highest alert already shown for the period starting at [periodStartMs]. */
    fun alertShown(periodStartMs: Long): Int =
        if (prefs.getLong(KEY_ALERT_PERIOD, -1) == periodStartMs) prefs.getInt(KEY_ALERT_LEVEL, 0) else 0

    fun setAlertShown(periodStartMs: Long, level: Int) = prefs.edit {
        putLong(KEY_ALERT_PERIOD, periodStartMs).putInt(KEY_ALERT_LEVEL, level)
    }

    /** Plan and alert switch for the platform channel (see channel_pack_repository.dart). */
    fun packToMap(): Map<String, Any?> {
        val plan = plan
        return mapOf(
            "type" to when (plan) {
                is PackPlan.Daily -> "daily"
                is PackPlan.Monthly -> "monthly"
                null -> null
            },
            "limitBytes" to (plan?.limitBytes ?: 0L),
            "resetDay" to ((plan as? PackPlan.Monthly)?.resetDay ?: 1),
            "alertsEnabled" to alertsEnabled,
        )
    }

    fun savePackFromMap(map: Map<*, *>) {
        val limit = (map["limitBytes"] as? Number)?.toLong() ?: 0L
        val resetDay = ((map["resetDay"] as? Number)?.toInt() ?: 1).coerceIn(1, 31)
        val newPlan = when (map["type"]) {
            "daily" -> if (limit > 0) PackPlan.Daily(limit) else null
            "monthly" -> if (limit > 0) PackPlan.Monthly(limit, resetDay) else null
            else -> null
        }
        if (newPlan != plan) {
            // A new pack starts its alerts afresh.
            prefs.edit { remove(KEY_ALERT_PERIOD).remove(KEY_ALERT_LEVEL) }
        }
        plan = newPlan
        alertsEnabled = map["alertsEnabled"] as? Boolean ?: true
    }

    private companion object {
        const val KEY_TYPE = "pack_type"
        const val KEY_LIMIT = "pack_limit_bytes"
        const val KEY_RESET_DAY = "pack_reset_day"
        const val KEY_ALERTS = "alerts_enabled"
        const val KEY_METER = "meter_enabled"
        const val KEY_METER_ON_BOOT = "meter_on_boot"
        const val KEY_ALERT_PERIOD = "alert_period_start"
        const val KEY_ALERT_LEVEL = "alert_level"
    }
}
