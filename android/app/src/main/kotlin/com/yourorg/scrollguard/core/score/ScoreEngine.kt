package com.yourorg.scrollguard.core.score

import com.yourorg.scrollguard.core.model.GuardConfig
import com.yourorg.scrollguard.core.util.NativeClock
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

class ScoreEngine(
    private val clock: NativeClock,
    private var config: GuardConfig = GuardConfig()
) {

    private var todayFeedSeconds: Long = 0L
    private var currentLogicalDate: String = ""

    init {
        currentLogicalDate = computeLogicalDate(clock.wallTimeMs(), config.resetHour)
    }

    fun updateConfig(newConfig: GuardConfig) {
        config = newConfig
    }

    fun setTodayFeedSeconds(seconds: Long) {
        todayFeedSeconds = seconds
    }

    fun getTodayFeedSeconds(): Long = todayFeedSeconds

    fun addFeedTime(deltaSeconds: Long) {
        val dateNow = computeLogicalDate(clock.wallTimeMs(), config.resetHour)
        if (dateNow != currentLogicalDate) {
            currentLogicalDate = dateNow
            todayFeedSeconds = 0L
        }
        todayFeedSeconds += deltaSeconds
    }

    fun getBudgetUsedFraction(): Float {
        val budget = max(1L, config.dailyBudgetSeconds)
        return todayFeedSeconds.toFloat() / budget.toFloat()
    }

    /**
     * Computes Doomscroll Intensity (0–100) based on §5.8:
     * 0.4 * norm(swipesPerMinute, 0..12)
     * + 0.3 * norm(1 - avgDwell/30s)
     * + 0.2 * norm(continuousMinutes, 0..20)
     * + 0.1 * timeOfDayFactor(23:00–05:00)
     */
    fun computeIntensity(
        swipesPerMinute: Float,
        avgDwellMs: Long,
        continuousMinutes: Float
    ): Int {
        // 1. Swipes per minute factor (0..12 spm)
        val spmNorm = (swipesPerMinute / 12.0f).coerceIn(0.0f, 1.0f)

        // 2. Dwell time factor: shorter dwell = higher intensity (0..30s)
        val dwellSec = avgDwellMs / 1000.0f
        val dwellNorm = (1.0f - (dwellSec / 30.0f)).coerceIn(0.0f, 1.0f)

        // 3. Continuous duration factor (0..20 min)
        val continuousNorm = (continuousMinutes / 20.0f).coerceIn(0.0f, 1.0f)

        // 4. Time of day factor (late night 23:00 - 05:00 gets 1.0, otherwise 0.0)
        val lateNightNorm = if (isLateNight(clock.wallTimeMs())) 1.0f else 0.0f

        val totalScore = (0.4f * spmNorm + 0.3f * dwellNorm + 0.2f * continuousNorm + 0.1f * lateNightNorm) * 100.0f
        return totalScore.toInt().coerceIn(0, 100)
    }

    companion object {
        fun computeLogicalDate(wallTimeMs: Long, resetHour: Int): String {
            val cal = Calendar.getInstance()
            cal.timeInMillis = wallTimeMs
            // If before resetHour, it counts as yesterday
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            if (hour < resetHour) {
                cal.add(Calendar.DAY_OF_YEAR, -1)
            }
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            return sdf.format(cal.time)
        }

        fun isLateNight(wallTimeMs: Long): Boolean {
            val cal = Calendar.getInstance()
            cal.timeInMillis = wallTimeMs
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            return hour >= 23 || hour < 5
        }
    }
}
