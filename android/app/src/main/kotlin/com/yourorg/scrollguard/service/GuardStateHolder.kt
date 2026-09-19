package com.yourorg.scrollguard.service

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class LiveGuardState(
    val isServiceRunning: Boolean = false,
    val inFeed: Boolean = false,
    val currentAppId: String = "",
    val currentSessionFeedSeconds: Long = 0L,
    val currentSessionSwipes: Int = 0,
    val todayFeedSeconds: Long = 0L,
    val dailyBudgetSeconds: Long = 1800L,
    val budgetFraction: Float = 0f,
    val intensityScore: Int = 0,
    val activePenaltyLevel: Int = 0,
    val strikesToday: Int = 0,
    val emergencyUnlocksRemaining: Int = 1,
    val isPaused: Boolean = false,
    val pausedUntilMs: Long = 0L
)

object GuardStateHolder {
    private val _state = MutableStateFlow(LiveGuardState())
    val state: StateFlow<LiveGuardState> = _state.asStateFlow()

    fun update(transform: (LiveGuardState) -> LiveGuardState) {
        _state.value = transform(_state.value)
    }

    fun getState(): LiveGuardState = _state.value
}
