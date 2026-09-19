package com.yourorg.scrollguard.core.detect

import android.view.accessibility.AccessibilityEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FakeNode(
    override val viewIdResourceName: String? = null,
    override val className: CharSequence? = null,
    override val contentDescription: CharSequence? = null,
    private val children: List<FakeNode> = emptyList()
) : NodeWrapper {
    override fun findByViewId(viewId: String): List<NodeWrapper> {
        val result = ArrayList<NodeWrapper>()
        if (viewIdResourceName == viewId) {
            result.add(this)
        }
        for (child in children) {
            result.addAll(child.findByViewId(viewId))
        }
        return result
    }
}

class DetectorsTest {

    @Test
    fun testRuleBasedDetectorDirectIdMatch() {
        val rule = AppRule(
            id = "youtube_shorts",
            packageName = "com.google.android.youtube",
            label = "YouTube Shorts",
            feedSignals = listOf(
                FeedSignal(
                    type = "viewIdPresent",
                    ids = listOf("com.google.android.youtube:id/reel_recycler")
                )
            ),
            swipeSignals = SwipeSignals(
                eventTypes = listOf("TYPE_VIEW_SCROLLED"),
                containerViewIds = listOf("com.google.android.youtube:id/reel_recycler"),
                minGapMs = 500L
            ),
            wholeAppIsFeed = false
        )

        val detector = RuleBasedDetector(rule)

        // Event from reel_recycler
        val result = detector.onEvent(
            eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
            eventPackage = "com.google.android.youtube",
            eventClass = "androidx.recyclerview.widget.RecyclerView",
            eventSourceId = "com.google.android.youtube:id/reel_recycler",
            rootNode = null,
            timestampMs = 1000L
        )

        assertTrue(result.inFeed)
        assertTrue(result.swiped)
        assertEquals(SignalSource.VIEW_ID, result.signal)

        // Negative test: Home feed recycler
        detector.reset()
        val homeResult = detector.onEvent(
            eventType = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            eventPackage = "com.google.android.youtube",
            eventClass = "android.widget.FrameLayout",
            eventSourceId = "com.google.android.youtube:id/browse_recycler",
            rootNode = null,
            timestampMs = 1000L
        )

        assertFalse(homeResult.inFeed)
        assertFalse(homeResult.swiped)
    }

    @Test
    fun testRuleBasedDetectorSubtreeMatch() {
        val rule = AppRule(
            id = "instagram_reels",
            packageName = "com.instagram.android",
            label = "Instagram Reels",
            feedSignals = listOf(
                FeedSignal(
                    type = "viewIdPresent",
                    ids = listOf("com.instagram.android:id/clips_viewer_view_pager")
                )
            ),
            swipeSignals = SwipeSignals(
                eventTypes = listOf("TYPE_VIEW_SCROLLED"),
                containerViewIds = listOf("com.instagram.android:id/clips_viewer_view_pager"),
                minGapMs = 500L
            ),
            wholeAppIsFeed = false
        )

        val detector = RuleBasedDetector(rule)

        val tree = FakeNode(
            viewIdResourceName = "root",
            children = listOf(
                FakeNode(viewIdResourceName = "com.instagram.android:id/clips_viewer_view_pager")
            )
        )

        val result = detector.onEvent(
            eventType = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            eventPackage = "com.instagram.android",
            eventClass = "android.widget.FrameLayout",
            eventSourceId = "unknown_child_id",
            rootNode = tree,
            timestampMs = 1000L
        )

        assertTrue(result.inFeed)
        assertEquals(SignalSource.VIEW_ID, result.signal)
    }

    @Test
    fun testWholeAppIsFeed() {
        val rule = AppRule(
            id = "tiktok",
            packageName = "com.zhiliaoapp.musically",
            label = "TikTok",
            feedSignals = emptyList(),
            swipeSignals = SwipeSignals(
                eventTypes = listOf("TYPE_VIEW_SCROLLED"),
                containerViewIds = emptyList(),
                minGapMs = 500L
            ),
            wholeAppIsFeed = true
        )

        val detector = RuleBasedDetector(rule)

        val result = detector.onEvent(
            eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
            eventPackage = "com.zhiliaoapp.musically",
            eventClass = "android.view.View",
            eventSourceId = null,
            rootNode = null,
            timestampMs = 2000L
        )

        assertTrue(result.inFeed)
        assertTrue(result.swiped)
        assertEquals(SignalSource.WHOLE_APP, result.signal)
    }

    @Test
    fun testSwipeCounterDebounceAndDwell() {
        val counter = SwipeCounter(minGapMs = 500L)

        // First swipe
        assertTrue(counter.recordSwipe(1000L))
        assertEquals(1, counter.swipeCount)

        // Rapid scroll event burst from same swipe (ignored)
        assertFalse(counter.recordSwipe(1100L))
        assertFalse(counter.recordSwipe(1200L))
        assertFalse(counter.recordSwipe(1400L))
        assertEquals(1, counter.swipeCount)

        // Second swipe after 600ms (1600ms total)
        assertTrue(counter.recordSwipe(1600L))
        assertEquals(2, counter.swipeCount)
        assertEquals(600L, counter.avgDwellMs)
        assertEquals(600L, counter.minDwellMs)

        // Third swipe after 1000ms (2600ms total)
        assertTrue(counter.recordSwipe(2600L))
        assertEquals(3, counter.swipeCount)
        assertEquals(800L, counter.avgDwellMs) // (600 + 1000) / 2 = 800
        assertEquals(600L, counter.minDwellMs)
    }

    @Test
    fun testBehavioralFallbackDetector() {
        val fallback = BehavioralFallbackDetector(
            appId = "youtube_shorts",
            packageName = "com.google.android.youtube",
            scrollThresholdPerMinute = 5,
            windowMs = 60_000L
        )

        var t = 10_000L
        // Simulate 6 scrolls within 30 seconds with 0 rule matches
        for (i in 1..6) {
            val res = fallback.onEvent(
                eventType = AccessibilityEvent.TYPE_VIEW_SCROLLED,
                eventPackage = "com.google.android.youtube",
                eventClass = null,
                eventSourceId = null,
                rootNode = null,
                timestampMs = t
            )
            t += 3000L
            if (i >= 5) {
                assertTrue(res.inFeed)
                assertEquals(SignalSource.BEHAVIORAL, res.signal)
                assertTrue(fallback.isRulesStale)
            }
        }
    }
}
