package dev.chandra.data_pack_meter

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/** Every 15 minutes (Android's minimum): pack alerts and the home-screen widget. */
class UsageCheckWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val use = PackCheck.run(applicationContext)
        PackWidget.refresh(applicationContext, use)
        return Result.success()
    }

    companion object {
        private const val NAME = "pack-check"

        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<UsageCheckWorker>(15, TimeUnit.MINUTES).build(),
            )
        }
    }
}
