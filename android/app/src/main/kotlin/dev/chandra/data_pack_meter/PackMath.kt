package dev.chandra.data_pack_meter

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

/** The user's pack, as saved by the app (see Prefs). Mirrors pack_plan.dart. */
sealed interface PackPlan {
    val limitBytes: Long

    data class Daily(override val limitBytes: Long) : PackPlan

    data class Monthly(override val limitBytes: Long, val resetDay: Int) : PackPlan
}

data class PackPeriod(val start: Instant, val end: Instant) {
    fun timeLeft(now: Instant): Duration =
        Duration.between(now, end).let { if (it.isNegative) Duration.ZERO else it }
}

/**
 * Pack windows for the background alerts and the widget. The same rules as
 * pack_period.dart: packs renew at local midnight, monthly ones on the reset
 * day or the month's last day if it is shorter.
 */
object PackMath {
    fun currentPeriod(plan: PackPlan, now: Instant, zone: ZoneId): PackPeriod {
        val today = now.atZone(zone).toLocalDate()
        val (start, end) = when (plan) {
            is PackPlan.Daily -> today to today.plusDays(1)
            is PackPlan.Monthly -> monthlyWindow(today, plan.resetDay)
        }
        return PackPeriod(start.atStartOfDay(zone).toInstant(), end.atStartOfDay(zone).toInstant())
    }

    fun today(now: Instant, zone: ZoneId): PackPeriod = currentPeriod(PackPlan.Daily(1), now, zone)

    private fun monthlyWindow(today: LocalDate, resetDay: Int): Pair<LocalDate, LocalDate> {
        val month = YearMonth.from(today)
        val thisMonth = resetIn(month, resetDay)
        return if (!today.isBefore(thisMonth)) {
            thisMonth to resetIn(month.plusMonths(1), resetDay)
        } else {
            resetIn(month.minusMonths(1), resetDay) to thisMonth
        }
    }

    private fun resetIn(month: YearMonth, resetDay: Int): LocalDate =
        month.atDay(resetDay.coerceIn(1, month.lengthOfMonth()))

    /** Days, hours and minutes left, rounded up to the minute. */
    fun durationParts(duration: Duration): Triple<Long, Long, Long> {
        val minutes = if (duration.isNegative) 0 else (duration.seconds + 59) / 60
        return Triple(minutes / (24 * 60), (minutes / 60) % 24, minutes % 60)
    }
}

/** When to alert: once at 80% and once at 100% of the pack, per period. */
object AlertPolicy {
    const val NONE = 0
    const val NEAR = 80
    const val FULL = 100

    fun levelFor(usedBytes: Long, limitBytes: Long): Int = when {
        limitBytes <= 0 -> NONE
        usedBytes >= limitBytes -> FULL
        // used / limit >= 0.8, without floating point.
        usedBytes * 5 >= limitBytes * 4 -> NEAR
        else -> NONE
    }

    /** The alert to show now, or null if [alreadyShown] covers it. */
    fun alertToShow(usedBytes: Long, limitBytes: Long, alreadyShown: Int): Int? =
        levelFor(usedBytes, limitBytes).takeIf { it > alreadyShown }
}
