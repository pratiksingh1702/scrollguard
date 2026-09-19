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
import com.yourorg.scrollguard.core.stats.UsageStatsReader
import com.yourorg.scrollguard.data.AppRoomDatabase
import com.yourorg.scrollguard.data.ConfigStore
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
        val nowElapsed = android.os.SystemClock.elapsedRealtime()

        // 1. Clock-tampering detection (P8-T1)
        val prefs = context.getSharedPreferences("scrollguard_tamper", Context.MODE_PRIVATE)
        val lastWall = prefs.getLong("last_wall_time", 0L)
        val lastElapsed = prefs.getLong("last_elapsed_time", 0L)

        if (lastWall > 0L && lastElapsed > 0L && nowElapsed >= lastElapsed) {
            val elapsedDelta = nowElapsed - lastElapsed
            val wallDelta = now - lastWall
            if (wallDelta < -5000L || kotlin.math.abs(wallDelta - elapsedDelta) > 60000L) {
                Log.w(TAG, "Clock tampering detected: wallDelta=$wallDelta ms, elapsedDelta=$elapsedDelta ms")
                db.guardEventDao().insertGuardEvent(
                    GuardEventEntity(
                        id = UUID.randomUUID().toString(),
                        ts = now,
                        type = "clock_tampering",
                        metaJson = "{\"wallDelta\":$wallDelta,\"elapsedDelta\":$elapsedDelta}"
                    )
                )
            }
        }
        prefs.edit().putLong("last_wall_time", now).putLong("last_elapsed_time", nowElapsed).apply()

        // 2. Service-disabled or killed detection (P8-T1)
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

        // 3. Service-disabled-while-used detection (UsageStats vs Guard events)
        if (!enabled || !ScrollGuardAccessibilityService.isServiceRunning) {
            if (UsageStatsReader.hasUsageStatsPermission(context)) {
                val fifteenMinAgo = now - 15 * 60 * 1000L
                val config = ConfigStore(context).loadConfig()
                val foregroundUsage = UsageStatsReader.queryDailyForegroundSeconds(
                    context,
                    config.guardedApps.toSet(),
                    fifteenMinAgo,
                    now
                )
                for ((pkg, fgSecs) in foregroundUsage) {
                    if (fgSecs > 30L) {
                        Log.w(TAG, "Guarded app $pkg was used for ${fgSecs}s while guard was inactive!")
                        db.guardEventDao().insertGuardEvent(
                            GuardEventEntity(
                                id = UUID.randomUUID().toString(),
                                ts = now,
                                type = "service_disabled_while_used",
                                metaJson = "{\"appId\":\"$pkg\",\"foregroundSeconds\":$fgSecs}"
                            )
                        )
                    }
                }
            }
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
