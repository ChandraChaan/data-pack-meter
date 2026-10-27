package dev.chandra.data_pack_meter

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Duration
import java.time.Instant

class WidgetModelTest {
    private val mb = 1024L * 1024
    private val start = Instant.parse("2026-10-26T18:30:00Z")
    private val period = PackPeriod(start, Instant.parse("2026-10-27T18:30:00Z"))
    private val now = Instant.parse("2026-10-27T10:50:00Z")

    @Test
    fun noUsageAccessAsksToOpenTheApp() {
        assertEquals(WidgetModel.NoAccess, WidgetModel.from(null))
    }

    @Test
    fun noPackShowsTodayAlone() {
        assertEquals(WidgetModel.NoPack(42 * mb), WidgetModel.from(PackUse(null, period, 42 * mb, now)))
    }

    @Test
    fun packShowsUseAndTimeLeft() {
        val model = WidgetModel.from(PackUse(PackPlan.Daily(1536 * mb), period, 1100 * mb, now)) as WidgetModel.Pack
        assertEquals(71, model.percentUsed)
        assertEquals(71, model.progress)
        assertEquals(436 * mb, model.remainingBytes)
        assertEquals(0L, model.overBytes)
        assertEquals(Duration.ofMinutes(7 * 60 + 40), model.timeLeft)
        assertEquals(true, model.daily)
        assertEquals(AlertPolicy.NONE, model.level)
    }

    @Test
    fun overThePackCapsTheBarButNotTheText() {
        val model = WidgetModel.Pack(1500 * mb, 1000 * mb, daily = false, timeLeft = Duration.ZERO)
        assertEquals(150, model.percentUsed)
        assertEquals(100, model.progress)
        assertEquals(0L, model.remainingBytes)
        assertEquals(500 * mb, model.overBytes)
        assertEquals(AlertPolicy.FULL, model.level)
    }

    @Test
    fun percentRoundsDown() {
        assertEquals(99, WidgetModel.Pack(999, 1000, true, Duration.ZERO).percentUsed)
    }
}
