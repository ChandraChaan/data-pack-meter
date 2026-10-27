package dev.chandra.data_pack_meter

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Hosts the Flutter UI and answers its platform channel calls. */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val background: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "dev.chandra.data_pack_meter/native").setMethodCallHandler(::onCall)
        EventChannel(messenger, "dev.chandra.data_pack_meter/speed").setStreamHandler(SpeedStream())

        Notifications.createChannels(this)
        val prefs = Prefs(this)
        if (prefs.plan != null) UsageCheckWorker.schedule(this)
        // The meter may have been refused a start at boot; the app is in front now.
        if (prefs.meterEnabled && !SpeedMeterService.running) SpeedMeterService.start(this)
    }

    override fun onDestroy() {
        background.shutdown()
        super.onDestroy()
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        val prefs = Prefs(this)
        when (call.method) {
            "getPack" -> result.success(prefs.packToMap())
            "savePack" -> {
                prefs.savePackFromMap(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                if (prefs.plan != null) UsageCheckWorker.schedule(this)
                result.success(null)
            }
            "hasUsageAccess" -> result.success(UsageStats(this).hasUsageAccess())
            "openUsageAccessSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            "deviceUsage" -> query(result) {
                val (start, end) = window(call)
                val stats = UsageStats(this)
                val mobile = stats.deviceTraffic(ConnectivityManager.TYPE_MOBILE, start, end)
                val wifi = stats.deviceTraffic(ConnectivityManager.TYPE_WIFI, start, end)
                mapOf(
                    "mobileRx" to mobile.first,
                    "mobileTx" to mobile.second,
                    "wifiRx" to wifi.first,
                    "wifiTx" to wifi.second,
                )
            }
            "appUsage" -> query(result) {
                val (start, end) = window(call)
                val type = if (call.argument<String>("network") == "wifi") {
                    ConnectivityManager.TYPE_WIFI
                } else {
                    ConnectivityManager.TYPE_MOBILE
                }
                val stats = UsageStats(this)
                stats.appTraffic(type, start, end).map(stats::describe)
            }
            "meterState" -> result.success(
                mapOf(
                    // What the user chose; the service follows it (and restarts if killed).
                    "running" to prefs.meterEnabled,
                    "startOnBoot" to prefs.meterOnBoot,
                    "notificationsAllowed" to Notifications.allowed(this),
                ),
            )
            "startMeter" -> {
                prefs.meterEnabled = true
                SpeedMeterService.start(this)
                result.success(null)
            }
            "stopMeter" -> {
                prefs.meterEnabled = false
                SpeedMeterService.stop(this)
                result.success(null)
            }
            "setStartOnBoot" -> {
                prefs.meterOnBoot = call.argument<Boolean>("enabled") == true
                result.success(null)
            }
            "requestNotificationPermission" -> requestNotificationPermission(result)
            else -> result.notImplemented()
        }
    }

    /** Runs a NetworkStats query off the main thread and replies on it. */
    private fun query(result: MethodChannel.Result, block: () -> Any?) {
        background.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: NoUsageAccessException) {
                main.post { result.error("NO_USAGE_ACCESS", e.message, null) }
            } catch (e: RuntimeException) {
                main.post { result.error("STATS_FAILED", e.message, null) }
            }
        }
    }

    private fun window(call: MethodCall): Pair<Long, Long> {
        val start = call.argument<Number>("startMs")?.toLong() ?: 0L
        val end = call.argument<Number>("endMs")?.toLong() ?: System.currentTimeMillis()
        return start to end
    }

    private fun openUsageAccessSettings() {
        // Newer Android versions open this app's own page when given its package.
        val direct = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:$packageName"))
        try {
            startActivity(direct)
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(Notifications.allowed(this))
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    /** Sends the live speed to Flutter once a second while the Today screen listens. */
    private inner class SpeedStream : EventChannel.StreamHandler {
        private val sampler = SpeedSampler()
        private var sink: EventChannel.EventSink? = null
        private val tick = object : Runnable {
            override fun run() {
                val speed = sampler.sample(
                    TrafficStats.getTotalRxBytes(),
                    TrafficStats.getTotalTxBytes(),
                    SystemClock.elapsedRealtime(),
                )
                sink?.success(mapOf("rx" to speed.rxPerSecond, "tx" to speed.txPerSecond))
                main.postDelayed(this, 1000)
            }
        }

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            sink = events
            sampler.reset()
            main.post(tick)
        }

        override fun onCancel(arguments: Any?) {
            main.removeCallbacks(tick)
            sink = null
        }
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 7
    }
}
