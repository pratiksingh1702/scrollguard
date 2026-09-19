import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/generated/native_api.g.dart';
import 'package:scrollguard/core/models/guard_models.dart';

abstract class NativeBridge {
  Future<GuardStatus> getStatus();
  Future<void> openAccessibilitySettings();
  Future<void> openUsageAccessSettings();
  Future<void> openBatterySettings();
  Future<void> requestNotificationPermission();
  Future<bool> isAccessibilityServiceEnabled();

  Future<void> applyConfig(GuardConfig config);
  Future<void> applyDetectorRules(String rulesJson);

  Future<List<SessionRecord>> getSessions(int fromEpochMs, int toEpochMs);
  Future<DailyStatsRecord?> getDailyStats(String dateIso);
  Future<List<PenaltyEventRecord>> getPenaltyEvents(
    int fromEpochMs,
    int toEpochMs,
  );
  Future<void> markSynced(List<String> ids);
  Future<List<PendingSyncItem>> getPendingSync();

  Future<bool> requestEmergencyUnlock(String reason);
  Future<void> setGuardPaused(Duration duration);

  Stream<LiveState> watchLiveState();
  Stream<GuardStatus> watchGuardStatus();
}

class AndroidNativeBridge implements NativeBridge {
  AndroidNativeBridge({
    GuardHostApi? hostApi,
    EventChannel? liveChannel,
    EventChannel? statusChannel,
  })  : _hostApi = hostApi ?? GuardHostApi(),
        _liveChannel = liveChannel ?? const EventChannel('scrollguard/live'),
        _statusChannel =
            statusChannel ?? const EventChannel('scrollguard/guardStatus');

  final GuardHostApi _hostApi;
  final EventChannel _liveChannel;
  final EventChannel _statusChannel;

  @override
  Future<GuardStatus> getStatus() async {
    final dto = await _hostApi.getStatus();
    return GuardStatus(
      isAccessibilityServiceEnabled: dto.isAccessibilityServiceEnabled,
      hasUsageStatsPermission: dto.hasUsageStatsPermission,
      hasNotificationPermission: dto.hasNotificationPermission,
      isIgnoringBatteryOptimizations: dto.isIgnoringBatteryOptimizations,
      isServiceRunning: dto.isServiceRunning,
      activePenaltyLevel: dto.activePenaltyLevel,
      strikesToday: dto.strikesToday,
      emergencyUnlocksRemaining: dto.emergencyUnlocksRemaining,
      isPaused: dto.isPaused,
      pausedUntilMs: dto.pausedUntilMs,
    );
  }

  @override
  Future<void> openAccessibilitySettings() =>
      _hostApi.openAccessibilitySettings();

  @override
  Future<void> openUsageAccessSettings() => _hostApi.openUsageAccessSettings();

  @override
  Future<void> openBatterySettings() => _hostApi.openBatterySettings();

  @override
  Future<void> requestNotificationPermission() =>
      _hostApi.requestNotificationPermission();

  @override
  Future<bool> isAccessibilityServiceEnabled() =>
      _hostApi.isAccessibilityServiceEnabled();

  @override
  Future<void> applyConfig(GuardConfig config) {
    return _hostApi.applyConfig(
      GuardConfigDto(
        dailyBudgetSeconds: config.dailyBudgetSeconds,
        nudgeThresholdFraction: config.nudgeThresholdFraction,
        frictionThresholdFraction: config.frictionThresholdFraction,
        lockThresholdFraction: config.lockThresholdFraction,
        continuousNudgeMinutes: config.continuousNudgeMinutes,
        continuousFrictionMinutes: config.continuousFrictionMinutes,
        cooldownMinutes: config.cooldownMinutes,
        maxEmergencyUnlocksPerDay: config.maxEmergencyUnlocksPerDay,
        resetHour: config.resetHour,
        guardedApps: config.guardedApps,
      ),
    );
  }

  @override
  Future<void> applyDetectorRules(String rulesJson) =>
      _hostApi.applyDetectorRules(rulesJson);

  @override
  Future<List<SessionRecord>> getSessions(
    int fromEpochMs,
    int toEpochMs,
  ) async {
    final dtos = await _hostApi.getSessions(fromEpochMs, toEpochMs);
    return dtos
        .map(
          (d) => SessionRecord(
            id: d.id,
            appId: d.appId,
            startTs: d.startTs,
            endTs: d.endTs,
            feedSeconds: d.feedSeconds,
            swipeCount: d.swipeCount,
            avgDwellMs: d.avgDwellMs,
            minDwellMs: d.minDwellMs,
            peakSpm: d.peakSpm,
            scoreMax: d.scoreMax,
            levelReached: d.levelReached,
            synced: d.synced,
          ),
        )
        .toList();
  }

  @override
  Future<DailyStatsRecord?> getDailyStats(String dateIso) async {
    final dto = await _hostApi.getDailyStats(dateIso);
    if (dto == null) return null;
    return DailyStatsRecord(
      dateIso: dto.dateIso,
      feedSeconds: dto.feedSeconds,
      swipeCount: dto.swipeCount,
      lockCount: dto.lockCount,
      strikeCount: dto.strikeCount,
      synced: dto.synced,
    );
  }

  @override
  Future<List<PenaltyEventRecord>> getPenaltyEvents(
    int fromEpochMs,
    int toEpochMs,
  ) async {
    final dtos = await _hostApi.getPenaltyEvents(fromEpochMs, toEpochMs);
    return dtos
        .map(
          (d) => PenaltyEventRecord(
            id: d.id,
            ts: d.ts,
            appId: d.appId,
            level: d.level,
            reason: d.reason,
            budgetFraction: d.budgetFraction,
            metaJson: d.metaJson,
            synced: d.synced,
          ),
        )
        .toList();
  }

  @override
  Future<void> markSynced(List<String> ids) => _hostApi.markSynced(ids);

  @override
  Future<List<PendingSyncItem>> getPendingSync() async {
    final dtos = await _hostApi.getPendingSync();
    return dtos
        .map(
          (d) => PendingSyncItem(
            id: d.id,
            type: d.type,
            payloadJson: d.payloadJson,
          ),
        )
        .toList();
  }

  @override
  Future<bool> requestEmergencyUnlock(String reason) =>
      _hostApi.requestEmergencyUnlock(reason);

  @override
  Future<void> setGuardPaused(Duration duration) =>
      _hostApi.setGuardPaused(duration.inMilliseconds);

  @override
  Stream<LiveState> watchLiveState() {
    return _liveChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return LiveState.fromMap(event);
      }
      return const LiveState();
    });
  }

  @override
  Stream<GuardStatus> watchGuardStatus() {
    return _statusChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return GuardStatus.fromMap(event);
      }
      return const GuardStatus();
    });
  }
}

class FakeNativeBridge implements NativeBridge {
  FakeNativeBridge({
    GuardStatus initialStatus = const GuardStatus(
      isAccessibilityServiceEnabled: true,
      hasUsageStatsPermission: true,
      hasNotificationPermission: true,
      isIgnoringBatteryOptimizations: true,
      isServiceRunning: true,
    ),
    GuardConfig initialConfig = const GuardConfig(),
  })  : _status = initialStatus,
        _config = initialConfig;

  GuardStatus _status;
  GuardConfig _config;

  final _liveController = StreamController<LiveState>.broadcast();
  final _statusController = StreamController<GuardStatus>.broadcast();

  final List<SessionRecord> sessions = [];
  final List<PenaltyEventRecord> penaltyEvents = [];
  final Map<String, DailyStatsRecord> dailyStats = {};
  final List<PendingSyncItem> pendingSync = [];
  final List<String> markedSyncedIds = [];

  bool accessibilitySettingsOpened = false;
  bool usageSettingsOpened = false;
  bool batterySettingsOpened = false;
  bool notificationPermissionRequested = false;
  bool configApplied = false;
  GuardConfig? appliedConfig;

  GuardConfig get currentConfig => _config;

  void emitLiveState(LiveState state) {
    _liveController.add(state);
  }

  void emitStatus(GuardStatus status) {
    _status = status;
    _statusController.add(status);
  }

  @override
  Future<GuardStatus> getStatus() async => _status;

  @override
  Future<void> openAccessibilitySettings() async {
    accessibilitySettingsOpened = true;
  }

  @override
  Future<void> openUsageAccessSettings() async {
    usageSettingsOpened = true;
  }

  @override
  Future<void> openBatterySettings() async {
    batterySettingsOpened = true;
  }

  @override
  Future<void> requestNotificationPermission() async {
    notificationPermissionRequested = true;
  }

  @override
  Future<bool> isAccessibilityServiceEnabled() async =>
      _status.isAccessibilityServiceEnabled;

  @override
  Future<void> applyConfig(GuardConfig config) async {
    _config = config;
    configApplied = true;
    appliedConfig = config;
  }

  @override
  Future<void> applyDetectorRules(String rulesJson) async {}

  @override
  Future<List<SessionRecord>> getSessions(
    int fromEpochMs,
    int toEpochMs,
  ) async {
    return sessions
        .where((s) => s.startTs >= fromEpochMs && s.startTs <= toEpochMs)
        .toList();
  }

  @override
  Future<DailyStatsRecord?> getDailyStats(String dateIso) async {
    return dailyStats[dateIso];
  }

  @override
  Future<List<PenaltyEventRecord>> getPenaltyEvents(
    int fromEpochMs,
    int toEpochMs,
  ) async {
    return penaltyEvents
        .where((p) => p.ts >= fromEpochMs && p.ts <= toEpochMs)
        .toList();
  }

  @override
  Future<void> markSynced(List<String> ids) async {
    markedSyncedIds.addAll(ids);
  }

  @override
  Future<List<PendingSyncItem>> getPendingSync() async => pendingSync;

  @override
  Future<bool> requestEmergencyUnlock(String reason) async {
    if (reason.trim().length < 10) return false;
    if (_status.emergencyUnlocksRemaining <= 0) return false;

    emitStatus(
      GuardStatus(
        isAccessibilityServiceEnabled: _status.isAccessibilityServiceEnabled,
        hasUsageStatsPermission: _status.hasUsageStatsPermission,
        hasNotificationPermission: _status.hasNotificationPermission,
        isIgnoringBatteryOptimizations: _status.isIgnoringBatteryOptimizations,
        isServiceRunning: _status.isServiceRunning,
        strikesToday: _status.strikesToday + 1,
        emergencyUnlocksRemaining: _status.emergencyUnlocksRemaining - 1,
        isPaused: _status.isPaused,
        pausedUntilMs: _status.pausedUntilMs,
      ),
    );
    return true;
  }

  @override
  Future<void> setGuardPaused(Duration duration) async {
    final until = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    emitStatus(
      GuardStatus(
        isAccessibilityServiceEnabled: _status.isAccessibilityServiceEnabled,
        hasUsageStatsPermission: _status.hasUsageStatsPermission,
        hasNotificationPermission: _status.hasNotificationPermission,
        isIgnoringBatteryOptimizations: _status.isIgnoringBatteryOptimizations,
        isServiceRunning: _status.isServiceRunning,
        strikesToday: _status.strikesToday,
        emergencyUnlocksRemaining: _status.emergencyUnlocksRemaining,
        isPaused: true,
        pausedUntilMs: until,
      ),
    );
  }

  @override
  Stream<LiveState> watchLiveState() => _liveController.stream;

  @override
  Stream<GuardStatus> watchGuardStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  void dispose() {
    _liveController.close();
    _statusController.close();
  }
}

final nativeBridgeProvider = Provider<NativeBridge>((ref) {
  return AndroidNativeBridge();
});
