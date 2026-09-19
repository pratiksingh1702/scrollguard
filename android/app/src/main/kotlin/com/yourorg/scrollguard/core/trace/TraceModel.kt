package com.yourorg.scrollguard.core.trace

data class TraceEvent(
    val eventType: Int,
    val eventPackage: String,
    val eventClass: String? = null,
    val eventSourceId: String? = null,
    val timestampMs: Long
)

data class TraceFixture(
    val name: String,
    val appId: String,
    val events: List<TraceEvent>
)
