package com.yourorg.scrollguard.core.detect

class DetectorRegistry(private var ruleSet: RuleSet) {

    private val ruleDetectors = HashMap<String, RuleBasedDetector>()
    private val fallbackDetectors = HashMap<String, BehavioralFallbackDetector>()

    init {
        initializeDetectors()
    }

    private fun initializeDetectors() {
        ruleDetectors.clear()
        fallbackDetectors.clear()
        for (app in ruleSet.apps) {
            ruleDetectors[app.packageName] = RuleBasedDetector(app)
            fallbackDetectors[app.packageName] = BehavioralFallbackDetector(app.id, app.packageName)
        }
    }

    fun updateRules(newRuleSet: RuleSet) {
        ruleSet = newRuleSet
        initializeDetectors()
    }

    fun onEvent(
        eventType: Int,
        eventPackage: String,
        eventClass: String?,
        eventSourceId: String?,
        rootNode: NodeWrapper?,
        timestampMs: Long
    ): DetectorResult {
        val ruleDetector = ruleDetectors[eventPackage] ?: return DetectorResult.NOT_IN_FEED
        val fallbackDetector = fallbackDetectors[eventPackage]

        val result = ruleDetector.onEvent(
            eventType = eventType,
            eventPackage = eventPackage,
            eventClass = eventClass,
            eventSourceId = eventSourceId,
            rootNode = rootNode,
            timestampMs = timestampMs
        )

        if (result.inFeed) {
            fallbackDetector?.notifyRuleBasedMatch(timestampMs)
            return result
        }

        // Try behavioral fallback if rule detector returned false
        if (fallbackDetector != null) {
            val fallbackResult = fallbackDetector.onEvent(
                eventType = eventType,
                eventPackage = eventPackage,
                eventClass = eventClass,
                eventSourceId = eventSourceId,
                rootNode = rootNode,
                timestampMs = timestampMs
            )
            if (fallbackResult.inFeed) {
                return fallbackResult
            }
        }

        return result
    }

    fun isRulesStale(packageName: String): Boolean {
        return fallbackDetectors[packageName]?.isRulesStale ?: false
    }
}
