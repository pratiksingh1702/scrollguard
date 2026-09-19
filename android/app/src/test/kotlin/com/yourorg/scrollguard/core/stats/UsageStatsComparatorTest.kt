package com.yourorg.scrollguard.core.stats

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageStatsComparatorTest {

    @Test
    fun testNegligibleSampleTimesDoNotFlagDivergence() {
        val result = UsageStatsComparator.compare(
            appId = "com.zhiliaoapp.musically",
            accessibilityFeedSeconds = 20L,
            usageStatsForegroundSeconds = 40L,
            isWholeAppFeed = true
        )
        assertFalse(result.isDivergent)
    }

    @Test
    fun testWithinThirtyPercentTolerancePasses() {
        val result = UsageStatsComparator.compare(
            appId = "com.zhiliaoapp.musically",
            accessibilityFeedSeconds = 850L,
            usageStatsForegroundSeconds = 1000L,
            isWholeAppFeed = true
        )
        assertFalse(result.isDivergent)
    }

    @Test
    fun testWholeAppFeedMissesOverThirtyPercentFlagsRulesStale() {
        val result = UsageStatsComparator.compare(
            appId = "com.zhiliaoapp.musically",
            accessibilityFeedSeconds = 400L,
            usageStatsForegroundSeconds = 1000L,
            isWholeAppFeed = true
        )
        assertTrue(result.isDivergent)
        assertEquals("rules_stale", result.eventType)
        assertEquals(60.0f, result.divergencePercentage, 0.1f)
    }

    @Test
    fun testExcessiveAccessibilityTimeFlagsGapDetected() {
        val result = UsageStatsComparator.compare(
            appId = "com.google.android.youtube",
            accessibilityFeedSeconds = 1500L,
            usageStatsForegroundSeconds = 1000L,
            isWholeAppFeed = false
        )
        assertTrue(result.isDivergent)
        assertEquals("gap_detected", result.eventType)
    }

    @Test
    fun testProlongedForegroundWithZeroFeedFlagsRulesStale() {
        val result = UsageStatsComparator.compare(
            appId = "com.instagram.android",
            accessibilityFeedSeconds = 0L,
            usageStatsForegroundSeconds = 1200L, // 20 minutes
            isWholeAppFeed = false
        )
        assertTrue(result.isDivergent)
        assertEquals("rules_stale", result.eventType)
    }
}
