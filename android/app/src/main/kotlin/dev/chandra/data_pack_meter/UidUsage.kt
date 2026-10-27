package dev.chandra.data_pack_meter

/** One row of NetworkStats: traffic of [uid] in some bucket. */
data class UidSample(val uid: Int, val rxBytes: Long, val txBytes: Long)

data class UidTraffic(val uid: Int, val rxBytes: Long, val txBytes: Long) {
    val totalBytes get() = rxBytes + txBytes
}

enum class UidKind(val wireName: String) {
    APP("app"),
    SYSTEM("system"),
    REMOVED("removed"),
    TETHERING("tethering"),
}

object UidUsage {
    /** Android's NetworkStats.Bucket.UID_REMOVED and UID_TETHERING. */
    const val UID_REMOVED = -4
    const val UID_TETHERING = -5

    /** Process.FIRST_APPLICATION_UID: lower ids belong to Android itself. */
    private const val FIRST_APPLICATION_UID = 10000
    private const val PER_USER_RANGE = 100000

    /** Android's own uid; every system uid is reported under it. */
    const val SYSTEM_UID = 1000

    /**
     * Sums buckets per uid, dropping uids with no traffic, busiest first.
     * All of Android's system uids (root, DNS, media, ...) merge into one row.
     */
    fun aggregate(samples: Sequence<UidSample>): List<UidTraffic> {
        val rx = HashMap<Int, Long>()
        val tx = HashMap<Int, Long>()
        for (s in samples) {
            val uid = if (kindOf(s.uid) == UidKind.SYSTEM) SYSTEM_UID else s.uid
            rx[uid] = (rx[uid] ?: 0L) + s.rxBytes.coerceAtLeast(0)
            tx[uid] = (tx[uid] ?: 0L) + s.txBytes.coerceAtLeast(0)
        }
        return rx.keys
            .map { UidTraffic(it, rx.getValue(it), tx.getValue(it)) }
            .filter { it.totalBytes > 0 }
            .sortedWith(compareByDescending<UidTraffic> { it.totalBytes }.thenBy { it.uid })
    }

    fun kindOf(uid: Int): UidKind = when {
        uid == UID_REMOVED -> UidKind.REMOVED
        uid == UID_TETHERING -> UidKind.TETHERING
        // Work profiles and other users add multiples of 100000 to app ids.
        uid < 0 || uid % PER_USER_RANGE < FIRST_APPLICATION_UID -> UidKind.SYSTEM
        else -> UidKind.APP
    }
}
