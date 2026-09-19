package com.yourorg.scrollguard.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.yourorg.scrollguard.data.entity.DailyStatsEntity
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.data.entity.PenaltyEventEntity
import com.yourorg.scrollguard.data.entity.SessionEntity

@Dao
interface SessionDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: SessionEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSessions(sessions: List<SessionEntity>)

    @Query("SELECT * FROM sessions WHERE startTs BETWEEN :fromEpochMs AND :toEpochMs ORDER BY startTs DESC")
    suspend fun getSessions(fromEpochMs: Long, toEpochMs: Long): List<SessionEntity>

    @Query("SELECT * FROM sessions WHERE synced = 0")
    suspend fun getUnsyncedSessions(): List<SessionEntity>

    @Query("UPDATE sessions SET synced = 1 WHERE id IN (:ids)")
    suspend fun markSynced(ids: List<String>)
}

@Dao
interface DailyStatsDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDailyStats(stats: DailyStatsEntity)

    @Query("SELECT * FROM daily_stats WHERE dateIso = :dateIso LIMIT 1")
    suspend fun getDailyStats(dateIso: String): DailyStatsEntity?

    @Query("SELECT * FROM daily_stats WHERE synced = 0")
    suspend fun getUnsyncedStats(): List<DailyStatsEntity>

    @Query("UPDATE daily_stats SET synced = 1 WHERE dateIso IN (:dates)")
    suspend fun markSynced(dates: List<String>)
}

@Dao
interface PenaltyEventDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPenaltyEvent(event: PenaltyEventEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPenaltyEvents(events: List<PenaltyEventEntity>)

    @Query("SELECT * FROM penalty_events WHERE ts BETWEEN :fromEpochMs AND :toEpochMs ORDER BY ts DESC")
    suspend fun getPenaltyEvents(fromEpochMs: Long, toEpochMs: Long): List<PenaltyEventEntity>

    @Query("SELECT * FROM penalty_events WHERE synced = 0")
    suspend fun getUnsyncedEvents(): List<PenaltyEventEntity>

    @Query("UPDATE penalty_events SET synced = 1 WHERE id IN (:ids)")
    suspend fun markSynced(ids: List<String>)
}

@Dao
interface GuardEventDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGuardEvent(event: GuardEventEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGuardEvents(events: List<GuardEventEntity>)

    @Query("SELECT * FROM guard_events WHERE ts BETWEEN :fromEpochMs AND :toEpochMs ORDER BY ts DESC")
    suspend fun getGuardEvents(fromEpochMs: Long, toEpochMs: Long): List<GuardEventEntity>

    @Query("SELECT * FROM guard_events WHERE synced = 0")
    suspend fun getUnsyncedEvents(): List<GuardEventEntity>

    @Query("UPDATE guard_events SET synced = 1 WHERE id IN (:ids)")
    suspend fun markSynced(ids: List<String>)
}
