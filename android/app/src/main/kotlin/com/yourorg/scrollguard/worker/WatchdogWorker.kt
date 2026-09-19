package com.yourorg.scrollguard.worker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.yourorg.scrollguard.R
import com.yourorg.scrollguard.data.AppRoomDatabase
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.service.ScrollGuardAccessibilityService
import java.util.UUID

class WatchdogWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "WatchdogWorker"
        const val CHANNEL_ID = "scrollguard_watchdog"
        const val NOTIFICATION_ID = 1001

        fun isAccessibilityEnabled(context: Context, serviceClass: Class<*>): Boolean {
            val expectedComponent = ComponentName(context, serviceClass)
            val setting = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(setting)
            while (colonSplitter.hasNext()) {
                val compStr = colonSplitter.next()
                val comp = ComponentName.unflattenFromString(compStr)
                if (comp != null && comp == expectedComponent) {
                    return true
                }
            }
            return false
        }
    }

    override suspend fun doWork(): Result {
        val enabled = isAccessibilityEnabled(context, ScrollGuardAccessibilityService::class.java)
        val db = AppRoomDatabase.getInstance(context)
        val now = System.currentTimeMillis()

        if (!enabled) {
            Log.w(TAG, "Watchdog detected AccessibilityService is DISABLED")
            // Record guard_off event
            db.guardEventDao().insertGuardEvent(
                GuardEventEntity(
                    id = UUID.randomUUID().toString(),
                    ts = now,
                    type = "guard_off",
                    metaJson = "{\"reason\":\"accessibility_disabled\"}"
                )
            )

            // Fire warning notification
            showGuardOffNotification()
        } else if (!ScrollGuardAccessibilityService.isServiceRunning) {
            Log.w(TAG, "Accessibility enabled in settings but service not currently running (likely OEM kill)")
            db.guardEventDao().insertGuardEvent(
                GuardEventEntity(
                    id = UUID.randomUUID().toString(),
                    ts = now,
                    type = "guard_killed",
                    metaJson = "{\"reason\":\"oem_service_killed\"}"
                )
            )
        }

        return Result.success()
    }

    private fun showGuardOffNotification() {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ScrollGuard Watchdog Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when protection is unexpectedly disabled"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val settingsIntent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            settingsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("ScrollGuard is inactive")
            .setContentText("Accessibility permission was turned off. Tap to re-enable your guard.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
