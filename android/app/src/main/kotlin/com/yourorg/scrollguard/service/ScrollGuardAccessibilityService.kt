package com.yourorg.scrollguard.service

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.yourorg.scrollguard.BuildConfig
import com.yourorg.scrollguard.core.detect.BehavioralFallbackDetector
import com.yourorg.scrollguard.core.detect.FeedDetector
import com.yourorg.scrollguard.core.detect.RealNodeWrapper
import com.yourorg.scrollguard.core.detect.RuleBasedDetector
import com.yourorg.scrollguard.core.detect.RuleSetParser
import com.yourorg.scrollguard.core.model.GuardConfig
import com.yourorg.scrollguard.core.penalty.PenaltyAction
import com.yourorg.scrollguard.core.penalty.PenaltyEngine
import com.yourorg.scrollguard.core.penalty.PenaltyLevel
import com.yourorg.scrollguard.core.penalty.PenaltyState
import com.yourorg.scrollguard.core.score.ScoreEngine
import com.yourorg.scrollguard.core.session.SessionTracker
import com.yourorg.scrollguard.core.util.SystemNativeClock
import com.yourorg.scrollguard.data.AppRoomDatabase
import com.yourorg.scrollguard.data.BufferedDataWriter
import com.yourorg.scrollguard.data.ConfigStore
import com.yourorg.scrollguard.data.entity.DailyStatsEntity
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.data.entity.PenaltyEventEntity
import com.yourorg.scrollguard.data.entity.SessionEntity
import com.yourorg.scrollguard.overlay.OverlayController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

/**
 * Core AccessibilityService for detecting short-video feeds and enforcing the penalty ladder.
 *
 * HARD PRIVACY RULE: Never read, log, store, or upload on-screen text,
 * messages, usernames, or video titles. Only use view IDs, class names,
 * package names, event types, and timestamps.
 */
class ScrollGuardAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ScrollGuardA11y"

        @Volatile
        var isServiceRunning: Boolean = false
            private set

        @Volatile
        var instance: ScrollGuardAccessibilityService? = null
            private set
    }

    private var activeRuleSet: com.yourorg.scrollguard.core.detect.RuleSet? = null
    private var isUsingRemoteRules: Boolean = false
    private var activeRulesAppliedTs: Long = 0L
    private var feedMatchesSinceRuleApplied: Int = 0

    private fun loadRules() {
        try {
            val cachedFile = File(filesDir, "cached_detector_rules.json")
            if (cachedFile.exists()) {
                val json = cachedFile.readText()
                val ruleSet = RuleSetParser.parse(json)
                applyRules(ruleSet, isRemote = true)
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading cached detector rules: ${e.message}", e)
        }

        try {
            val json = assets.open("detector_rules.json").bufferedReader().use { it.readText() }
            val ruleSet = RuleSetParser.parse(json)
            applyRules(ruleSet, isRemote = false)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading detector rules: ${e.message}", e)
            val fallback = RuleSetParser.defaultFallbackRuleSet()
            applyRules(fallback, isRemote = false)
        }
    }

    fun applyRules(ruleSet: com.yourorg.scrollguard.core.detect.RuleSet, isRemote: Boolean = true) {
        activeRuleSet = ruleSet
        isUsingRemoteRules = isRemote
        activeRulesAppliedTs = System.currentTimeMillis()
        feedMatchesSinceRuleApplied = 0

        detectorMap.clear()
        for (app in ruleSet.apps) {
            detectorMap[app.packageName] = RuleBasedDetector(app)
        }
        Log.i(TAG, "Applied detector rules v${ruleSet.version} (remote=$isRemote)")
    }

    fun rollbackToLastKnownGood() {
        isUsingRemoteRules = false
        try {
            val lkgFile = File(filesDir, "last_known_good_rules.json")
            if (lkgFile.exists()) {
                val ruleSet = RuleSetParser.parse(lkgFile.readText())
                applyRules(ruleSet, isRemote = false)
                Log.i(TAG, "Rolled back to last-known-good rules v${ruleSet.version}")
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load last-known-good rules: ${e.message}", e)
        }

        try {
            val json = assets.open("detector_rules.json").bufferedReader().use { it.readText() }
            val ruleSet = RuleSetParser.parse(json)
            applyRules(ruleSet, isRemote = false)
            Log.i(TAG, "Rolled back to bundled asset rules v${ruleSet.version}")
        } catch (e: Exception) {
            val fallback = RuleSetParser.defaultFallbackRuleSet()
            applyRules(fallback, isRemote = false)
        }
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val clock = SystemNativeClock
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var database: AppRoomDatabase
    private lateinit var bufferedWriter: BufferedDataWriter
    private lateinit var configStore: ConfigStore
    private lateinit var overlayController: OverlayController

    private var config: GuardConfig = GuardConfig()
    private lateinit var scoreEngine: ScoreEngine
    private lateinit var penaltyEngine: PenaltyEngine
    private var penaltyState: PenaltyState = PenaltyState()
    private lateinit var sessionTracker: SessionTracker

    private val detectorMap = HashMap<String, FeedDetector>()
    private val fallbackDetectors = HashMap<String, BehavioralFallbackDetector>()

    private var lastFeedElapsedTs: Long = 0L

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    sessionTracker.onScreenOff()
                    serviceScope.launch(Dispatchers.IO) {
                        bufferedWriter.flush()
                    }
                    overlayController.dismiss()
                }
                Intent.ACTION_USER_PRESENT -> {
                    // Screen unlocked
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this

        database = AppRoomDatabase.getInstance(applicationContext)
        bufferedWriter = BufferedDataWriter(database)
        configStore = ConfigStore(applicationContext)
        overlayController = OverlayController(this)

        scoreEngine = ScoreEngine(clock, config)
        penaltyEngine = PenaltyEngine(config)
        penaltyState = PenaltyState(
            logicalDate = ScoreEngine.computeLogicalDate(System.currentTimeMillis(), config.resetHour)
        )

        sessionTracker = SessionTracker(
            clock = clock,
            onSessionSaved = { session ->
                bufferedWriter.queueSession(
                    SessionEntity(
                        id = session.id,
                        appId = session.appId,
                        startTs = session.startTs,
                        endTs = session.endTs,
                        feedSeconds = session.feedSeconds,
                        swipeCount = session.swipeCount,
                        avgDwellMs = session.avgDwellMs,
                        minDwellMs = session.minDwellMs,
                        peakSpm = session.peakSpm,
                        scoreMax = session.scoreMax,
                        levelReached = session.levelReached,
                        synced = false
                    )
                )

                // Update daily stats entity
                val logicalDate = ScoreEngine.computeLogicalDate(session.startTs, config.resetHour)
                serviceScope.launch(Dispatchers.IO) {
                    val existing = database.dailyStatsDao().getDailyStats(logicalDate)
                    val updated = DailyStatsEntity(
                        dateIso = logicalDate,
                        feedSeconds = (existing?.feedSeconds ?: 0L) + session.feedSeconds,
                        swipeCount = (existing?.swipeCount ?: 0) + session.swipeCount,
                        lockCount = (existing?.lockCount ?: 0) + if (session.levelReached >= PenaltyLevel.L2_LOCK.value) 1 else 0,
                        strikeCount = (existing?.strikeCount ?: 0) + if (session.levelReached >= PenaltyLevel.L3_STRIKE.value) 1 else 0,
                        synced = false
                    )
                    bufferedWriter.updateDailyStats(updated)
                }
            }
        )

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        instance = this

        loadRules()

        serviceScope.launch(Dispatchers.IO) {
            config = configStore.loadConfig()
            scoreEngine.updateConfig(config)
            penaltyEngine.updateConfig(config)

            val today = ScoreEngine.computeLogicalDate(System.currentTimeMillis(), config.resetHour)
            val stats = database.dailyStatsDao().getDailyStats(today)
            val todaySeconds = stats?.feedSeconds ?: 0L
            scoreEngine.setTodayFeedSeconds(todaySeconds)

            updateLiveState(inFeed = false, appId = "")
        }

        if (BuildConfig.DEBUG) {
            Log.d(TAG, "ScrollGuard AccessibilityService connected")
        }
    }

    private fun getDetectorForPackage(packageName: String): FeedDetector {
        return detectorMap[packageName] ?: fallbackDetectors.getOrPut(packageName) {
            BehavioralFallbackDetector(appId = packageName, packageName = packageName)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return

        val isGuarded = config.guardedApps.contains(packageName) || detectorMap.containsKey(packageName)
        if (!isGuarded) {
            if (overlayController.currentType != com.yourorg.scrollguard.overlay.OverlayType.NONE) {
                overlayController.dismiss()
            }
            sessionTracker.onFeedAbsent()
            updateLiveState(inFeed = false, appId = "")
            return
        }

        val nowElapsed = SystemClock.elapsedRealtime()
        val nowWall = System.currentTimeMillis()

        // Auto-rollback check: if using remote rules and 24h of usage produced zero feed matches
        if (isUsingRemoteRules && feedMatchesSinceRuleApplied == 0 && activeRulesAppliedTs > 0L) {
            if (nowWall - activeRulesAppliedTs > 24 * 60 * 60 * 1000L) {
                Log.w(TAG, "Auto-rolling back remote rules: 0 matches in 24h with guarded usage")
                rollbackToLastKnownGood()
            }
        }

        val detector = getDetectorForPackage(packageName)
        val rootNode = try {
            rootInActiveWindow?.let { RealNodeWrapper(it) }
        } catch (e: Exception) {
            null
        }

        val eventSourceId = try {
            event.source?.viewIdResourceName
        } catch (e: Exception) {
            null
        }

        val result = detector.onEvent(
            eventType = event.eventType,
            eventPackage = packageName,
            eventClass = event.className?.toString(),
            eventSourceId = eventSourceId,
            rootNode = rootNode,
            timestampMs = nowElapsed
        )

        if (result.inFeed) {
            feedMatchesSinceRuleApplied++
            if (isUsingRemoteRules && feedMatchesSinceRuleApplied >= 5) {
                try {
                    val cachedFile = File(filesDir, "cached_detector_rules.json")
                    if (cachedFile.exists()) {
                        val lkgFile = File(filesDir, "last_known_good_rules.json")
                        cachedFile.copyTo(lkgFile, overwrite = true)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save last-known-good rules: ${e.message}")
                }
            }

            if (lastFeedElapsedTs > 0L) {
                val deltaSec = ((nowElapsed - lastFeedElapsedTs) / 1000L).coerceIn(0L, 5L)
                if (deltaSec > 0L) {
                    scoreEngine.addFeedTime(deltaSec)
                }
            }
            lastFeedElapsedTs = nowElapsed

            sessionTracker.onFeedSignal(detector.appId, result.swiped)


            val budgetFraction = scoreEngine.getBudgetUsedFraction()
            val continuousMinutes = sessionTracker.currentSessionFeedSeconds / 60.0f

            val evalResult = penaltyEngine.evaluate(
                currentState = penaltyState,
                appId = detector.appId,
                budgetFraction = budgetFraction,
                continuousMinutes = continuousMinutes,
                nowWallMs = nowWall
            )
            penaltyState = evalResult.nextState

            val intensity = scoreEngine.computeIntensity(
                swipesPerMinute = sessionTracker.currentSessionSwipes / continuousMinutes.coerceAtLeast(0.1f),
                avgDwellMs = 0L,
                continuousMinutes = continuousMinutes
            )
            sessionTracker.updateScoreAndPenalty(intensity, penaltyState.activeLevel.value)

            executeActions(evalResult.actions)
        } else {
            sessionTracker.onFeedAbsent()
            lastFeedElapsedTs = 0L
            if (penaltyState.activeLevel != PenaltyLevel.L2_LOCK &&
                penaltyState.activeLevel != PenaltyLevel.L3_STRIKE
            ) {
                overlayController.dismiss()
            }
        }

        updateLiveState(inFeed = result.inFeed, appId = if (result.inFeed) detector.appId else "")
    }

    private fun executeActions(actions: List<PenaltyAction>) {
        for (action in actions) {
            when (action) {
                is PenaltyAction.ShowNudge -> {
                    overlayController.showNudge(action.message)
                }
                is PenaltyAction.ShowFriction -> {
                    overlayController.showFriction(
                        countdownSeconds = action.countdownSeconds,
                        onLeave = { performGlobalAction(GLOBAL_ACTION_BACK) },
                        onContinue = { /* continue allowed after timer */ }
                    )
                }
                is PenaltyAction.ShowLock -> {
                    overlayController.showLock(
                        remainingSeconds = action.remainingSeconds,
                        onLeave = {
                            performGlobalAction(GLOBAL_ACTION_BACK)
                            performGlobalAction(GLOBAL_ACTION_HOME)
                        },
                        onEmergencyUnlock = { reason ->
                            requestEmergencyUnlock(reason)
                        }
                    )
                }
                is PenaltyAction.DismissOverlay -> {
                    overlayController.dismiss()
                }
                is PenaltyAction.TriggerBackAction -> {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
                is PenaltyAction.TriggerHomeAction -> {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                }
                is PenaltyAction.RecordPenalty -> {
                    bufferedWriter.queuePenalty(
                        PenaltyEventEntity(
                            id = UUID.randomUUID().toString(),
                            ts = System.currentTimeMillis(),
                            appId = action.appId,
                            level = action.level,
                            reason = action.reason,
                            budgetFraction = action.budgetFraction,
                            metaJson = "{}"
                        )
                    )
                }
                is PenaltyAction.RecordGuardEvent -> {
                    bufferedWriter.queueGuardEvent(
                        GuardEventEntity(
                            id = UUID.randomUUID().toString(),
                            ts = System.currentTimeMillis(),
                            type = action.type,
                            metaJson = action.metaJson
                        )
                    )
                }
            }
        }
    }

    private fun updateLiveState(inFeed: Boolean, appId: String) {
        val now = System.currentTimeMillis()
        GuardStateHolder.update {
            it.copy(
                isServiceRunning = isServiceRunning,
                inFeed = inFeed,
                currentAppId = appId,
                currentSessionFeedSeconds = sessionTracker.currentSessionFeedSeconds,
                currentSessionSwipes = sessionTracker.currentSessionSwipes,
                todayFeedSeconds = scoreEngine.getTodayFeedSeconds(),
                dailyBudgetSeconds = config.dailyBudgetSeconds,
                budgetFraction = scoreEngine.getBudgetUsedFraction(),
                activePenaltyLevel = penaltyState.activeLevel.value,
                strikesToday = penaltyState.strikesToday,
                emergencyUnlocksRemaining = (config.maxEmergencyUnlocksPerDay - penaltyState.emergencyUnlocksUsedToday).coerceAtLeast(0),
                isPaused = now < penaltyState.pausedUntilMs,
                pausedUntilMs = penaltyState.pausedUntilMs
            )
        }
    }

    /**
     * Request an emergency unlock.
     * Must have reason >= 10 chars.
     */
    fun requestEmergencyUnlock(reason: String): Boolean {
        val now = System.currentTimeMillis()
        val (nextState, success) = penaltyEngine.requestEmergencyUnlock(penaltyState, reason, now)
        if (success) {
            penaltyState = nextState
            overlayController.dismiss()
            bufferedWriter.queueGuardEvent(
                GuardEventEntity(
                    id = UUID.randomUUID().toString(),
                    ts = now,
                    type = "emergency_unlock",
                    metaJson = "{\"reason\":\"${reason.replace("\"", "\\\"")}\"}"
                )
            )
            updateLiveState(inFeed = false, appId = "")
        }
        return success
    }

    /**
     * Request temporary pause (e.g. 10 minutes).
     */
    fun requestPause(durationMs: Long) {
        val now = System.currentTimeMillis()
        penaltyState = penaltyEngine.requestPause(penaltyState, durationMs, now)
        overlayController.dismiss()
        bufferedWriter.queueGuardEvent(
            GuardEventEntity(
                id = UUID.randomUUID().toString(),
                ts = now,
                type = "guard_pause",
                metaJson = "{\"durationMs\":$durationMs,\"pausedUntilMs\":${penaltyState.pausedUntilMs}}"
            )
        )
        updateLiveState(inFeed = false, appId = "")
    }

    /**
     * Apply new user-configured GuardConfig dynamically.
     */
    fun applyConfig(newConfig: GuardConfig) {
        config = newConfig
        scoreEngine.updateConfig(newConfig)
        penaltyEngine.updateConfig(newConfig)
        serviceScope.launch(Dispatchers.IO) {
            configStore.saveConfig(newConfig)
        }
        updateLiveState(inFeed = false, appId = "")
    }

    override fun onInterrupt() {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "ScrollGuard AccessibilityService interrupted")
        }
    }

    override fun onDestroy() {
        isServiceRunning = false
        instance = null
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        sessionTracker.finalizeSession()
        overlayController.dismiss()
        serviceScope.launch(Dispatchers.IO) {
            bufferedWriter.flush()
            bufferedWriter.stop()
        }
        serviceScope.cancel()
        super.onDestroy()
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "ScrollGuard AccessibilityService destroyed")
        }
    }
}
