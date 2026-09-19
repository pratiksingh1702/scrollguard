package com.yourorg.scrollguard.worker

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object WorkScheduler {

    private const val WATCHDOG_WORK_NAME = "scrollguard_watchdog_work"
    private const val HEARTBEAT_WORK_NAME = "scrollguard_heartbeat_work"

    fun schedulePeriodicWork(context: Context) {
        val workManager = WorkManager.getInstance(context)

        // Periodic watchdog (15 minutes)
        val watchdogRequest = PeriodicWorkRequestBuilder<WatchdogWorker>(
            15, TimeUnit.MINUTES
        ).build()

        workManager.enqueueUniquePeriodicWork(
            WATCHDOG_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            watchdogRequest
        )

        // Periodic heartbeat (15 minutes)
        val heartbeatRequest = PeriodicWorkRequestBuilder<HeartbeatWorker>(
            15, TimeUnit.MINUTES
        ).build()

        workManager.enqueueUniquePeriodicWork(
            HEARTBEAT_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            heartbeatRequest
        )
    }
}
