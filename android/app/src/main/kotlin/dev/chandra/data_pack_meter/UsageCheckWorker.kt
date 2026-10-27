package dev.chandra.data_pack_meter

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/** Checks the pack every 15 minutes (Android's minimum) for alerts. */
class UsageCheckWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        PackCheck.run(applicationContext)
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
