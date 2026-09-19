package com.yourorg.scrollguard.core.trace

import com.yourorg.scrollguard.core.detect.DetectorRegistry
import com.yourorg.scrollguard.core.model.SessionRecord
import com.yourorg.scrollguard.core.session.SessionTracker
import com.yourorg.scrollguard.core.util.TestNativeClock

class TraceReplayer(
    private val detectorRegistry: DetectorRegistry
) {
    fun replay(fixture: TraceFixture): List<SessionRecord> {
        val completedSessions = ArrayList<SessionRecord>()
        if (fixture.events.isEmpty()) return completedSessions

        val initialTime = fixture.events.first().timestampMs
        val clock = TestNativeClock(wallTime = initialTime, elapsed = 0L)
        val tracker = SessionTracker(clock) { completedSessions.add(it) }

        for (event in fixture.events) {
            val elapsedDelta = event.timestampMs - initialTime
            clock.set(wallTimeMs = event.timestampMs, elapsedMs = elapsedDelta)

            val result = detectorRegistry.onEvent(
                eventType = event.eventType,
                eventPackage = event.eventPackage,
                eventClass = event.eventClass,
                eventSourceId = event.eventSourceId,
                rootNode = null,
                timestampMs = event.timestampMs
            )

            if (result.inFeed) {
                tracker.onFeedSignal(fixture.appId, swiped = result.swiped)
            } else {
                tracker.onFeedAbsent()
            }
            tracker.checkTimeouts()
        }

        // Finalize any lingering session
        tracker.finalizeSession()
        return completedSessions
    }
}
