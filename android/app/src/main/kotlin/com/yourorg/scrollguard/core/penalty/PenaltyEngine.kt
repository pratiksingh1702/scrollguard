package com.yourorg.scrollguard.core.penalty

import com.yourorg.scrollguard.core.model.GuardConfig
import com.yourorg.scrollguard.core.score.ScoreEngine

enum class PenaltyLevel(val value: Int) {
    NONE(0),
    L0_NUDGE(1),
    L1_FRICTION(2),
    L2_LOCK(3),
    L3_STRIKE(4)
}

data class PenaltyState(
    val activeLevel: PenaltyLevel = PenaltyLevel.NONE,
    val lockedUntilMs: Long = 0L,
    val emergencyUnlocksUsedToday: Int = 0,
    val strikesToday: Int = 0,
    val logicalDate: String = "",
    val pausedUntilMs: Long = 0L
)

sealed interface PenaltyAction {
    data class ShowNudge(val message: String) : PenaltyAction
    data class ShowFriction(val countdownSeconds: Int = 10) : PenaltyAction
    data class ShowLock(val remainingSeconds: Long) : PenaltyAction
    object DismissOverlay : PenaltyAction
    object TriggerBackAction : PenaltyAction
    object TriggerHomeAction : PenaltyAction
    data class RecordPenalty(
        val level: Int,
        val reason: String,
        val budgetFraction: Float,
        val appId: String
    ) : PenaltyAction
    data class RecordGuardEvent(
        val type: String,
        val metaJson: String
    ) : PenaltyAction
}

data class EvaluationResult(
    val nextState: PenaltyState,
    val actions: List<PenaltyAction>
)

class PenaltyEngine(
    private var config: GuardConfig = GuardConfig()
) {

    fun updateConfig(newConfig: GuardConfig) {
        config = newConfig
    }

    /**
     * Pure function evaluating state + input -> nextState + actions.
     */
    fun evaluate(
        currentState: PenaltyState,
        appId: String,
        budgetFraction: Float,
        continuousMinutes: Float,
        nowWallMs: Long
    ): EvaluationResult {
        val todayDate = ScoreEngine.computeLogicalDate(nowWallMs, config.resetHour)
        var state = if (todayDate != currentState.logicalDate) {
            // Day rollover: reset unlocks and strikes
            currentState.copy(
                logicalDate = todayDate,
                emergencyUnlocksUsedToday = 0,
                strikesToday = 0,
                activeLevel = PenaltyLevel.NONE,
                lockedUntilMs = 0L
            )
        } else {
            currentState
        }

        val actions = ArrayList<PenaltyAction>()

        // Check if guard is paused
        if (nowWallMs < state.pausedUntilMs) {
            if (state.activeLevel != PenaltyLevel.NONE) {
                actions.add(PenaltyAction.DismissOverlay)
            }
            return EvaluationResult(state.copy(activeLevel = PenaltyLevel.NONE), actions)
        }

        // Check if currently locked in cooldown
        if (nowWallMs < state.lockedUntilMs) {
            val remainingSec = (state.lockedUntilMs - nowWallMs) / 1000L
            actions.add(PenaltyAction.ShowLock(remainingSec))
            actions.add(PenaltyAction.TriggerBackAction)
            return EvaluationResult(state.copy(activeLevel = PenaltyLevel.L2_LOCK), actions)
        }

        // Evaluate triggers
        val budgetPercent = (budgetFraction * 100).toInt()

        // L2: 100% of budget
        if (budgetFraction >= config.lockThresholdFraction) {
            val cooldownMs = config.cooldownMinutes * 60 * 1000L
            val lockedUntil = nowWallMs + cooldownMs
            val remainingSec = cooldownMs / 1000L

            actions.add(PenaltyAction.ShowLock(remainingSec))
            actions.add(PenaltyAction.TriggerBackAction)
            actions.add(
                PenaltyAction.RecordPenalty(
                    level = PenaltyLevel.L2_LOCK.value,
                    reason = "Budget limit reached ($budgetPercent% in $appId)",
                    budgetFraction = budgetFraction,
                    appId = appId
                )
            )

            // 150% budget threshold also incurs a strike
            var newStrikes = state.strikesToday
            if (budgetFraction >= 1.5f && state.activeLevel != PenaltyLevel.L3_STRIKE) {
                newStrikes++
                actions.add(
                    PenaltyAction.RecordPenalty(
                        level = PenaltyLevel.L3_STRIKE.value,
                        reason = "Severe budget excess: $budgetPercent% of daily budget",
                        budgetFraction = budgetFraction,
                        appId = appId
                    )
                )
            }

            return EvaluationResult(
                state.copy(
                    activeLevel = if (budgetFraction >= 1.5f) PenaltyLevel.L3_STRIKE else PenaltyLevel.L2_LOCK,
                    lockedUntilMs = lockedUntil,
                    strikesToday = newStrikes
                ),
                actions
            )
        }

        // L1: 80% of budget OR 20 min continuous
        if (budgetFraction >= config.frictionThresholdFraction ||
            continuousMinutes >= config.continuousFrictionMinutes.toFloat()
        ) {
            if (state.activeLevel < PenaltyLevel.L1_FRICTION) {
                actions.add(PenaltyAction.ShowFriction(countdownSeconds = 10))
                val reason = if (budgetFraction >= config.frictionThresholdFraction) {
                    "Friction: $budgetPercent% of daily budget used"
                } else {
                    "Friction: ${continuousMinutes.toInt()} min continuous scrolling"
                }
                actions.add(
                    PenaltyAction.RecordPenalty(
                        level = PenaltyLevel.L1_FRICTION.value,
                        reason = reason,
                        budgetFraction = budgetFraction,
                        appId = appId
                    )
                )
            }
            return EvaluationResult(state.copy(activeLevel = PenaltyLevel.L1_FRICTION), actions)
        }

        // L0: 50% of budget OR 10 min continuous
        if (budgetFraction >= config.nudgeThresholdFraction ||
            continuousMinutes >= config.continuousNudgeMinutes.toFloat()
        ) {
            if (state.activeLevel < PenaltyLevel.L0_NUDGE) {
                val reason = if (budgetFraction >= config.nudgeThresholdFraction) {
                    "Nudge: $budgetPercent% of daily budget used"
                } else {
                    "Nudge: ${continuousMinutes.toInt()} min continuous scrolling"
                }
                actions.add(PenaltyAction.ShowNudge(reason))
                actions.add(
                    PenaltyAction.RecordPenalty(
                        level = PenaltyLevel.L0_NUDGE.value,
                        reason = reason,
                        budgetFraction = budgetFraction,
                        appId = appId
                    )
                )
            }
            return EvaluationResult(state.copy(activeLevel = PenaltyLevel.L0_NUDGE), actions)
        }

        // No threshold reached
        if (state.activeLevel != PenaltyLevel.NONE) {
            actions.add(PenaltyAction.DismissOverlay)
        }
        return EvaluationResult(state.copy(activeLevel = PenaltyLevel.NONE), actions)
    }

    /**
     * Handles emergency unlock request. Requires reason >= 10 chars.
     */
    fun requestEmergencyUnlock(
        currentState: PenaltyState,
        reason: String,
        nowWallMs: Long
    ): Pair<PenaltyState, Boolean> {
        if (reason.trim().length < 10) return Pair(currentState, false)
        if (currentState.emergencyUnlocksUsedToday >= config.maxEmergencyUnlocksPerDay) {
            return Pair(currentState, false)
        }

        val updated = currentState.copy(
            lockedUntilMs = 0L,
            activeLevel = PenaltyLevel.NONE,
            emergencyUnlocksUsedToday = currentState.emergencyUnlocksUsedToday + 1,
            strikesToday = currentState.strikesToday + 1
        )
        return Pair(updated, true)
    }

    /**
     * Handles temporary pause request.
     */
    fun requestPause(
        currentState: PenaltyState,
        durationMs: Long,
        nowWallMs: Long
    ): PenaltyState {
        val maxPauseMs = 15 * 60 * 1000L // Max 15 min
        val clampedDuration = durationMs.coerceIn(60_000L, maxPauseMs)
        return currentState.copy(
            pausedUntilMs = nowWallMs + clampedDuration,
            activeLevel = PenaltyLevel.NONE,
            lockedUntilMs = 0L
        )
    }
}
