package com.yourorg.scrollguard.core.detect

import android.view.accessibility.AccessibilityEvent

class RuleBasedDetector(
    private val rule: AppRule,
    private val throttleIntervalMs: Long = 400L
) : FeedDetector {

    override val appId: String = rule.id
    override val packageName: String = rule.packageName

    private var lastNodeCheckTs: Long = 0L
    private var lastFeedPresence: Boolean = false
    private var lastSwipeTs: Long = 0L

    override fun onEvent(
        eventType: Int,
        eventPackage: String,
        eventClass: String?,
        eventSourceId: String?,
        rootNode: NodeWrapper?,
        timestampMs: Long
    ): DetectorResult {
        if (eventPackage != rule.packageName) {
            return DetectorResult.NOT_IN_FEED
        }

        // Case 1: Whole app is feed (e.g. TikTok)
        if (rule.wholeAppIsFeed) {
            val isScroll = eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED
            val swiped = isScroll && (timestampMs - lastSwipeTs >= (rule.swipeSignals?.minGapMs ?: 500L))
            if (swiped) {
                lastSwipeTs = timestampMs
            }
            return DetectorResult(
                inFeed = true,
                swiped = swiped,
                confidence = 0.95f,
                signal = SignalSource.WHOLE_APP
            )
        }

        // Case 2: Direct match on eventSourceId
        val targetIds = rule.feedSignals.flatMap { it.ids }
        var inFeed = false
        var signalSource = SignalSource.NONE

        if (eventSourceId != null && targetIds.contains(eventSourceId)) {
            inFeed = true
            signalSource = SignalSource.VIEW_ID
            lastFeedPresence = true
            lastNodeCheckTs = timestampMs
        } else if (eventSourceId != null && !targetIds.contains(eventSourceId)) {
            if (rootNode != null) {
                if (timestampMs - lastNodeCheckTs >= throttleIntervalMs) {
                    lastNodeCheckTs = timestampMs
                    val found = targetIds.any { rootNode.findByViewId(it).isNotEmpty() }
                    lastFeedPresence = found
                    inFeed = found
                    signalSource = if (found) SignalSource.VIEW_ID else SignalSource.NONE
                } else {
                    inFeed = lastFeedPresence
                    signalSource = if (lastFeedPresence) SignalSource.VIEW_ID else SignalSource.NONE
                }
            } else {
                inFeed = false
                lastFeedPresence = false
                signalSource = SignalSource.NONE
            }
        } else {
            // Check throttled tree search
            if (timestampMs - lastNodeCheckTs >= throttleIntervalMs && rootNode != null) {
                lastNodeCheckTs = timestampMs
                var found = false
                for (id in targetIds) {
                    val matchingNodes = rootNode.findByViewId(id)
                    if (matchingNodes.isNotEmpty()) {
                        found = true
                        break
                    }
                }
                lastFeedPresence = found
                inFeed = found
                signalSource = if (found) SignalSource.VIEW_ID else SignalSource.NONE
            } else {
                inFeed = lastFeedPresence
                signalSource = if (lastFeedPresence) SignalSource.VIEW_ID else SignalSource.NONE
            }
        }

        // Check swipe signal
        var swiped = false
        if (inFeed && eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            val minGap = rule.swipeSignals?.minGapMs ?: 500L
            val validContainer = rule.swipeSignals?.containerViewIds?.let { containers ->
                containers.isEmpty() || (eventSourceId != null && containers.contains(eventSourceId))
            } ?: true

            if (validContainer && (timestampMs - lastSwipeTs >= minGap)) {
                swiped = true
                lastSwipeTs = timestampMs
            }
        }

        return DetectorResult(
            inFeed = inFeed,
            swiped = swiped,
            confidence = if (inFeed) 0.9f else 0.1f,
            signal = signalSource
        )
    }

    fun reset() {
        lastNodeCheckTs = 0L
        lastFeedPresence = false
        lastSwipeTs = 0L
    }
}
