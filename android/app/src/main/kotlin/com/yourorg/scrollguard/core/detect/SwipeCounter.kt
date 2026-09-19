package com.yourorg.scrollguard.core.detect

import java.util.LinkedList

class SwipeCounter(
    val minGapMs: Long = 500L,
    private val maxDwellWindowSize: Int = 20
) {
    var swipeCount: Int = 0
        private set

    private var lastSwipeTimestampMs: Long = 0L
    private val recentDwellTimes = LinkedList<Long>()

    /**
     * Records an event and returns true if a valid new swipe was counted.
     */
    fun recordSwipe(timestampMs: Long): Boolean {
        if (lastSwipeTimestampMs == 0L) {
            lastSwipeTimestampMs = timestampMs
            swipeCount++
            return true
        }

        val elapsed = timestampMs - lastSwipeTimestampMs
        if (elapsed < minGapMs) {
            // Debounced
            return false
        }

        // Valid swipe
        recentDwellTimes.add(elapsed)
        if (recentDwellTimes.size > maxDwellWindowSize) {
            recentDwellTimes.removeFirst()
        }

        lastSwipeTimestampMs = timestampMs
        swipeCount++
        return true
    }

    val avgDwellMs: Long
        get() = if (recentDwellTimes.isEmpty()) 0L else (recentDwellTimes.sum() / recentDwellTimes.size)

    val minDwellMs: Long
        get() = if (recentDwellTimes.isEmpty()) 0L else (recentDwellTimes.minOrNull() ?: 0L)

    val dwellTimes: List<Long>
        get() = recentDwellTimes.toList()

    fun reset() {
        swipeCount = 0
        lastSwipeTimestampMs = 0L
        recentDwellTimes.clear()
    }
}
