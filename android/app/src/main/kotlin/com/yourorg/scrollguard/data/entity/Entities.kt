package com.yourorg.scrollguard.data.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "sessions",
    indices = [
        Index(value = ["startTs"]),
        Index(value = ["synced"])
    ]
)
data class SessionEntity(
    @PrimaryKey val id: String,
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

@Entity(
    tableName = "daily_stats",
    indices = [
        Index(value = ["synced"])
    ]
)
data class DailyStatsEntity(
    @PrimaryKey val dateIso: String,
    val feedSeconds: Long,
    val swipeCount: Int,
    val lockCount: Int,
    val strikeCount: Int,
    val synced: Boolean = false
)

@Entity(
    tableName = "penalty_events",
    indices = [
        Index(value = ["ts"]),
        Index(value = ["synced"])
    ]
)
data class PenaltyEventEntity(
    @PrimaryKey val id: String,
    val ts: Long,
    val appId: String,
    val level: Int,
    val reason: String,
    val budgetFraction: Float,
    val metaJson: String,
    val synced: Boolean = false
)

@Entity(
    tableName = "guard_events",
    indices = [
        Index(value = ["ts"]),
        Index(value = ["synced"])
    ]
)
data class GuardEventEntity(
    @PrimaryKey val id: String,
    val ts: Long,
    val type: String,
    val metaJson: String,
    val synced: Boolean = false
)
