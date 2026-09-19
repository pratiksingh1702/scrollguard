package com.yourorg.scrollguard.core.stats

data class DivergenceResult(
    val isDivergent: Boolean,
    val divergencePercentage: Float,
    val reason: String?,
    val eventType: String?
)

object UsageStatsComparator {

    private const val MIN_SAMPLE_SECONDS = 60L
    private const val DIVERGENCE_THRESHOLD = 0.30f // 30%

    /**
     * Pure function comparing accessibility-tracked feed seconds against total app foreground seconds.
     *
     * In apps where the whole app is feed (e.g. TikTok), foreground seconds should closely match.
     * In apps with non-feed sections (e.g. YouTube standard videos, Instagram DMs),
     * accessibility feed time is naturally smaller, but if foreground time is dramatically higher
     * than expected and feed time is near zero while swiping occurred, this flags "rules_stale".
     */
    fun compare(
        appId: String,
        accessibilityFeedSeconds: Long,
        usageStatsForegroundSeconds: Long,
        isWholeAppFeed: Boolean = false
    ): DivergenceResult {
        // If total foreground is negligible, skip evaluation to avoid noise
        if (usageStatsForegroundSeconds < MIN_SAMPLE_SECONDS && accessibilityFeedSeconds < MIN_SAMPLE_SECONDS) {
            return DivergenceResult(
                isDivergent = false,
                divergencePercentage = 0f,
                reason = null,
                eventType = null
            )
        }

        // Case 1: Accessibility feed time exceeded total foreground by > 30%
        if (accessibilityFeedSeconds > usageStatsForegroundSeconds * (1f + DIVERGENCE_THRESHOLD)) {
            val ratio = (accessibilityFeedSeconds - usageStatsForegroundSeconds).toFloat() /
                    usageStatsForegroundSeconds.coerceAtLeast(1L).toFloat()
            return DivergenceResult(
                isDivergent = true,
                divergencePercentage = ratio * 100f,
                reason = "Accessibility recorded more time than total app foreground",
                eventType = "gap_detected"
            )
        }

        // Case 2: Whole app is feed (e.g. TikTok), but accessibility recorded significantly less (> 30% gap)
        if (isWholeAppFeed) {
            if (usageStatsForegroundSeconds > 0) {
                val gap = usageStatsForegroundSeconds - accessibilityFeedSeconds
                val ratio = gap.toFloat() / usageStatsForegroundSeconds.toFloat()
                if (ratio > DIVERGENCE_THRESHOLD && gap > MIN_SAMPLE_SECONDS) {
                    return DivergenceResult(
                        isDivergent = true,
                        divergencePercentage = ratio * 100f,
                        reason = "Accessibility missed ${gap}s (${(ratio * 100).toInt()}%) of foreground time in full-feed app $appId",
                        eventType = "rules_stale"
                    )
                }
            }
        } else {
            // Partial feed app (e.g. Instagram Reels or YouTube Shorts)
            // If user spent > 15 minutes in app and 0 feed seconds were detected, flag possible rules_stale
            if (usageStatsForegroundSeconds >= 900L && accessibilityFeedSeconds == 0L) {
                return DivergenceResult(
                    isDivergent = true,
                    divergencePercentage = 100f,
                    reason = "User spent ${usageStatsForegroundSeconds / 60} min in $appId with zero feed detection",
                    eventType = "rules_stale"
                )
            }
        }

        return DivergenceResult(
            isDivergent = false,
            divergencePercentage = 0f,
            reason = null,
            eventType = null
        )
    }
}
