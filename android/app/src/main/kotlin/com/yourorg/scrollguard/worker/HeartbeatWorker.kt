package com.yourorg.scrollguard.worker

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.yourorg.scrollguard.data.AppRoomDatabase
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.service.ScrollGuardAccessibilityService
import java.util.UUID

class HeartbeatWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "HeartbeatWorker"
    }

    override suspend fun doWork(): Result {
        val now = System.currentTimeMillis()
        val isRunning = ScrollGuardAccessibilityService.isServiceRunning
        val db = AppRoomDatabase.getInstance(context)

        Log.d(TAG, "Heartbeat recorded: ts=$now, serviceRunning=$isRunning")

        db.guardEventDao().insertGuardEvent(
            GuardEventEntity(
                id = UUID.randomUUID().toString(),
                ts = now,
                type = "heartbeat",
                metaJson = "{\"serviceRunning\":$isRunning}",
                synced = false
            )
        )

        return Result.success()
    }
}
