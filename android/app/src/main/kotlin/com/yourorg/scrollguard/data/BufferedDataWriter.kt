package com.yourorg.scrollguard.data

import com.yourorg.scrollguard.data.entity.DailyStatsEntity
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.data.entity.PenaltyEventEntity
import com.yourorg.scrollguard.data.entity.SessionEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentLinkedQueue

class BufferedDataWriter(
    private val database: AppRoomDatabase,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
    private val flushIntervalMs: Long = 5_000L
) {
    private val sessionQueue = ConcurrentLinkedQueue<SessionEntity>()
    private val penaltyQueue = ConcurrentLinkedQueue<PenaltyEventEntity>()
    private val guardEventQueue = ConcurrentLinkedQueue<GuardEventEntity>()
    private var pendingDailyStats: DailyStatsEntity? = null

    private val mutex = Mutex()
    private var periodicJob: Job? = null

    init {
        startPeriodicFlush()
    }

    fun queueSession(session: SessionEntity) {
        sessionQueue.add(session)
    }

    fun queuePenalty(penalty: PenaltyEventEntity) {
        penaltyQueue.add(penalty)
    }

    fun queueGuardEvent(event: GuardEventEntity) {
        guardEventQueue.add(event)
    }

    fun updateDailyStats(stats: DailyStatsEntity) {
        pendingDailyStats = stats
    }

    private fun startPeriodicFlush() {
        periodicJob = scope.launch {
            while (isActive) {
                delay(flushIntervalMs)
                flush()
            }
        }
    }

    suspend fun flush() {
        mutex.withLock {
            val sessionsToSave = ArrayList<SessionEntity>()
            while (sessionQueue.isNotEmpty()) {
                sessionQueue.poll()?.let { sessionsToSave.add(it) }
            }
            if (sessionsToSave.isNotEmpty()) {
                database.sessionDao().insertSessions(sessionsToSave)
            }

            val penaltiesToSave = ArrayList<PenaltyEventEntity>()
            while (penaltyQueue.isNotEmpty()) {
                penaltyQueue.poll()?.let { penaltiesToSave.add(it) }
            }
            if (penaltiesToSave.isNotEmpty()) {
                database.penaltyEventDao().insertPenaltyEvents(penaltiesToSave)
            }

            val guardEventsToSave = ArrayList<GuardEventEntity>()
            while (guardEventQueue.isNotEmpty()) {
                guardEventQueue.poll()?.let { guardEventsToSave.add(it) }
            }
            if (guardEventsToSave.isNotEmpty()) {
                database.guardEventDao().insertGuardEvents(guardEventsToSave)
            }

            val stats = pendingDailyStats
            if (stats != null) {
                database.dailyStatsDao().insertDailyStats(stats)
                pendingDailyStats = null
            }
        }
    }

    fun stop() {
        periodicJob?.cancel()
    }
}
