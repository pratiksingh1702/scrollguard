package com.yourorg.scrollguard.core.penalty

import com.yourorg.scrollguard.core.model.GuardConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class PenaltyEngineTest {

    private lateinit var engine: PenaltyEngine
    private val config = GuardConfig(
        nudgeThresholdFraction = 0.5f,
        frictionThresholdFraction = 0.8f,
        lockThresholdFraction = 1.0f,
        continuousNudgeMinutes = 10,
        continuousFrictionMinutes = 20,
        cooldownMinutes = 15,
        maxEmergencyUnlocksPerDay = 2,
        resetHour = 4
    )

    @Before
    fun setUp() {
        engine = PenaltyEngine(config)
    }

    @Test
    fun testInitialStateBelowThresholdsRemainsNone() {
        val state = PenaltyState(logicalDate = "2026-03-15")
        val result = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 0.3f,
            continuousMinutes = 5.0f,
            nowWallMs = 1773560000000L
        )

        assertEquals(PenaltyLevel.NONE, result.nextState.activeLevel)
        assertTrue(result.actions.isEmpty())
    }

    @Test
    fun testNudgeTriggeredAtHalfBudgetOrTenMinutes() {
        val state = PenaltyState(logicalDate = "2026-03-15")

        // Triggered by budget fraction 0.52
        val res1 = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 0.52f,
            continuousMinutes = 4.0f,
            nowWallMs = 1773560000000L
        )
        assertEquals(PenaltyLevel.L0_NUDGE, res1.nextState.activeLevel)
        assertTrue(res1.actions.any { it is PenaltyAction.ShowNudge })

        // Triggered by continuous minutes 11.0
        val res2 = engine.evaluate(
            currentState = state,
            appId = "com.zhiliaoapp.musically",
            budgetFraction = 0.2f,
            continuousMinutes = 11.0f,
            nowWallMs = 1773560000000L
        )
        assertEquals(PenaltyLevel.L0_NUDGE, res2.nextState.activeLevel)
        assertTrue(res2.actions.any { it is PenaltyAction.ShowNudge })
    }

    @Test
    fun testFrictionTriggeredAtEightyPercentOrTwentyMinutes() {
        val state = PenaltyState(logicalDate = "2026-03-15")

        // Triggered by budget fraction 0.82
        val res1 = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 0.82f,
            continuousMinutes = 5.0f,
            nowWallMs = 1773560000000L
        )
        assertEquals(PenaltyLevel.L1_FRICTION, res1.nextState.activeLevel)
        assertTrue(res1.actions.any { it is PenaltyAction.ShowFriction })

        // Triggered by continuous 22 minutes
        val res2 = engine.evaluate(
            currentState = state,
            appId = "com.zhiliaoapp.musically",
            budgetFraction = 0.4f,
            continuousMinutes = 22.0f,
            nowWallMs = 1773560000000L
        )
        assertEquals(PenaltyLevel.L1_FRICTION, res2.nextState.activeLevel)
        assertTrue(res2.actions.any { it is PenaltyAction.ShowFriction })
    }

    @Test
    fun testLockTriggeredAtHundredPercentBudget() {
        val state = PenaltyState(logicalDate = "2026-03-15")
        val now = 1773560000000L

        val result = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 1.05f,
            continuousMinutes = 5.0f,
            nowWallMs = now
        )

        assertEquals(PenaltyLevel.L2_LOCK, result.nextState.activeLevel)
        assertEquals(now + 15 * 60 * 1000L, result.nextState.lockedUntilMs)
        assertTrue(result.actions.any { it is PenaltyAction.ShowLock })
        assertTrue(result.actions.any { it is PenaltyAction.TriggerBackAction })
    }

    @Test
    fun testSevereStrikeAtOneHundredFiftyPercent() {
        val state = PenaltyState(logicalDate = "2026-03-15", strikesToday = 0)
        val now = 1773560000000L

        val result = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 1.55f,
            continuousMinutes = 5.0f,
            nowWallMs = now
        )

        assertEquals(PenaltyLevel.L3_STRIKE, result.nextState.activeLevel)
        assertEquals(1, result.nextState.strikesToday)
        assertTrue(result.actions.any { it is PenaltyAction.RecordPenalty && it.level == PenaltyLevel.L3_STRIKE.value })
    }

    @Test
    fun testCooldownMaintainsLockUntilExpiry() {
        val now = 1773560000000L
        val lockedUntil = now + 60_000L
        val state = PenaltyState(
            activeLevel = PenaltyLevel.L2_LOCK,
            lockedUntilMs = lockedUntil,
            logicalDate = "2026-03-15"
        )

        // 30 seconds into cooldown
        val resMid = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 0.5f,
            continuousMinutes = 0f,
            nowWallMs = now + 30_000L
        )
        assertEquals(PenaltyLevel.L2_LOCK, resMid.nextState.activeLevel)
        assertTrue(resMid.actions.any { it is PenaltyAction.ShowLock })

        // Expired cooldown and budget normalized
        val resExpired = engine.evaluate(
            currentState = state,
            appId = "com.instagram.android",
            budgetFraction = 0.4f,
            continuousMinutes = 0f,
            nowWallMs = lockedUntil + 1000L
        )
        assertEquals(PenaltyLevel.NONE, resExpired.nextState.activeLevel)
        assertTrue(resExpired.actions.any { it is PenaltyAction.DismissOverlay })
    }

    @Test
    fun testEmergencyUnlockRequirementsAndLimits() {
        val state = PenaltyState(
            activeLevel = PenaltyLevel.L2_LOCK,
            lockedUntilMs = 1773560060000L,
            emergencyUnlocksUsedToday = 0,
            strikesToday = 0
        )

        // Reason too short (< 10 chars)
        val (s1, ok1) = engine.requestEmergencyUnlock(state, "urgent", 1773560000000L)
        assertFalse(ok1)
        assertEquals(0, s1.emergencyUnlocksUsedToday)

        // Valid reason (>= 10 chars)
        val (s2, ok2) = engine.requestEmergencyUnlock(state, "Need to message family urgent", 1773560000000L)
        assertTrue(ok2)
        assertEquals(1, s2.emergencyUnlocksUsedToday)
        assertEquals(1, s2.strikesToday)
        assertEquals(0L, s2.lockedUntilMs)
        assertEquals(PenaltyLevel.NONE, s2.activeLevel)

        // Second unlock
        val (s3, ok3) = engine.requestEmergencyUnlock(s2, "Another critical situation occurred", 1773560010000L)
        assertTrue(ok3)
        assertEquals(2, s3.emergencyUnlocksUsedToday)

        // Third unlock should fail because max is 2
        val (s4, ok4) = engine.requestEmergencyUnlock(s3, "Third attempt beyond daily limit", 1773560020000L)
        assertFalse(ok4)
        assertEquals(2, s4.emergencyUnlocksUsedToday)
    }

    @Test
    fun testPauseSuppressesPenaltiesAndAutoDismisses() {
        val now = 1773560000000L
        val activeState = PenaltyState(
            activeLevel = PenaltyLevel.L1_FRICTION,
            logicalDate = "2026-03-15"
        )

        // Request 10-minute pause
        val pausedState = engine.requestPause(activeState, durationMs = 10 * 60 * 1000L, nowWallMs = now)
        assertEquals(now + 10 * 60 * 1000L, pausedState.pausedUntilMs)
        assertEquals(PenaltyLevel.NONE, pausedState.activeLevel)

        // Evaluate during pause window even with budget 1.2
        val result = engine.evaluate(
            currentState = pausedState,
            appId = "com.instagram.android",
            budgetFraction = 1.2f,
            continuousMinutes = 25f,
            nowWallMs = now + 5 * 60 * 1000L
        )
        assertEquals(PenaltyLevel.NONE, result.nextState.activeLevel)
    }
}
