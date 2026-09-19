package com.yourorg.scrollguard.core.detect

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

enum class SignalSource {
    VIEW_ID,
    HEURISTIC_TEXT,
    BEHAVIORAL,
    WHOLE_APP,
    NONE
}

data class DetectorResult(
    val inFeed: Boolean,
    val swiped: Boolean,
    val confidence: Float,
    val signal: SignalSource
) {
    companion object {
        val NOT_IN_FEED = DetectorResult(
            inFeed = false,
            swiped = false,
            confidence = 1.0f,
            signal = SignalSource.NONE
        )
    }
}

/**
 * Abstraction of accessibility node to allow pure JVM testing.
 */
interface NodeWrapper {
    val viewIdResourceName: String?
    val className: CharSequence?
    val contentDescription: CharSequence?
    fun findByViewId(viewId: String): List<NodeWrapper>
}

class RealNodeWrapper(private val node: AccessibilityNodeInfo?) : NodeWrapper {
    override val viewIdResourceName: String?
        get() = try {
            node?.viewIdResourceName
        } catch (e: Exception) {
            null
        }

    override val className: CharSequence?
        get() = try {
            node?.className
        } catch (e: Exception) {
            null
        }

    override val contentDescription: CharSequence?
        get() = try {
            node?.contentDescription
        } catch (e: Exception) {
            null
        }

    override fun findByViewId(viewId: String): List<NodeWrapper> {
        if (node == null) return emptyList()
        return try {
            node.findAccessibilityNodeInfosByViewId(viewId)?.map { RealNodeWrapper(it) } ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}

interface FeedDetector {
    val appId: String
    val packageName: String
    fun onEvent(
        eventType: Int,
        eventPackage: String,
        eventClass: String?,
        eventSourceId: String?,
        rootNode: NodeWrapper?,
        timestampMs: Long
    ): DetectorResult
}
