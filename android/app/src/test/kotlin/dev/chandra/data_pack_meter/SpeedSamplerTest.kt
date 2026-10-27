package dev.chandra.data_pack_meter

import org.junit.Assert.assertEquals
import org.junit.Test

class SpeedSamplerTest {
    @Test
    fun firstSampleIsZero() {
        assertEquals(Speed.ZERO, SpeedSampler().sample(5_000_000, 1_000, 10_000))
    }

    @Test
    fun bytesPerSecondFromCounterDeltas() {
        val sampler = SpeedSampler()
        sampler.sample(1_000_000, 50_000, 0)
        assertEquals(Speed(2_048_000, 10_240), sampler.sample(3_048_000, 60_240, 1_000))
    }

    @Test
    fun scalesByElapsedTime() {
        val sampler = SpeedSampler()
        sampler.sample(0, 0, 0)
        // 3000 bytes over 1.5 s.
        assertEquals(Speed(2_000, 0), sampler.sample(3_000, 0, 1_500))
    }

    @Test
    fun counterGoingBackwardsReadsAsZero() {
        val sampler = SpeedSampler()
        sampler.sample(10_000, 10_000, 0)
        assertEquals(Speed.ZERO, sampler.sample(4_000, 2_000, 1_000))
        // And the next sample measures from the new, lower value.
        assertEquals(Speed(1_000, 0), sampler.sample(5_000, 2_000, 2_000))
    }

    @Test
    fun unsupportedCountersReadAsZero() {
        val sampler = SpeedSampler()
        sampler.sample(1_000, 1_000, 0)
        assertEquals(Speed.ZERO, sampler.sample(-1, -1, 1_000))
        assertEquals(Speed.ZERO, sampler.sample(9_000, 9_000, 2_000))
        assertEquals(Speed(1_000, 0), sampler.sample(10_000, 9_000, 3_000))
    }

    @Test
    fun noTimePassedIsZeroNotADivisionByZero() {
        val sampler = SpeedSampler()
        sampler.sample(1_000, 0, 5_000)
        assertEquals(Speed.ZERO, sampler.sample(2_000, 0, 5_000))
    }

    @Test
    fun resetAvoidsASpikeAfterSleeping() {
        val sampler = SpeedSampler()
        sampler.sample(0, 0, 0)
        sampler.reset()
        // 100 MB downloaded while the screen was off is not "speed now".
        assertEquals(Speed.ZERO, sampler.sample(100_000_000, 0, 600_000))
        assertEquals(Speed(500, 0), sampler.sample(100_000_500, 0, 601_000))
    }
}
