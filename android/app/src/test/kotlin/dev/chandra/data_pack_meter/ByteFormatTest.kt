package dev.chandra.data_pack_meter

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class ByteFormatTest {
    private val en = Locale.US
    private val mb = 1024L * 1024
    private val gb = mb * 1024

    @Test
    fun matchesTheFlutterFormatter() {
        assertEquals("0 B", ByteFormat.bytes(0, en))
        assertEquals("999 B", ByteFormat.bytes(999, en))
        assertEquals("0.98 KB", ByteFormat.bytes(1000, en))
        assertEquals("1.5 KB", ByteFormat.bytes(1536, en))
        assertEquals("12.3 MB", ByteFormat.bytes((12.34 * mb).toLong(), en))
        assertEquals("123 MB", ByteFormat.bytes((123.4 * mb).toLong(), en))
        assertEquals("0.98 GB", ByteFormat.bytes(1000 * mb, en))
        assertEquals("1.5 GB", ByteFormat.bytes(gb * 3 / 2, en))
    }

    @Test
    fun negativeIsZero() {
        assertEquals("0 B", ByteFormat.bytes(-1, en))
    }

    @Test
    fun followsLocale() {
        assertEquals("1,5 GB", ByteFormat.bytes(gb * 3 / 2, Locale.GERMANY))
    }

    @Test
    fun speedAddsPerSecond() {
        assertEquals("250 KB/s", ByteFormat.speed(250 * 1024, en))
    }

    @Test
    fun iconTextFitsThreeCharacters() {
        assertEquals(ByteFormat.IconText("0", "KB/s"), ByteFormat.iconText(0))
        assertEquals(ByteFormat.IconText("0", "KB/s"), ByteFormat.iconText(300))
        assertEquals(ByteFormat.IconText("1", "KB/s"), ByteFormat.iconText(1024))
        assertEquals(ByteFormat.IconText("999", "KB/s"), ByteFormat.iconText(999 * 1024))
        // 999.6 KB/s would round to "1000"; it becomes MB/s instead.
        assertEquals(ByteFormat.IconText("1.0", "MB/s"), ByteFormat.iconText(1_023_600))
        assertEquals(ByteFormat.IconText("1.2", "MB/s"), ByteFormat.iconText((1.2 * mb).toLong()))
        assertEquals(ByteFormat.IconText("9.9", "MB/s"), ByteFormat.iconText((9.94 * mb).toLong()))
        assertEquals(ByteFormat.IconText("10", "MB/s"), ByteFormat.iconText((9.96 * mb).toLong()))
        assertEquals(ByteFormat.IconText("125", "MB/s"), ByteFormat.iconText(125 * mb))
        assertEquals(ByteFormat.IconText("1.2", "GB/s"), ByteFormat.iconText((1.2 * gb).toLong()))
    }

    @Test
    fun iconTextNeverExceedsThreeCharacters() {
        var bytes = 1L
        while (bytes < 100 * gb) {
            val text = ByteFormat.iconText(bytes)
            assert(text.value.length <= 3) { "$bytes -> $text" }
            bytes = bytes * 11 / 10 + 1
        }
    }
}
