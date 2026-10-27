package dev.chandra.data_pack_meter

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.TrafficStats
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The status bar meter: an ongoing, silent notification whose icon is the
 * current download speed. Ticks once a second while the screen is on and
 * sleeps while it is off.
 */
class SpeedMeterService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val sampler = SpeedSampler()
    private lateinit var icon: SpeedIcon
    private lateinit var worker: ExecutorService
    private var packLine: String? = null
    private var lastPackCheckMs = 0L
    private var ticking = false
    private var receiverRegistered = false

    private val tick = object : Runnable {
        override fun run() {
            update()
            handler.postDelayed(this, TICK_MS)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON -> startTicking()
                Intent.ACTION_SCREEN_OFF -> stopTicking()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Notifications.createChannels(this)
        icon = SpeedIcon(resources.displayMetrics.density)
        worker = Executors.newSingleThreadExecutor()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, Notifications.ID_METER, build(Speed.ZERO), type)
        running = true
        if (!receiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            ContextCompat.registerReceiver(this, screenReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }
        if (getSystemService(PowerManager::class.java).isInteractive) startTicking()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        stopTicking()
        if (receiverRegistered) {
            unregisterReceiver(screenReceiver)
            receiverRegistered = false
        }
        worker.shutdownNow()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startTicking() {
        if (ticking) return
        ticking = true
        // The counters kept growing while we slept; don't show that as one burst.
        sampler.reset()
        handler.post(tick)
    }

    private fun stopTicking() {
        ticking = false
        handler.removeCallbacks(tick)
    }

    private fun update() {
        val speed = sampler.sample(TrafficStats.getTotalRxBytes(), TrafficStats.getTotalTxBytes(), SystemClock.elapsedRealtime())
        if (Notifications.allowed(this)) {
            try {
                NotificationManagerCompat.from(this).notify(Notifications.ID_METER, build(speed))
            } catch (_: SecurityException) {
                // Notifications were just turned off; the next tick checks again.
            }
        }
        val now = SystemClock.elapsedRealtime()
        if (lastPackCheckMs == 0L || now - lastPackCheckMs >= PACK_CHECK_MS) {
            lastPackCheckMs = now
            worker.execute {
                val use = PackCheck.run(this)
                val line = use?.let { packLine(it) }
                handler.post { packLine = line }
            }
        }
    }

    private fun packLine(use: PackUse): String {
        val used = ByteFormat.bytes(use.usedBytes)
        val plan = use.plan ?: return getString(R.string.meter_text_today, used)
        return getString(R.string.meter_text_pack, used, ByteFormat.bytes(plan.limitBytes))
    }

    private fun build(speed: Speed): Notification {
        val stop = PendingIntent.getBroadcast(
            this,
            1,
            Intent(this, MeterStopReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, Notifications.CHANNEL_SPEED)
            .setSmallIcon(IconCompat.createWithBitmap(icon.render(ByteFormat.iconText(speed.rxPerSecond))))
            .setContentTitle(getString(R.string.meter_title, ByteFormat.speed(speed.rxPerSecond), ByteFormat.speed(speed.txPerSecond)))
            .setContentText(packLine)
            .setContentIntent(Notifications.openAppIntent(this))
            .addAction(0, getString(R.string.meter_stop), stop)
            .setOngoing(true)
            .setGroup(Notifications.GROUP_METER)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val TICK_MS = 1000L
        private const val PACK_CHECK_MS = 60_000L

        @Volatile
        var running = false
            private set

        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, SpeedMeterService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SpeedMeterService::class.java))
        }
    }
}
