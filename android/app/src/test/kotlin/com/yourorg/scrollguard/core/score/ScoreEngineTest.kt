package com.yourorg.scrollguard.core.score

import com.yourorg.scrollguard.core.model.GuardConfig
import com.yourorg.scrollguard.core.util.TestNativeClock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class ScoreEngineTest {

    @Test
    fun testLogicalDayBoundaryAcrossResetHour() {
        val cal = Calendar.getInstance()
        cal.set(2026, Calendar.MARCH, 15, 3, 55, 0) // 03:55 AM
        val t1 = cal.timeInMillis

        cal.set(2026, Calendar.MARCH, 15, 4, 5, 0) // 04:05 AM
        val t2 = cal.timeInMillis

        val date1 = ScoreEngine.computeLogicalDate(t1, resetHour = 4)
        val date2 = ScoreEngine.computeLogicalDate(t2, resetHour = 4)

        // 03:55 AM counts as March 14 (previous logical day)
        assertEquals("2026-03-14", date1)
        // 04:05 AM counts as March 15 (current day)
        assertEquals("2026-03-15", date2)
    }

    @Test
    fun testBudgetFractionCalculatedAccurately() {
        val clock = TestNativeClock()
        val config = GuardConfig(dailyBudgetSeconds = 1000L)
        val engine = ScoreEngine(clock, config)

        engine.setTodayFeedSeconds(500L)
        assertEquals(0.5f, engine.getBudgetUsedFraction(), 0.001f)

        engine.addFeedTime(500L)
        assertEquals(1.0f, engine.getBudgetUsedFraction(), 0.001f)

        engine.addFeedTime(200L)
        assertEquals(1.2f, engine.getBudgetUsedFraction(), 0.001f)
    }

    @Test
    fun testIntensityMonotonicWithSwipeRate() {
        val clock = TestNativeClock()
        val engine = ScoreEngine(clock)

        val scoreLowSpm = engine.computeIntensity(
            swipesPerMinute = 2.0f,
            avgDwellMs = 15_000L,
            continuousMinutes = 5.0f
        )

        val scoreHighSpm = engine.computeIntensity(
            swipesPerMinute = 10.0f,
            avgDwellMs = 15_000L,
            continuousMinutes = 5.0f
        )

        assertTrue("Higher SPM must yield higher or equal intensity", scoreHighSpm > scoreLowSpm)
    }

    @Test
    fun testIntensityHigherWithShorterDwell() {
        val clock = TestNativeClock()
        val engine = ScoreEngine(clock)

        val scoreLongDwell = engine.computeIntensity(
            swipesPerMinute = 6.0f,
            avgDwellMs = 25_000L, // 25s per video
            continuousMinutes = 5.0f
        )

        val scoreShortDwell = engine.computeIntensity(
            swipesPerMinute = 6.0f,
            avgDwellMs = 5_000L, // 5s per video (rapid flicking)
            continuousMinutes = 5.0f
        )

        assertTrue("Shorter dwell must yield higher intensity", scoreShortDwell > scoreLongDwell)
    }
}
