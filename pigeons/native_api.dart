import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/bridge/generated/native_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/yourorg/scrollguard/bridge/NativeApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.yourorg.scrollguard.bridge',
    ),
    dartOptions: DartOptions(),
  ),
)
class GuardStatusDto {
  GuardStatusDto({
    required this.isAccessibilityServiceEnabled,
    required this.hasUsageStatsPermission,
    required this.hasNotificationPermission,
    required this.isIgnoringBatteryOptimizations,
    required this.isServiceRunning,
    required this.activePenaltyLevel,
    required this.strikesToday,
    required this.emergencyUnlocksRemaining,
    required this.isPaused,
    required this.pausedUntilMs,
  });

  final bool isAccessibilityServiceEnabled;
  final bool hasUsageStatsPermission;
  final bool hasNotificationPermission;
  final bool isIgnoringBatteryOptimizations;
  final bool isServiceRunning;
  final int activePenaltyLevel;
  final int strikesToday;
  final int emergencyUnlocksRemaining;
  final bool isPaused;
  final int pausedUntilMs;
}

class GuardConfigDto {
  GuardConfigDto({
    required this.dailyBudgetSeconds,
    required this.nudgeThresholdFraction,
    required this.frictionThresholdFraction,
    required this.lockThresholdFraction,
    required this.continuousNudgeMinutes,
    required this.continuousFrictionMinutes,
    required this.cooldownMinutes,
    required this.maxEmergencyUnlocksPerDay,
    required this.resetHour,
    required this.guardedApps,
  });

  final int dailyBudgetSeconds;
  final double nudgeThresholdFraction;
  final double frictionThresholdFraction;
  final double lockThresholdFraction;
  final int continuousNudgeMinutes;
  final int continuousFrictionMinutes;
  final int cooldownMinutes;
  final int maxEmergencyUnlocksPerDay;
  final int resetHour;
  final List<String> guardedApps;
}

class SessionDto {
  SessionDto({
    required this.id,
    required this.appId,
    required this.startTs,
    required this.endTs,
    required this.feedSeconds,
    required this.swipeCount,
    required this.avgDwellMs,
    required this.minDwellMs,
    required this.peakSpm,
    required this.scoreMax,
    required this.levelReached,
    required this.synced,
  });

  final String id;
  final String appId;
  final int startTs;
  final int endTs;
  final int feedSeconds;
  final int swipeCount;
  final int avgDwellMs;
  final int minDwellMs;
  final double peakSpm;
  final int scoreMax;
  final int levelReached;
  final bool synced;
}

class DailyStatsDto {
  DailyStatsDto({
    required this.dateIso,
    required this.feedSeconds,
    required this.swipeCount,
    required this.lockCount,
    required this.strikeCount,
    required this.synced,
  });

  final String dateIso;
  final int feedSeconds;
  final int swipeCount;
  final int lockCount;
  final int strikeCount;
  final bool synced;
}

class PenaltyEventDto {
  PenaltyEventDto({
    required this.id,
    required this.ts,
    required this.appId,
    required this.level,
    required this.reason,
    required this.budgetFraction,
    required this.metaJson,
    required this.synced,
  });

  final String id;
  final int ts;
  final String appId;
  final int level;
  final String reason;
  final double budgetFraction;
  final String metaJson;
  final bool synced;
}

class PendingSyncItemDto {
  PendingSyncItemDto({
    required this.id,
    required this.type,
    required this.payloadJson,
  });

  final String id;
  final String type;
  final String payloadJson;
}

@HostApi()
abstract class GuardHostApi {
  GuardStatusDto getStatus();
  void openAccessibilitySettings();
  void openUsageAccessSettings();
  void openBatterySettings();
  void requestNotificationPermission();
  bool isAccessibilityServiceEnabled();

  void applyConfig(GuardConfigDto config);
  void applyDetectorRules(String rulesJson);

  @async
  List<SessionDto> getSessions(int fromEpochMs, int toEpochMs);

  @async
  DailyStatsDto? getDailyStats(String dateIso);

  @async
  List<PenaltyEventDto> getPenaltyEvents(int fromEpochMs, int toEpochMs);

  @async
  void markSynced(List<String> ids);

  @async
  List<PendingSyncItemDto> getPendingSync();

  bool requestEmergencyUnlock(String reason);
  void setGuardPaused(int durationMs);
}

@FlutterApi()
abstract class GuardFlutterApi {
  void onPenaltyApplied(PenaltyEventDto event);
}
