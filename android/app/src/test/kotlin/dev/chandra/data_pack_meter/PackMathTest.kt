package dev.chandra.data_pack_meter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

class PackMathTest {
    private val india = ZoneId.of("Asia/Kolkata")
    private val utc = ZoneOffset.UTC
    private val gb = 1024L * 1024 * 1024

    private fun at(text: String) = Instant.parse(text)

    @Test
    fun dailyPackRunsFromLocalMidnight() {
        // 01:30 on 28 October in India.
        val period = PackMath.currentPeriod(PackPlan.Daily(gb), at("2026-10-27T20:00:00Z"), india)
        assertEquals(PackPeriod(at("2026-10-27T18:30:00Z"), at("2026-10-28T18:30:00Z")), period)
    }

    @Test
    fun dailyPackFollowsTheTimeZone() {
        val now = at("2026-10-27T20:00:00Z")
        assertEquals(at("2026-10-27T00:00:00Z"), PackMath.currentPeriod(PackPlan.Daily(gb), now, utc).start)
        assertEquals(
            at("2026-10-27T07:00:00Z"),
            PackMath.currentPeriod(PackPlan.Daily(gb), now, ZoneId.of("America/Los_Angeles")).start,
        )
    }

    @Test
    fun daylightSavingDayIs23Hours() {
        val period = PackMath.currentPeriod(PackPlan.Daily(gb), at("2026-03-29T12:00:00Z"), ZoneId.of("Europe/Berlin"))
        assertEquals(at("2026-03-28T23:00:00Z"), period.start)
        assertEquals(Duration.ofHours(23), Duration.between(period.start, period.end))
    }

    @Test
    fun monthlyPackClampsToShortMonths() {
        val plan = PackPlan.Monthly(30 * gb, 31)
        assertEquals(
            PackPeriod(at("2026-01-31T00:00:00Z"), at("2026-02-28T00:00:00Z")),
            PackMath.currentPeriod(plan, at("2026-02-27T10:00:00Z"), utc),
        )
        assertEquals(
            PackPeriod(at("2026-02-28T00:00:00Z"), at("2026-03-31T00:00:00Z")),
            PackMath.currentPeriod(plan, at("2026-03-10T10:00:00Z"), utc),
        )
    }

    @Test
    fun monthlyPackCrossesTheYear() {
        assertEquals(
            PackPeriod(at("2026-12-05T00:00:00Z"), at("2027-01-05T00:00:00Z")),
            PackMath.currentPeriod(PackPlan.Monthly(gb, 5), at("2027-01-02T00:00:00Z"), utc),
        )
    }

    @Test
    fun timeLeftNeverNegative() {
        val period = PackPeriod(at("2026-01-01T00:00:00Z"), at("2026-01-02T00:00:00Z"))
        assertEquals(Duration.ofHours(6), period.timeLeft(at("2026-01-01T18:00:00Z")))
        assertEquals(Duration.ZERO, period.timeLeft(at("2026-01-03T00:00:00Z")))
    }

    @Test
    fun durationPartsRoundUpToTheMinute() {
        assertEquals(Triple(2L, 4L, 30L), PackMath.durationParts(Duration.ofMinutes(2 * 1440 + 4 * 60 + 30)))
        assertEquals(Triple(0L, 0L, 1L), PackMath.durationParts(Duration.ofSeconds(1)))
        assertEquals(Triple(0L, 0L, 0L), PackMath.durationParts(Duration.ofMinutes(-5)))
    }

    @Test
    fun alertLevels() {
        assertEquals(AlertPolicy.NONE, AlertPolicy.levelFor(799, 1000))
        assertEquals(AlertPolicy.NEAR, AlertPolicy.levelFor(800, 1000))
        assertEquals(AlertPolicy.FULL, AlertPolicy.levelFor(1000, 1000))
        assertEquals(AlertPolicy.NONE, AlertPolicy.levelFor(5, 0))
    }

    @Test
    fun eachAlertShowsOncePerPeriod() {
        assertEquals(AlertPolicy.NEAR, AlertPolicy.alertToShow(850, 1000, AlertPolicy.NONE))
        assertNull(AlertPolicy.alertToShow(900, 1000, AlertPolicy.NEAR))
        assertEquals(AlertPolicy.FULL, AlertPolicy.alertToShow(1000, 1000, AlertPolicy.NEAR))
        assertNull(AlertPolicy.alertToShow(1500, 1000, AlertPolicy.FULL))
        // Jumping straight past 100% shows only the full alert.
        assertEquals(AlertPolicy.FULL, AlertPolicy.alertToShow(1200, 1000, AlertPolicy.NONE))
    }

    @Test
    fun hugePacksDoNotOverflow() {
        val limit = 100L * 1024 * gb
        assertEquals(AlertPolicy.NEAR, AlertPolicy.levelFor(limit * 9 / 10, limit))
    }
}
