package dev.chandra.data_pack_meter

import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.util.LruCache
import java.io.ByteArrayOutputStream

/** Thrown when Usage Access is off and Android refuses to share statistics. */
class NoUsageAccessException(cause: Throwable? = null) : Exception("Usage access is off", cause)

/** Reads Android's network statistics. Every query needs Usage Access. */
class UsageStats(private val context: Context) {
    private val stats = context.getSystemService(NetworkStatsManager::class.java)
    private val packages = context.packageManager

    fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            context.checkCallingOrSelfPermission(android.Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    /** Whole-device bytes received and sent on [networkType] between the two times. */
    fun deviceTraffic(networkType: Int, startMs: Long, endMs: Long): Pair<Long, Long> = guarded {
        // A null subscriber id means every SIM (Android 10+ hides the real id).
        val bucket = stats.querySummaryForDevice(networkType, null, startMs, endMs)
        bucket.rxBytes.coerceAtLeast(0) to bucket.txBytes.coerceAtLeast(0)
    }

    fun mobileBytes(startMs: Long, endMs: Long): Long =
        deviceTraffic(ConnectivityManager.TYPE_MOBILE, startMs, endMs).let { it.first + it.second }

    /** Traffic per app on [networkType], busiest first. */
    fun appTraffic(networkType: Int, startMs: Long, endMs: Long): List<UidTraffic> = guarded {
        val result = stats.querySummary(networkType, null, startMs, endMs)
        try {
            UidUsage.aggregate(sequence {
                val bucket = NetworkStats.Bucket()
                while (result.hasNextBucket()) {
                    result.getNextBucket(bucket)
                    yield(UidSample(bucket.uid, bucket.rxBytes, bucket.txBytes))
                }
            })
        } finally {
            result.close()
        }
    }

    /** A channel-ready row for one uid: kind, name, package and icon. */
    fun describe(traffic: UidTraffic): Map<String, Any?> {
        val kind = UidUsage.kindOf(traffic.uid)
        val app = if (kind == UidKind.APP) appFor(traffic.uid) else null
        return mapOf(
            "uid" to traffic.uid,
            "kind" to kind.wireName,
            "label" to (app?.label ?: ""),
            "packageName" to app?.packageName,
            "rx" to traffic.rxBytes,
            "tx" to traffic.txBytes,
            "icon" to app?.icon,
        )
    }

    private class AppInfo(val packageName: String, val label: String, val icon: ByteArray?)

    /** Several packages can share a uid; prefer one the user can see in the launcher. */
    private fun appFor(uid: Int): AppInfo? {
        val names = packages.getPackagesForUid(uid) ?: return null
        val infos = names.mapNotNull { name ->
            try {
                packages.getApplicationInfo(name, 0)
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
        }
        val info = infos.firstOrNull { packages.getLaunchIntentForPackage(it.packageName) != null }
            ?: infos.firstOrNull()
            ?: return null
        return iconCache.get(info.packageName) ?: AppInfo(
            info.packageName,
            packages.getApplicationLabel(info).toString(),
            iconPng(info),
        ).also { iconCache.put(info.packageName, it) }
    }

    private fun iconPng(info: ApplicationInfo): ByteArray? = try {
        val drawable = packages.getApplicationIcon(info)
        val size = ICON_PX
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            out.toByteArray()
        }
    } catch (_: RuntimeException) {
        // Some icons fail to draw off-screen; the app shows a placeholder instead.
        null
    }

    private inline fun <T> guarded(block: () -> T): T = try {
        block()
    } catch (e: SecurityException) {
        throw NoUsageAccessException(e)
    }

    private companion object {
        const val ICON_PX = 96
        val iconCache = LruCache<String, AppInfo>(200)
    }
}
