package com.yourorg.scrollguard.core.detect

import android.view.accessibility.AccessibilityEvent
import java.util.LinkedList

class BehavioralFallbackDetector(
    override val appId: String,
    override val packageName: String,
    private val scrollThresholdPerMinute: Int = 10,
    private val windowMs: Long = 60_000L
) : FeedDetector {

    private val scrollTimestamps = LinkedList<Long>()
    private var lastRuleMatchTs: Long = 0L
    var isRulesStale: Boolean = false
        private set

    fun notifyRuleBasedMatch(timestampMs: Long) {
        lastRuleMatchTs = timestampMs
        isRulesStale = false
    }

    override fun onEvent(
        eventType: Int,
        eventPackage: String,
        eventClass: String?,
        eventSourceId: String?,
        rootNode: NodeWrapper?,
        timestampMs: Long
    ): DetectorResult {
        if (eventPackage != packageName) {
            return DetectorResult.NOT_IN_FEED
        }

        if (eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            scrollTimestamps.add(timestampMs)
        }

        // Clean out older timestamps outside window
        while (scrollTimestamps.isNotEmpty() && timestampMs - scrollTimestamps.first() > windowMs) {
            scrollTimestamps.removeFirst()
        }

        val scrollCount = scrollTimestamps.size
        val isRapidScrolling = scrollCount >= scrollThresholdPerMinute

        // If user is rapidly scrolling for > 1 min without any rule-based match
        if (isRapidScrolling && (lastRuleMatchTs == 0L || timestampMs - lastRuleMatchTs > windowMs)) {
            isRulesStale = true
            return DetectorResult(
                inFeed = true,
                swiped = eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED,
                confidence = 0.5f,
                signal = SignalSource.BEHAVIORAL
            )
        }

        return DetectorResult.NOT_IN_FEED
    }

    fun reset() {
        scrollTimestamps.clear()
        lastRuleMatchTs = 0L
        isRulesStale = false
    }
}
