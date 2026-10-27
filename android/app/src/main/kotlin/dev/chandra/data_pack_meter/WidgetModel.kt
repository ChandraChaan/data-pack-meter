package dev.chandra.data_pack_meter

import java.time.Duration

/** What the home-screen widget shows. Pure, so it is unit-tested on the JVM. */
sealed interface WidgetModel {
    /** Usage Access is off: the widget asks the user to open the app. */
    data object NoAccess : WidgetModel

    /** No pack set yet: show today's mobile use alone. */
    data class NoPack(val todayBytes: Long) : WidgetModel

    data class Pack(
        val usedBytes: Long,
        val limitBytes: Long,
        val daily: Boolean,
        val timeLeft: Duration,
    ) : WidgetModel {
        /** 0 to 100 for the progress bar; the text can say more than 100%. */
        val progress: Int get() = percentUsed.coerceIn(0, 100)

        /** Rounded down, so 99.6% never reads as 100%. Matches pack_status.dart. */
        val percentUsed: Int get() = if (limitBytes <= 0) 0 else (usedBytes * 100 / limitBytes).toInt()

        val remainingBytes: Long get() = (limitBytes - usedBytes).coerceAtLeast(0)

        val overBytes: Long get() = (usedBytes - limitBytes).coerceAtLeast(0)

        val level: Int get() = AlertPolicy.levelFor(usedBytes, limitBytes)
    }

    companion object {
        fun from(use: PackUse?): WidgetModel {
            if (use == null) return NoAccess
            val plan = use.plan ?: return NoPack(use.usedBytes)
            return Pack(use.usedBytes, plan.limitBytes, plan is PackPlan.Daily, use.period.timeLeft(use.now))
        }
    }
}
