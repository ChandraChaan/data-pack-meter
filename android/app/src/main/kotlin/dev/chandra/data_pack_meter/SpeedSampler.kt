package dev.chandra.data_pack_meter

/** Download and upload speed in bytes per second. */
data class Speed(val rxPerSecond: Long, val txPerSecond: Long) {
    companion object {
        val ZERO = Speed(0, 0)
    }
}

/**
 * Turns the device's ever-growing byte counters (TrafficStats) into speeds.
 *
 * Counters can go backwards when an interface disappears, and Android reports
 * -1 when it can't count; both read as zero rather than as a spike.
 */
class SpeedSampler {
    private var lastRx = -1L
    private var lastTx = -1L
    private var lastAtMs = 0L

    /** Feeds the counters read at [nowMs] (a monotonic clock); returns the speed since the last sample. */
    fun sample(rxTotal: Long, txTotal: Long, nowMs: Long): Speed {
        if (rxTotal < 0 || txTotal < 0) {
            reset()
            return Speed.ZERO
        }
        val first = lastRx < 0
        val elapsed = nowMs - lastAtMs
        if (!first && elapsed <= 0) return Speed.ZERO
        val speed = if (first) {
            Speed.ZERO
        } else {
            Speed(rate(rxTotal - lastRx, elapsed), rate(txTotal - lastTx, elapsed))
        }
        lastRx = rxTotal
        lastTx = txTotal
        lastAtMs = nowMs
        return speed
    }

    /** Forgets the last sample, for example after the screen was off. */
    fun reset() {
        lastRx = -1L
        lastTx = -1L
        lastAtMs = 0L
    }

    private fun rate(delta: Long, elapsedMs: Long): Long =
        if (delta <= 0) 0 else delta * 1000 / elapsedMs
}
