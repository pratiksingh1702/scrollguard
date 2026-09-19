package com.yourorg.scrollguard.bridge

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.yourorg.scrollguard.core.model.GuardConfig
import com.yourorg.scrollguard.core.stats.UsageStatsReader
import com.yourorg.scrollguard.data.AppRoomDatabase
import com.yourorg.scrollguard.data.ConfigStore
import com.yourorg.scrollguard.service.GuardStateHolder
import com.yourorg.scrollguard.service.ScrollGuardAccessibilityService
import com.yourorg.scrollguard.worker.WatchdogWorker
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

class ScrollGuardPlugin : FlutterPlugin, GuardHostApi {

    companion object {
        private const val TAG = "ScrollGuardPlugin"
        private const val LIVE_CHANNEL = "scrollguard/live"
        private const val STATUS_CHANNEL = "scrollguard/guardStatus"
    }

    private var context: Context? = null
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var liveEventChannel: EventChannel? = null
    private var statusEventChannel: EventChannel? = null

    private var liveJob: Job? = null
    private var statusJob: Job? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val messenger = binding.binaryMessenger

        GuardHostApi.setUp(messenger, this)

        setupEventChannels(messenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        GuardHostApi.setUp(binding.binaryMessenger, null)
        liveEventChannel?.setStreamHandler(null)
        statusEventChannel?.setStreamHandler(null)
        liveJob?.cancel()
        statusJob?.cancel()
        pluginScope.cancel()
        context = null
    }

    private fun setupEventChannels(messenger: BinaryMessenger) {
        liveEventChannel = EventChannel(messenger, LIVE_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) return
                    liveJob?.cancel()
                    liveJob = pluginScope.launch {
                        GuardStateHolder.state.collectLatest { state ->
                            val map = HashMap<String, Any?>()
                            map["appId"] = state.currentAppId
                            map["inFeed"] = state.inFeed
                            map["sessionSeconds"] = state.currentSessionFeedSeconds
                            map["swipeCount"] = state.currentSessionSwipes
                            map["todayFeedSeconds"] = state.todayFeedSeconds
                            map["dailyBudgetSeconds"] = state.dailyBudgetSeconds
                            map["budgetFraction"] = state.budgetFraction.toDouble()
                            map["intensity"] = state.intensityScore
                            map["activePenaltyLevel"] = state.activePenaltyLevel.toLong()
                            map["strikesToday"] = state.strikesToday.toLong()
                            map["emergencyUnlocksRemaining"] = state.emergencyUnlocksRemaining.toLong()
                            map["isPaused"] = state.isPaused
                            map["pausedUntilMs"] = state.pausedUntilMs

                            mainHandler.post {
                                events.success(map)
                            }
                            delay(1000L) // Throttle to 1 Hz
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    liveJob?.cancel()
                    liveJob = null
                }
            })
        }

        statusEventChannel = EventChannel(messenger, STATUS_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) return
                    statusJob?.cancel()
                    statusJob = pluginScope.launch {
                        while (true) {
                            val status = getStatus()
                            val map = HashMap<String, Any?>()
                            map["isAccessibilityServiceEnabled"] = status.isAccessibilityServiceEnabled
                            map["hasUsageStatsPermission"] = status.hasUsageStatsPermission
                            map["hasNotificationPermission"] = status.hasNotificationPermission
                            map["isIgnoringBatteryOptimizations"] = status.isIgnoringBatteryOptimizations
                            map["isServiceRunning"] = status.isServiceRunning
                            map["activePenaltyLevel"] = status.activePenaltyLevel
                            map["strikesToday"] = status.strikesToday
                            map["emergencyUnlocksRemaining"] = status.emergencyUnlocksRemaining
                            map["isPaused"] = status.isPaused
                            map["pausedUntilMs"] = status.pausedUntilMs

                            mainHandler.post {
                                events.success(map)
                            }
                            delay(3000L) // Poll status changes every 3s
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    statusJob?.cancel()
                    statusJob = null
                }
            })
        }
    }

    // --- GuardHostApi implementation ---

    override fun getStatus(): GuardStatusDto {
        val ctx = context ?: return GuardStatusDto(
            isAccessibilityServiceEnabled = false,
            hasUsageStatsPermission = false,
            hasNotificationPermission = false,
            isIgnoringBatteryOptimizations = false,
            isServiceRunning = false,
            activePenaltyLevel = 0L,
            strikesToday = 0L,
            emergencyUnlocksRemaining = 1L,
            isPaused = false,
            pausedUntilMs = 0L
        )

        val a11yEnabled = WatchdogWorker.isAccessibilityEnabled(ctx, ScrollGuardAccessibilityService::class.java)
        val usageAccess = UsageStatsReader.hasUsageStatsPermission(ctx)
        val notifs = NotificationManagerCompat.from(ctx).areNotificationsEnabled()

        val powerManager = ctx.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val batteryIgnored = powerManager?.isIgnoringBatteryOptimizations(ctx.packageName) ?: false

        val liveState = GuardStateHolder.getState()

        return GuardStatusDto(
            isAccessibilityServiceEnabled = a11yEnabled,
            hasUsageStatsPermission = usageAccess,
            hasNotificationPermission = notifs,
            isIgnoringBatteryOptimizations = batteryIgnored,
            isServiceRunning = ScrollGuardAccessibilityService.isServiceRunning,
            activePenaltyLevel = liveState.activePenaltyLevel.toLong(),
            strikesToday = liveState.strikesToday.toLong(),
            emergencyUnlocksRemaining = liveState.emergencyUnlocksRemaining.toLong(),
            isPaused = liveState.isPaused,
            pausedUntilMs = liveState.pausedUntilMs
        )
    }

    override fun openAccessibilitySettings() {
        val ctx = context ?: return
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        ctx.startActivity(intent)
    }

    override fun openUsageAccessSettings() {
        val ctx = context ?: return
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        ctx.startActivity(intent)
    }

    override fun openBatterySettings() {
        val ctx = context ?: return
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        } else {
            Intent(Settings.ACTION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        }
        ctx.startActivity(intent)
    }

    override fun requestNotificationPermission() {
        val ctx = context ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            ctx.startActivity(intent)
        }
    }

    override fun isAccessibilityServiceEnabled(): Boolean {
        val ctx = context ?: return false
        return WatchdogWorker.isAccessibilityEnabled(ctx, ScrollGuardAccessibilityService::class.java)
    }

    override fun applyConfig(config: GuardConfigDto) {
        val ctx = context ?: return
        val domainConfig = GuardConfig(
            dailyBudgetSeconds = config.dailyBudgetSeconds,
            nudgeThresholdFraction = config.nudgeThresholdFraction.toFloat(),
            frictionThresholdFraction = config.frictionThresholdFraction.toFloat(),
            lockThresholdFraction = config.lockThresholdFraction.toFloat(),
            continuousNudgeMinutes = config.continuousNudgeMinutes,
            continuousFrictionMinutes = config.continuousFrictionMinutes,
            cooldownMinutes = config.cooldownMinutes,
            maxEmergencyUnlocksPerDay = config.maxEmergencyUnlocksPerDay.toInt(),
            resetHour = config.resetHour.toInt(),
            guardedApps = config.guardedApps
        )

        ScrollGuardAccessibilityService.instance?.applyConfig(domainConfig)

        pluginScope.launch(Dispatchers.IO) {
            ConfigStore(ctx).saveConfig(domainConfig)
        }
    }

    override fun applyDetectorRules(rulesJson: String) {
        Log.d(TAG, "applyDetectorRules called with ${rulesJson.length} bytes")
        // Persist or apply to service if needed
    }

    override fun getSessions(
        fromEpochMs: Long,
        toEpochMs: Long,
        callback: (Result<List<SessionDto>>) -> Unit
    ) {
        val ctx = context
        if (ctx == null) {
            callback(Result.success(emptyList()))
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val db = AppRoomDatabase.getInstance(ctx)
                val entities = db.sessionDao().getSessions(fromEpochMs, toEpochMs)
                val dtos = entities.map { e ->
                    SessionDto(
                        id = e.id,
                        appId = e.appId,
                        startTs = e.startTs,
                        endTs = e.endTs,
                        feedSeconds = e.feedSeconds,
                        swipeCount = e.swipeCount.toLong(),
                        avgDwellMs = e.avgDwellMs,
                        minDwellMs = e.minDwellMs,
                        peakSpm = e.peakSpm.toDouble(),
                        scoreMax = e.scoreMax.toLong(),
                        levelReached = e.levelReached.toLong(),
                        synced = e.synced
                    )
                }
                withContext(Dispatchers.Main) {
                    callback(Result.success(dtos))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getDailyStats(
        dateIso: String,
        callback: (Result<DailyStatsDto?>) -> Unit
    ) {
        val ctx = context
        if (ctx == null) {
            callback(Result.success(null))
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val db = AppRoomDatabase.getInstance(ctx)
                val e = db.dailyStatsDao().getDailyStats(dateIso)
                val dto = e?.let {
                    DailyStatsDto(
                        dateIso = it.dateIso,
                        feedSeconds = it.feedSeconds,
                        swipeCount = it.swipeCount.toLong(),
                        lockCount = it.lockCount.toLong(),
                        strikeCount = it.strikeCount.toLong(),
                        synced = it.synced
                    )
                }
                withContext(Dispatchers.Main) {
                    callback(Result.success(dto))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getPenaltyEvents(
        fromEpochMs: Long,
        toEpochMs: Long,
        callback: (Result<List<PenaltyEventDto>>) -> Unit
    ) {
        val ctx = context
        if (ctx == null) {
            callback(Result.success(emptyList()))
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val db = AppRoomDatabase.getInstance(ctx)
                val list = db.penaltyEventDao().getPenaltyEvents(fromEpochMs, toEpochMs).map { e ->
                    PenaltyEventDto(
                        id = e.id,
                        ts = e.ts,
                        appId = e.appId,
                        level = e.level.toLong(),
                        reason = e.reason,
                        budgetFraction = e.budgetFraction.toDouble(),
                        metaJson = e.metaJson,
                        synced = e.synced
                    )
                }
                withContext(Dispatchers.Main) {
                    callback(Result.success(list))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun markSynced(
        ids: List<String>,
        callback: (Result<Unit>) -> Unit
    ) {
        val ctx = context
        if (ctx == null) {
            callback(Result.success(Unit))
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val db = AppRoomDatabase.getInstance(ctx)
                db.sessionDao().markSynced(ids)
                db.penaltyEventDao().markSynced(ids)
                db.guardEventDao().markSynced(ids)
                withContext(Dispatchers.Main) {
                    callback(Result.success(Unit))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getPendingSync(callback: (Result<List<PendingSyncItemDto>>) -> Unit) {
        val ctx = context
        if (ctx == null) {
            callback(Result.success(emptyList()))
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val db = AppRoomDatabase.getInstance(ctx)
                val items = ArrayList<PendingSyncItemDto>()

                val unsyncedSessions = db.sessionDao().getUnsyncedSessions()
                for (s in unsyncedSessions) {
                    val json = JSONObject().apply {
                        put("id", s.id)
                        put("appId", s.appId)
                        put("startTs", s.startTs)
                        put("endTs", s.endTs)
                        put("feedSeconds", s.feedSeconds)
                        put("swipeCount", s.swipeCount)
                        put("scoreMax", s.scoreMax)
                    }
                    items.add(PendingSyncItemDto(id = s.id, type = "session", payloadJson = json.toString()))
                }

                val unsyncedPenalties = db.penaltyEventDao().getUnsyncedEvents()
                for (p in unsyncedPenalties) {
                    val json = JSONObject().apply {
                        put("id", p.id)
                        put("ts", p.ts)
                        put("appId", p.appId)
                        put("level", p.level)
                        put("reason", p.reason)
                        put("budgetFraction", p.budgetFraction)
                    }
                    items.add(PendingSyncItemDto(id = p.id, type = "penalty", payloadJson = json.toString()))
                }

                val unsyncedGuardEvents = db.guardEventDao().getUnsyncedEvents()
                for (g in unsyncedGuardEvents) {
                    val json = JSONObject().apply {
                        put("id", g.id)
                        put("ts", g.ts)
                        put("type", g.type)
                        put("metaJson", g.metaJson)
                    }
                    items.add(PendingSyncItemDto(id = g.id, type = "guard_event", payloadJson = json.toString()))
                }

                withContext(Dispatchers.Main) {
                    callback(Result.success(items))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun requestEmergencyUnlock(reason: String): Boolean {
        return ScrollGuardAccessibilityService.instance?.requestEmergencyUnlock(reason) ?: false
    }

    override fun setGuardPaused(durationMs: Long) {
        ScrollGuardAccessibilityService.instance?.requestPause(durationMs)
    }
}
