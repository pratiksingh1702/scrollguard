package com.yourorg.scrollguard.core.session

import com.yourorg.scrollguard.core.model.SessionRecord
import com.yourorg.scrollguard.core.util.TestNativeClock
import org.junit.Assert.assertEquals
import org.junit.Test

class SessionTrackerTest {

    @Test
    fun testLeaveFor10sAndReturnMergesIntoOneSession() {
        val clock = TestNativeClock(wallTime = 100_000L, elapsed = 10_000L)
        val savedSessions = ArrayList<SessionRecord>()
        val tracker = SessionTracker(clock) { savedSessions.add(it) }

        // Start scrolling Shorts
        tracker.onFeedSignal("youtube_shorts", swiped = true)
        clock.advance(5_000L) // 5 seconds in feed
        tracker.onFeedSignal("youtube_shorts", swiped = true)

        // Leave for 10s (within 20s merge window)
        tracker.onFeedAbsent()
        clock.advance(10_000L)

        // Return to Shorts
        tracker.onFeedSignal("youtube_shorts", swiped = true)
        clock.advance(5_000L)
        tracker.onFeedAbsent()

        // After 25s idle, session expires
        clock.advance(25_000L)
        tracker.checkTimeouts()

        // Should be merged into 1 session
        assertEquals(1, savedSessions.size)
        val session = savedSessions[0]
        assertEquals("youtube_shorts", session.appId)
        assertEquals(3, session.swipeCount)
        assertEquals(10L, session.feedSeconds) // 5s + 5s active feed time
    }

    @Test
    fun testLeaveFor60sProducesTwoSessions() {
        val clock = TestNativeClock(wallTime = 100_000L, elapsed = 10_000L)
        val savedSessions = ArrayList<SessionRecord>()
        val tracker = SessionTracker(clock) { savedSessions.add(it) }

        // Session 1: 5 seconds, 2 swipes
        tracker.onFeedSignal("instagram_reels", swiped = true)
        clock.advance(5_000L)
        tracker.onFeedSignal("instagram_reels", swiped = true)
        tracker.onFeedAbsent()

        // Leave for 60s (exceeds 20s merge window)
        clock.advance(60_000L)
        tracker.checkTimeouts()

        assertEquals(1, savedSessions.size)

        // Session 2: 8 seconds, 2 swipes
        tracker.onFeedSignal("instagram_reels", swiped = true)
        clock.advance(8_000L)
        tracker.onFeedSignal("instagram_reels", swiped = true)
        tracker.onFeedAbsent()

        clock.advance(25_000L)
        tracker.checkTimeouts()

        assertEquals(2, savedSessions.size)
    }

    @Test
    fun testScreenOffEndsSessionImmediately() {
        val clock = TestNativeClock(wallTime = 100_000L, elapsed = 10_000L)
        val savedSessions = ArrayList<SessionRecord>()
        val tracker = SessionTracker(clock) { savedSessions.add(it) }

        tracker.onFeedSignal("tiktok", swiped = true)
        clock.advance(10_000L)
        tracker.onFeedSignal("tiktok", swiped = true)

        // Screen turned off
        tracker.onScreenOff()

        assertEquals(1, savedSessions.size)
        assertEquals("tiktok", savedSessions[0].appId)
        assertEquals(2, savedSessions[0].swipeCount)
        assertEquals(10L, savedSessions[0].feedSeconds)
    }
}
