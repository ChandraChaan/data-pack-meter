package dev.chandra.data_pack_meter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import kotlin.math.roundToInt

/**
 * Draws the speed as a status bar icon: the number on top, the unit below.
 * Android only uses the alpha channel of small icons, so it is drawn in white.
 */
class SpeedIcon(density: Float) {
    private val size = (24 * density).roundToInt().coerceAtLeast(24)
    private val valuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private val unitPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private var lastText: ByteFormat.IconText? = null
    private var lastBitmap: Bitmap? = null

    fun render(text: ByteFormat.IconText): Bitmap {
        lastBitmap?.let { if (text == lastText) return it }
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        fit(valuePaint, text.value, size * 0.64f)
        fit(unitPaint, text.unit, size * 0.4f)
        canvas.drawText(text.value, center, size * 0.6f, valuePaint)
        canvas.drawText(text.unit, center, size * 0.97f, unitPaint)
        lastText = text
        lastBitmap = bitmap
        return bitmap
    }

    /** Uses [maxTextSize] unless the text would be wider than the icon. */
    private fun fit(paint: Paint, text: String, maxTextSize: Float) {
        paint.textSize = maxTextSize
        val width = paint.measureText(text)
        if (width > size) paint.textSize = maxTextSize * size / width
    }
}
