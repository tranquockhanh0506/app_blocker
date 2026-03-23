package com.khanhtq.app_blocker.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.khanhtq.app_blocker.blocking.BlockingServiceManager
import com.khanhtq.app_blocker.persistence.BlockerPreferences
import com.khanhtq.app_blocker.scheduling.ScheduleManager
import java.util.concurrent.TimeUnit

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val preferences = BlockerPreferences(context)

        if (preferences.isBlocking()) {
            val workRequest = OneTimeWorkRequestBuilder<RestoreBlockingWorker>()
                .setInitialDelay(1, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueue(workRequest)
        }

        val scheduleManager = ScheduleManager(context)
        scheduleManager.rescheduleAll()
    }

    class RestoreBlockingWorker(
        context: Context,
        workerParams: WorkerParameters
    ) : Worker(context, workerParams) {

        override fun doWork(): Result {
            val blockingServiceManager = BlockingServiceManager(applicationContext)
            blockingServiceManager.restoreBlocking()
            return Result.success()
        }
    }
}
