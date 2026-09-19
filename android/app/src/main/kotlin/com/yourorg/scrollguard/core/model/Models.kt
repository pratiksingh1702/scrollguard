package com.yourorg.scrollguard.core.model

data class SessionRecord(
    val id: String,
    val appId: String,
    val startTs: Long,
    val endTs: Long,
    val feedSeconds: Long,
    val swipeCount: Int,
    val avgDwellMs: Long,
    val minDwellMs: Long,
    val peakSpm: Float,
    val scoreMax: Int,
    val levelReached: Int,
    val synced: Boolean = false
)

data class DailyStatsRecord(
    val dateIso: String,
    val feedSeconds: Long,
    val swipeCount: Int,
    val lockCount: Int,
    val strikeCount: Int,
    val synced: Boolean = false
)

data class PenaltyEventRecord(
    val id: String,
    val ts: Long,
    val appId: String,
    val level: Int,
    val reason: String,
    val budgetFraction: Float,
    val metaJson: String,
    val synced: Boolean = false
)

data class GuardEventRecord(
    val id: String,
    val ts: Long,
    val type: String, // guard_on, guard_off, rules_stale, boot, paused, emergency_unlock
    val metaJson: String,
    val synced: Boolean = false
)

data class GuardConfig(
    val dailyBudgetSeconds: Long = 1800L, // 30 min default
    val nudgeThresholdFraction: Float = 0.5f,
    val frictionThresholdFraction: Float = 0.8f,
    val lockThresholdFraction: Float = 1.0f,
    val continuousNudgeMinutes: Long = 10L,
    val continuousFrictionMinutes: Long = 20L,
    val cooldownMinutes: Long = 30L,
    val resetHour: Int = 4, // 04:00 default
    val maxEmergencyUnlocksPerDay: Int = 1,
    val guardedApps: List<String> = listOf(
        "com.google.android.youtube",
        "com.instagram.android",
        "com.zhiliaoapp.musically"
    )
)
