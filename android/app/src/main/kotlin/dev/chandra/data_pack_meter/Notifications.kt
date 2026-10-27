package dev.chandra.data_pack_meter

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.time.Duration

object Notifications {
    const val CHANNEL_SPEED = "speed_meter"
    const val CHANNEL_ALERTS = "alerts"
    const val ID_METER = 1
    const val ID_ALERT = 2

    // Separate groups stop Android bundling the meter with alerts, which
    // would hide the meter's Turn off button inside a collapsed bundle.
    const val GROUP_METER = "dev.chandra.data_pack_meter.METER"
    private const val GROUP_ALERTS = "dev.chandra.data_pack_meter.ALERTS"

    fun createChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        // Early builds used a low-importance channel that hid the icon.
        manager.deleteNotificationChannel("speed")
        manager.createNotificationChannels(
            listOf(
                // Android hides the status bar icons of low-importance ("silent")
                // notifications, so the meter uses default importance with no
                // sound or vibration. It never peeks: heads-up needs high importance.
                NotificationChannel(
                    CHANNEL_SPEED,
                    context.getString(R.string.channel_speed),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = context.getString(R.string.channel_speed_description)
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                },
                NotificationChannel(
                    CHANNEL_ALERTS,
                    context.getString(R.string.channel_alerts),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = context.getString(R.string.channel_alerts_description) },
            ),
        )
    }

    fun allowed(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED)

    fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun showPackAlert(context: Context, level: Int, usedBytes: Long, limitBytes: Long, timeLeft: Duration) {
        if (!allowed(context)) return
        val used = ByteFormat.bytes(usedBytes)
        val limit = ByteFormat.bytes(limitBytes)
        val left = durationText(context, timeLeft)
        val (title, text) = if (level >= AlertPolicy.FULL) {
            context.getString(R.string.alert_full_title) to context.getString(R.string.alert_full_text, used, limit, left)
        } else {
            context.getString(R.string.alert_near_title) to context.getString(R.string.alert_near_text, used, limit, left)
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_stat_pack)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openAppIntent(context))
            .setAutoCancel(true)
            .setGroup(GROUP_ALERTS)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(ID_ALERT, notification)
        } catch (_: SecurityException) {
            // Permission revoked between the check and the post: nothing to show.
        }
    }

    fun durationText(context: Context, duration: Duration): String {
        val (days, hours, minutes) = PackMath.durationParts(duration)
        return when {
            days > 0 -> context.getString(R.string.duration_days_hours, days.toInt(), hours.toInt())
            hours > 0 -> context.getString(R.string.duration_hours_minutes, hours.toInt(), minutes.toInt())
            else -> context.getString(R.string.duration_minutes, minutes.toInt())
        }
    }
}
