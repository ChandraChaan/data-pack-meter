package dev.chandra.data_pack_meter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Restarts the meter after a reboot (if the user asked) or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = Prefs(context)
        val restart = when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> prefs.meterEnabled && prefs.meterOnBoot
            Intent.ACTION_MY_PACKAGE_REPLACED -> prefs.meterEnabled
            else -> return
        }
        if (prefs.plan != null || PackWidget.hasWidgets(context)) UsageCheckWorker.schedule(context)
        if (!restart) return
        try {
            SpeedMeterService.start(context)
        } catch (e: IllegalStateException) {
            // Android refused a background start; the meter returns when the app opens.
            Log.w("BootReceiver", "Could not start the meter", e)
        }
    }
}
