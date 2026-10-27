package dev.chandra.data_pack_meter

import org.junit.Assert.assertEquals
import org.junit.Test

class UidUsageTest {
    @Test
    fun sumsBucketsPerUidBusiestFirst() {
        val result = UidUsage.aggregate(
            sequenceOf(
                UidSample(10100, 100, 10),
                UidSample(10200, 5_000, 100),
                UidSample(10100, 300, 20),
                UidSample(1000, 50, 50),
            ),
        )
        assertEquals(
            listOf(UidTraffic(10200, 5_000, 100), UidTraffic(10100, 400, 30), UidTraffic(1000, 50, 50)),
            result,
        )
    }

    @Test
    fun mergesSystemUidsIntoOneRow() {
        val result = UidUsage.aggregate(
            sequenceOf(UidSample(0, 10, 0), UidSample(1000, 20, 0), UidSample(1051, 5, 5), UidSample(-5, 7, 0)),
        )
        assertEquals(listOf(UidTraffic(1000, 35, 5), UidTraffic(-5, 7, 0)), result)
    }

    @Test
    fun dropsEmptyRowsAndNegativeCounts() {
        val result = UidUsage.aggregate(sequenceOf(UidSample(10100, 0, 0), UidSample(10200, -5, 7)))
        assertEquals(listOf(UidTraffic(10200, 0, 7)), result)
    }

    @Test
    fun breaksTiesByUid() {
        val result = UidUsage.aggregate(sequenceOf(UidSample(10300, 5, 0), UidSample(10100, 5, 0)))
        assertEquals(listOf(10100, 10300), result.map { it.uid })
    }

    @Test
    fun classifiesUids() {
        assertEquals(UidKind.REMOVED, UidUsage.kindOf(-4))
        assertEquals(UidKind.TETHERING, UidUsage.kindOf(-5))
        assertEquals(UidKind.SYSTEM, UidUsage.kindOf(0))
        assertEquals(UidKind.SYSTEM, UidUsage.kindOf(1000))
        assertEquals(UidKind.APP, UidUsage.kindOf(10123))
        // Work profile (user 10): system and app ids keep their meaning.
        assertEquals(UidKind.SYSTEM, UidUsage.kindOf(1_001_000))
        assertEquals(UidKind.APP, UidUsage.kindOf(1_010_123))
    }
}
