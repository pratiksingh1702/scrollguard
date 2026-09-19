package com.yourorg.scrollguard.core.stats

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build

object UsageStatsReader {

    /**
     * Checks if the PACKAGE_USAGE_STATS permission is granted by the user.
     */
    fun hasUsageStatsPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Queries per-app daily foreground time in seconds for the given packages.
     */
    fun queryDailyForegroundSeconds(
        context: Context,
        packageNames: Set<String>,
        startTimeMs: Long,
        endTimeMs: Long
    ): Map<String, Long> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyMap()

        val statsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTimeMs,
            endTimeMs
        ) ?: return emptyMap()

        val resultMap = HashMap<String, Long>()
        for (stat in statsList) {
            if (packageNames.contains(stat.packageName)) {
                val existing = resultMap[stat.packageName] ?: 0L
                resultMap[stat.packageName] = existing + (stat.totalTimeInForeground / 1000L)
            }
        }
        return resultMap
    }
}
