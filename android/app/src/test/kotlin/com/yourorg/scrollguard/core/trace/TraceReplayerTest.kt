package com.yourorg.scrollguard.core.trace

import android.view.accessibility.AccessibilityEvent
import com.yourorg.scrollguard.core.detect.DetectorRegistry
import com.yourorg.scrollguard.core.detect.RuleSetParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TraceReplayerTest {

    private val ruleSet = RuleSetParser.defaultFallbackRuleSet()
    private val detectorRegistry = DetectorRegistry(ruleSet)
    private val replayer = TraceReplayer(detectorRegistry)

    @Test
    fun testReplayYoutubeShortsDoomscroll() {
        val events = ArrayList<TraceEvent>()
        var t = 10_000L

        // Enters Shorts and swipes 5 times with 4-second dwell
        for (i in 1..5) {
            events.add(
                TraceEvent(
                    eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
                    eventPackage = "com.google.android.youtube",
                    eventClass = "androidx.recyclerview.widget.RecyclerView",
                    eventSourceId = "com.google.android.youtube:id/reel_recycler",
                    timestampMs = t
                )
            )
            t += 4_000L
        }

        val fixture = TraceFixture("youtube_shorts_doomscroll", "youtube_shorts", events)
        val sessions = replayer.replay(fixture)

        assertEquals(1, sessions.size)
        val session = sessions[0]
        assertEquals("youtube_shorts", session.appId)
        assertEquals(5, session.swipeCount)
        assertTrue(session.feedSeconds >= 12L)
    }

    @Test
    fun testReplayYoutubeLongVideoBrowsingYieldsZeroFeedSessions() {
        val events = ArrayList<TraceEvent>()
        var t = 10_000L

        // Watching long video on watch_while_layout
        for (i in 1..10) {
            events.add(
                TraceEvent(
                    eventType = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
                    eventPackage = "com.google.android.youtube",
                    eventClass = "android.view.ViewGroup",
                    eventSourceId = "com.google.android.youtube:id/watch_while_layout",
                    timestampMs = t
                )
            )
            t += 3_000L
        }

        val fixture = TraceFixture("youtube_long_video", "youtube_shorts", events)
        val sessions = replayer.replay(fixture)

        assertEquals(0, sessions.size)
    }

    @Test
    fun testReplayInstagramReelsTwoVisitsYieldsTwoSessions() {
        val events = ArrayList<TraceEvent>()
        var t = 10_000L

        // Visit 1: 2 swipes in Reels
        events.add(
            TraceEvent(
                eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
                eventPackage = "com.instagram.android",
                eventClass = "androidx.viewpager2.widget.ViewPager2",
                eventSourceId = "com.instagram.android:id/clips_viewer_view_pager",
                timestampMs = t
            )
        )
        t += 3_000L
        events.add(
            TraceEvent(
                eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
                eventPackage = "com.instagram.android",
                eventClass = "androidx.viewpager2.widget.ViewPager2",
                eventSourceId = "com.instagram.android:id/clips_viewer_view_pager",
                timestampMs = t
            )
        )

        // Leave Reels after 1s (feed absent event)
        t += 1_000L
        events.add(
            TraceEvent(
                eventType = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
                eventPackage = "com.instagram.android",
                eventClass = "android.widget.FrameLayout",
                eventSourceId = "com.instagram.android:id/main_feed",
                timestampMs = t
            )
        )

        // Return to Reels 60 seconds later (exceeds 20s merge window)
        t += 60_000L
        events.add(
            TraceEvent(
                eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
                eventPackage = "com.instagram.android",
                eventClass = "androidx.viewpager2.widget.ViewPager2",
                eventSourceId = "com.instagram.android:id/clips_viewer_view_pager",
                timestampMs = t
            )
        )
        t += 4_000L
        events.add(
            TraceEvent(
                eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
                eventPackage = "com.instagram.android",
                eventClass = "androidx.viewpager2.widget.ViewPager2",
                eventSourceId = "com.instagram.android:id/clips_viewer_view_pager",
                timestampMs = t
            )
        )

        val fixture = TraceFixture("instagram_two_visits", "instagram_reels", events)
        val sessions = replayer.replay(fixture)

        assertEquals(2, sessions.size)
    }
}
