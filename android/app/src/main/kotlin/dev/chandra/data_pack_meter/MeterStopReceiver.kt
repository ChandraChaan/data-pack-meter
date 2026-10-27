package dev.chandra.data_pack_meter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** The meter notification's Turn off button. */
class MeterStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Prefs(context).meterEnabled = false
        SpeedMeterService.stop(context)
    }
}
