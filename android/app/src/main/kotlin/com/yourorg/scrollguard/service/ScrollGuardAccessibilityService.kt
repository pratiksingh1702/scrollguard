package com.yourorg.scrollguard.service

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.yourorg.scrollguard.BuildConfig

/**
 * Core AccessibilityService for detecting short-video feeds.
 *
 * HARD PRIVACY RULE: Never read, log, store, or upload on-screen text,
 * messages, usernames, or video titles. Only use view IDs, class names,
 * package names, event types, and timestamps.
 */
class ScrollGuardAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ScrollGuardA11y"
        private val GUARDED_PACKAGES = setOf(
            "com.google.android.youtube",
            "com.instagram.android",
            "com.zhiliaoapp.musically",
            "com.ss.android.ugc.trill",
            "com.facebook.katana",
            "com.snapchat.android"
        )

        @Volatile
        var isServiceRunning: Boolean = false
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "ScrollGuard AccessibilityService connected")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return

        // Filter strictly to guarded packages
        if (!GUARDED_PACKAGES.contains(packageName)) return

        if (BuildConfig.DEBUG) {
            val eventTypeName = AccessibilityEvent.eventTypeToString(event.eventType)
            val className = event.className?.toString() ?: "unknown_class"
            val viewId = try {
                event.source?.viewIdResourceName ?: "no_id"
            } catch (e: Exception) {
                "error_id"
            }
            Log.d(TAG, "Event: pkg=$packageName type=$eventTypeName class=$className id=$viewId")
        }
    }

    override fun onInterrupt() {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "ScrollGuard AccessibilityService interrupted")
        }
    }

    override fun onDestroy() {
        isServiceRunning = false
        super.onDestroy()
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "ScrollGuard AccessibilityService destroyed")
        }
    }
}
