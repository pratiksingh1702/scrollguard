package com.yourorg.scrollguard.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.yourorg.scrollguard.data.AppRoomDatabase
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.worker.WorkScheduler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.d(TAG, "Device booted or package replaced: action=$action. Rescheduling workers.")

            // Reschedule background workers
            WorkScheduler.schedulePeriodicWork(context)

            // Log boot event
            val pendingResult = goAsync()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val db = AppRoomDatabase.getInstance(context)
                    db.guardEventDao().insertGuardEvent(
                        GuardEventEntity(
                            id = UUID.randomUUID().toString(),
                            ts = System.currentTimeMillis(),
                            type = "device_boot",
                            metaJson = "{\"action\":\"$action\"}",
                            synced = false
                        )
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to record boot event: ${e.message}")
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }
}
