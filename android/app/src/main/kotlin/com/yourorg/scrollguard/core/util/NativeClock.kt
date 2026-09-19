package com.yourorg.scrollguard.core.util

import android.os.SystemClock

interface NativeClock {
    fun wallTimeMs(): Long
    fun elapsedRealtimeMs(): Long
}

object SystemNativeClock : NativeClock {
    override fun wallTimeMs(): Long = System.currentTimeMillis()
    override fun elapsedRealtimeMs(): Long = try {
        SystemClock.elapsedRealtime()
    } catch (e: Exception) {
        System.currentTimeMillis()
    }
}

class TestNativeClock(
    private var wallTime: Long = 1700000000000L,
    private var elapsed: Long = 10000L
) : NativeClock {
    override fun wallTimeMs(): Long = wallTime
    override fun elapsedRealtimeMs(): Long = elapsed

    fun advance(ms: Long) {
        wallTime += ms
        elapsed += ms
    }

    fun set(wallTimeMs: Long, elapsedMs: Long) {
        wallTime = wallTimeMs
        elapsed = elapsedMs
    }
}
