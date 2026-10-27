package dev.chandra.data_pack_meter

import java.text.NumberFormat
import java.util.Locale
import kotlin.math.roundToLong

/**
 * 1024-based byte formatting, matching the Flutter side (byte_format.dart):
 * units switch at 1000 so a number never has four digits, and values below
 * 10 keep up to two decimals, below 100 one, larger none.
 */
object ByteFormat {
    private const val KB = 1024L
    private const val MB = KB * 1024
    private const val GB = MB * 1024

    fun bytes(bytes: Long, locale: Locale = Locale.getDefault()): String {
        val value = bytes.coerceAtLeast(0)
        val (unit, size) = when {
            value >= 1000 * MB -> "GB" to GB
            value >= 1000 * KB -> "MB" to MB
            value >= 1000 -> "KB" to KB
            else -> return "${NumberFormat.getIntegerInstance(locale).format(value)} B"
        }
        return "${number(value.toDouble() / size, locale)} $unit"
    }

    fun speed(bytesPerSecond: Long, locale: Locale = Locale.getDefault()): String =
        "${bytes(bytesPerSecond, locale)}/s"

    /** What the status bar icon shows: a short number over a unit, like "1.2" / "MB/s". */
    data class IconText(val value: String, val unit: String)

    /**
     * Fits a speed into at most three characters. The icon never shows bytes:
     * anything under 1 KB/s is "0 KB/s".
     */
    fun iconText(bytesPerSecond: Long): IconText {
        val kb = bytesPerSecond.coerceAtLeast(0) / KB.toDouble()
        if (kb < 999.5) return IconText(kb.roundToLong().toString(), "KB/s")
        val mb = kb / 1024
        if (mb < 9.95) return IconText(oneDecimal(mb), "MB/s")
        if (mb < 999.5) return IconText(mb.roundToLong().toString(), "MB/s")
        val gb = mb / 1024
        return if (gb < 9.95) IconText(oneDecimal(gb), "GB/s") else IconText(gb.roundToLong().toString(), "GB/s")
    }

    private fun oneDecimal(value: Double): String {
        val tenths = (value * 10).roundToLong()
        return "${tenths / 10}.${tenths % 10}"
    }

    private fun number(value: Double, locale: Locale): String {
        val format = NumberFormat.getNumberInstance(locale)
        format.minimumFractionDigits = 0
        format.maximumFractionDigits = if (value < 10) 2 else if (value < 100) 1 else 0
        return format.format(value)
    }
}
