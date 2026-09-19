package com.yourorg.scrollguard.core.session

import com.yourorg.scrollguard.core.detect.SwipeCounter
import com.yourorg.scrollguard.core.model.SessionRecord
import com.yourorg.scrollguard.core.util.NativeClock
import java.util.UUID

enum class SessionState {
    IDLE,
    ACTIVE,
    PAUSED,
    ENDED
}

class SessionTracker(
    private val clock: NativeClock,
    private val feedTimeoutMs: Long = 8_000L,
    private val mergeWindowMs: Long = 20_000L,
    private val onSessionSaved: (SessionRecord) -> Unit
) {
    var state: SessionState = SessionState.IDLE
        private set

    private var currentSessionId: String? = null
    private var currentAppId: String? = null
    private var sessionStartWallTs: Long = 0L
    private var sessionStartElapsedTs: Long = 0L
    private var lastActiveElapsedTs: Long = 0L
    private var pauseStartElapsedTs: Long = 0L
    private var totalFeedDurationMs: Long = 0L

    private val swipeCounter = SwipeCounter()
    private var maxIntensityScore: Int = 0
    private var maxPenaltyLevel: Int = 0

    fun onFeedSignal(appId: String, swiped: Boolean = false) {
        val nowElapsed = clock.elapsedRealtimeMs()
        val nowWall = clock.wallTimeMs()

        when (state) {
            SessionState.IDLE, SessionState.ENDED -> {
                // Start a brand new session
                startNewSession(appId, nowElapsed, nowWall)
            }
            SessionState.PAUSED -> {
                // If returning within merge window to the same app, resume session
                val pauseDuration = nowElapsed - pauseStartElapsedTs
                if (currentAppId == appId && pauseDuration <= mergeWindowMs) {
                    state = SessionState.ACTIVE
                    lastActiveElapsedTs = nowElapsed
                } else {
                    // Beyond merge window or different app -> finalize old session and start new
                    finalizeSession()
                    startNewSession(appId, nowElapsed, nowWall)
                }
            }
            SessionState.ACTIVE -> {
                if (currentAppId != appId) {
                    finalizeSession()
                    startNewSession(appId, nowElapsed, nowWall)
                } else {
                    totalFeedDurationMs += (nowElapsed - lastActiveElapsedTs)
                    lastActiveElapsedTs = nowElapsed
                }
            }
        }

        if (swiped) {
            swipeCounter.recordSwipe(nowElapsed)
        }
    }

    fun onFeedAbsent() {
        val nowElapsed = clock.elapsedRealtimeMs()
        if (state == SessionState.ACTIVE) {
            totalFeedDurationMs += (nowElapsed - lastActiveElapsedTs)
            lastActiveElapsedTs = nowElapsed
            pauseStartElapsedTs = nowElapsed
            state = SessionState.PAUSED
        }
    }

    fun onScreenOff() {
        val nowElapsed = clock.elapsedRealtimeMs()
        if (state == SessionState.ACTIVE) {
            totalFeedDurationMs += (nowElapsed - lastActiveElapsedTs)
            lastActiveElapsedTs = nowElapsed
        }
        if (state == SessionState.ACTIVE || state == SessionState.PAUSED) {
            finalizeSession()
        }
    }

    fun checkTimeouts() {
        val nowElapsed = clock.elapsedRealtimeMs()
        if (state == SessionState.PAUSED) {
            val pauseDuration = nowElapsed - pauseStartElapsedTs
            if (pauseDuration > mergeWindowMs) {
                finalizeSession()
            }
        } else if (state == SessionState.ACTIVE) {
            val idleDuration = nowElapsed - lastActiveElapsedTs
            if (idleDuration > feedTimeoutMs) {
                totalFeedDurationMs += feedTimeoutMs
                pauseStartElapsedTs = lastActiveElapsedTs + feedTimeoutMs
                state = SessionState.PAUSED
                if (nowElapsed - pauseStartElapsedTs > mergeWindowMs) {
                    finalizeSession()
                }
            }
        }
    }

    fun updateScoreAndPenalty(score: Int, penaltyLevel: Int) {
        if (score > maxIntensityScore) {
            maxIntensityScore = score
        }
        if (penaltyLevel > maxPenaltyLevel) {
            maxPenaltyLevel = penaltyLevel
        }
    }

    private fun startNewSession(appId: String, nowElapsed: Long, nowWall: Long) {
        currentSessionId = UUID.randomUUID().toString()
        currentAppId = appId
        sessionStartWallTs = nowWall
        sessionStartElapsedTs = nowElapsed
        lastActiveElapsedTs = nowElapsed
        pauseStartElapsedTs = 0L
        totalFeedDurationMs = 0L
        swipeCounter.reset()
        maxIntensityScore = 0
        maxPenaltyLevel = 0
        state = SessionState.ACTIVE
    }

    fun finalizeSession() {
        if (currentSessionId == null || currentAppId == null) {
            state = SessionState.IDLE
            return
        }

        val feedSeconds = totalFeedDurationMs / 1000L
        // Only save sessions that had at least 2 seconds or 1 swipe
        if (feedSeconds >= 2L || swipeCounter.swipeCount > 0) {
            val durationMinutes = if (feedSeconds > 0) feedSeconds / 60.0f else 0.1f
            val peakSpm = (swipeCounter.swipeCount / durationMinutes.coerceAtLeast(0.1f))

            val session = SessionRecord(
                id = currentSessionId!!,
                appId = currentAppId!!,
                startTs = sessionStartWallTs,
                endTs = sessionStartWallTs + totalFeedDurationMs,
                feedSeconds = feedSeconds,
                swipeCount = swipeCounter.swipeCount,
                avgDwellMs = swipeCounter.avgDwellMs,
                minDwellMs = swipeCounter.minDwellMs,
                peakSpm = peakSpm,
                scoreMax = maxIntensityScore,
                levelReached = maxPenaltyLevel,
                synced = false
            )
            onSessionSaved(session)
        }

        currentSessionId = null
        currentAppId = null
        state = SessionState.IDLE
    }

    val currentSessionFeedSeconds: Long
        get() {
            if (state == SessionState.IDLE || state == SessionState.ENDED) return 0L
            val extra = if (state == SessionState.ACTIVE) {
                clock.elapsedRealtimeMs() - lastActiveElapsedTs
            } else 0L
            return (totalFeedDurationMs + extra) / 1000L
        }

    val currentSessionSwipes: Int
        get() = swipeCounter.swipeCount
}
