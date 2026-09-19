package com.yourorg.scrollguard.core.enforcement

import com.yourorg.scrollguard.core.model.GuardConfig
import com.yourorg.scrollguard.core.penalty.PenaltyAction
import com.yourorg.scrollguard.core.penalty.PenaltyEngine
import com.yourorg.scrollguard.core.penalty.PenaltyLevel
import com.yourorg.scrollguard.core.penalty.PenaltyState
import com.yourorg.scrollguard.core.score.ScoreEngine
import com.yourorg.scrollguard.core.session.SessionTracker
import com.yourorg.scrollguard.core.util.TestNativeClock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class EnforcementFlowTest {

    private lateinit var clock: TestNativeClock
    private lateinit var config: GuardConfig
    private lateinit var scoreEngine: ScoreEngine
    private lateinit var penaltyEngine: PenaltyEngine

    @Before
    fun setUp() {
        clock = TestNativeClock(wallTime = 1773560000000L, elapsed = 10_000L)
        // 1-minute test budget (60s)
        config = GuardConfig(
            dailyBudgetSeconds = 60L,
            nudgeThresholdFraction = 0.5f,
            frictionThresholdFraction = 0.8f,
            lockThresholdFraction = 1.0f,
            continuousNudgeMinutes = 10,
            continuousFrictionMinutes = 20,
            cooldownMinutes = 15,
            maxEmergencyUnlocksPerDay = 2,
            resetHour = 4
        )
        scoreEngine = ScoreEngine(clock, config)
        penaltyEngine = PenaltyEngine(config)
    }

    @Test
    fun testOneMinuteBudgetEnforcementLadder() {
        var penaltyState = PenaltyState(
            logicalDate = ScoreEngine.computeLogicalDate(clock.wallTimeMs(), config.resetHour)
        )

        // 1. Initial 10 seconds of feed time (10s / 60s = 16.6%) -> NONE
        scoreEngine.setTodayFeedSeconds(10L)
        var eval = penaltyEngine.evaluate(
            currentState = penaltyState,
            appId = "youtube_shorts",
            budgetFraction = scoreEngine.getBudgetUsedFraction(),
            continuousMinutes = 10f / 60f,
            nowWallMs = clock.wallTimeMs()
        )
        penaltyState = eval.nextState
        assertEquals(PenaltyLevel.NONE, penaltyState.activeLevel)

        // 2. Reaching 30 seconds (30s / 60s = 50%) -> Nudge at 30s
        scoreEngine.setTodayFeedSeconds(30L)
        eval = penaltyEngine.evaluate(
            currentState = penaltyState,
            appId = "youtube_shorts",
            budgetFraction = scoreEngine.getBudgetUsedFraction(),
            continuousMinutes = 30f / 60f,
            nowWallMs = clock.wallTimeMs()
        )
        penaltyState = eval.nextState
        assertEquals(PenaltyLevel.L0_NUDGE, penaltyState.activeLevel)
        assertTrue(eval.actions.any { it is PenaltyAction.ShowNudge })

        // 3. Reaching 48 seconds (48s / 60s = 80%) -> Friction at 48s
        scoreEngine.setTodayFeedSeconds(48L)
        eval = penaltyEngine.evaluate(
            currentState = penaltyState,
            appId = "youtube_shorts",
            budgetFraction = scoreEngine.getBudgetUsedFraction(),
            continuousMinutes = 48f / 60f,
            nowWallMs = clock.wallTimeMs()
        )
        penaltyState = eval.nextState
        assertEquals(PenaltyLevel.L1_FRICTION, penaltyState.activeLevel)
        assertTrue(eval.actions.any { it is PenaltyAction.ShowFriction })

        // 4. Reaching 60 seconds (60s / 60s = 100%) -> Lock at 60s
        scoreEngine.setTodayFeedSeconds(60L)
        val lockWallTime = clock.wallTimeMs()
        eval = penaltyEngine.evaluate(
            currentState = penaltyState,
            appId = "youtube_shorts",
            budgetFraction = scoreEngine.getBudgetUsedFraction(),
            continuousMinutes = 1.0f,
            nowWallMs = lockWallTime
        )
        penaltyState = eval.nextState
        assertEquals(PenaltyLevel.L2_LOCK, penaltyState.activeLevel)
        assertEquals(lockWallTime + 15 * 60 * 1000L, penaltyState.lockedUntilMs)
        assertTrue(eval.actions.any { it is PenaltyAction.ShowLock })
        assertTrue(eval.actions.any { it is PenaltyAction.TriggerBackAction })

        // 5. Re-opening Shorts during cool-down is blocked
        clock.advance(2 * 60 * 1000L) // 2 minutes later
        eval = penaltyEngine.evaluate(
            currentState = penaltyState,
            appId = "youtube_shorts",
            budgetFraction = scoreEngine.getBudgetUsedFraction(),
            continuousMinutes = 0.1f,
            nowWallMs = clock.wallTimeMs()
        )
        penaltyState = eval.nextState
        assertEquals(PenaltyLevel.L2_LOCK, penaltyState.activeLevel)
        assertTrue("Must trigger back action during cooldown", eval.actions.any { it is PenaltyAction.TriggerBackAction })
    }

    @Test
    fun testEmergencyUnlockFlowAndResetHour() {
        val lockTime = clock.wallTimeMs()
        var state = PenaltyState(
            activeLevel = PenaltyLevel.L2_LOCK,
            lockedUntilMs = lockTime + 15 * 60 * 1000L,
            emergencyUnlocksUsedToday = 0,
            logicalDate = "2026-03-15"
        )

        // Attempt invalid unlock (< 10 chars)
        val (s1, ok1) = penaltyEngine.requestEmergencyUnlock(state, "urgent", lockTime)
        assertFalse(ok1)
        assertEquals(PenaltyLevel.L2_LOCK, s1.activeLevel)

        // Valid unlock
        val (s2, ok2) = penaltyEngine.requestEmergencyUnlock(state, "Need urgent medical info lookup", lockTime)
        assertTrue(ok2)
        assertEquals(PenaltyLevel.NONE, s2.activeLevel)
        assertEquals(0L, s2.lockedUntilMs)
        assertEquals(1, s2.emergencyUnlocksUsedToday)
        assertEquals(1, s2.strikesToday)

        // Second valid unlock
        val (s3, ok3) = penaltyEngine.requestEmergencyUnlock(s2, "Another emergency contact needed", lockTime + 1000L)
        assertTrue(ok3)
        assertEquals(2, s3.emergencyUnlocksUsedToday)

        // Exceeded max unlocks
        val (s4, ok4) = penaltyEngine.requestEmergencyUnlock(s3, "Third unlock attempt should fail", lockTime + 2000L)
        assertFalse(ok4)
        assertEquals(2, s4.emergencyUnlocksUsedToday)

        // Day rollover test: next logical day at 05:00 AM
        val nextDayTime = lockTime + 24 * 60 * 60 * 1000L
        val nextDayDate = ScoreEngine.computeLogicalDate(nextDayTime, config.resetHour)
        val evalDayChange = penaltyEngine.evaluate(
            currentState = s4,
            appId = "youtube_shorts",
            budgetFraction = 0.1f,
            continuousMinutes = 1f,
            nowWallMs = nextDayTime
        )
        // Reset counters on new day
        assertEquals(0, evalDayChange.nextState.emergencyUnlocksUsedToday)
        assertEquals(0, evalDayChange.nextState.strikesToday)
        assertEquals(nextDayDate, evalDayChange.nextState.logicalDate)
    }

    @Test
    fun testPauseSuppression() {
        val now = clock.wallTimeMs()
        val activeState = PenaltyState(
            activeLevel = PenaltyLevel.L1_FRICTION,
            logicalDate = "2026-03-15"
        )

        val pausedState = penaltyEngine.requestPause(activeState, durationMs = 10 * 60 * 1000L, nowWallMs = now)
        assertEquals(now + 10 * 60 * 1000L, pausedState.pausedUntilMs)
        assertEquals(PenaltyLevel.NONE, pausedState.activeLevel)

        val eval = penaltyEngine.evaluate(
            currentState = pausedState,
            appId = "youtube_shorts",
            budgetFraction = 1.1f,
            continuousMinutes = 15f,
            nowWallMs = now + 5 * 60 * 1000L
        )
        assertEquals(PenaltyLevel.NONE, eval.nextState.activeLevel)
    }
}
