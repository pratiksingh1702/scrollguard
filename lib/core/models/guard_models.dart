import 'package:flutter/foundation.dart';

@immutable
class GuardConfig {
  const GuardConfig({
    this.dailyBudgetSeconds = 1800,
    this.nudgeThresholdFraction = 0.5,
    this.frictionThresholdFraction = 0.8,
    this.lockThresholdFraction = 1.0,
    this.continuousNudgeMinutes = 10,
    this.continuousFrictionMinutes = 20,
    this.cooldownMinutes = 30,
    this.maxEmergencyUnlocksPerDay = 1,
    this.resetHour = 4,
    this.guardedApps = const [
      'com.google.android.youtube',
      'com.instagram.android',
      'com.zhiliaoapp.musically',
    ],
  });

  factory GuardConfig.fromJson(Map<String, dynamic> json) {
    return GuardConfig(
      dailyBudgetSeconds: (json['dailyBudgetSeconds'] as num?)?.toInt() ?? 1800,
      nudgeThresholdFraction:
          (json['nudgeThresholdFraction'] as num?)?.toDouble() ?? 0.5,
      frictionThresholdFraction:
          (json['frictionThresholdFraction'] as num?)?.toDouble() ?? 0.8,
      lockThresholdFraction:
          (json['lockThresholdFraction'] as num?)?.toDouble() ?? 1.0,
      continuousNudgeMinutes:
          (json['continuousNudgeMinutes'] as num?)?.toInt() ?? 10,
      continuousFrictionMinutes:
          (json['continuousFrictionMinutes'] as num?)?.toInt() ?? 20,
      cooldownMinutes: (json['cooldownMinutes'] as num?)?.toInt() ?? 30,
      maxEmergencyUnlocksPerDay:
          (json['maxEmergencyUnlocksPerDay'] as num?)?.toInt() ?? 1,
      resetHour: (json['resetHour'] as num?)?.toInt() ?? 4,
      guardedApps: (json['guardedApps'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [
            'com.google.android.youtube',
            'com.instagram.android',
            'com.zhiliaoapp.musically',
          ],
    );
  }

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

  GuardConfig copyWith({
    int? dailyBudgetSeconds,
    double? nudgeThresholdFraction,
    double? frictionThresholdFraction,
    double? lockThresholdFraction,
    int? continuousNudgeMinutes,
    int? continuousFrictionMinutes,
    int? cooldownMinutes,
    int? maxEmergencyUnlocksPerDay,
    int? resetHour,
    List<String>? guardedApps,
  }) {
    return GuardConfig(
      dailyBudgetSeconds: dailyBudgetSeconds ?? this.dailyBudgetSeconds,
      nudgeThresholdFraction:
          nudgeThresholdFraction ?? this.nudgeThresholdFraction,
      frictionThresholdFraction:
          frictionThresholdFraction ?? this.frictionThresholdFraction,
      lockThresholdFraction:
          lockThresholdFraction ?? this.lockThresholdFraction,
      continuousNudgeMinutes:
          continuousNudgeMinutes ?? this.continuousNudgeMinutes,
      continuousFrictionMinutes:
          continuousFrictionMinutes ?? this.continuousFrictionMinutes,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      maxEmergencyUnlocksPerDay:
          maxEmergencyUnlocksPerDay ?? this.maxEmergencyUnlocksPerDay,
      resetHour: resetHour ?? this.resetHour,
      guardedApps: guardedApps ?? this.guardedApps,
    );
  }

  Map<String, dynamic> toJson() => {
        'dailyBudgetSeconds': dailyBudgetSeconds,
        'nudgeThresholdFraction': nudgeThresholdFraction,
        'frictionThresholdFraction': frictionThresholdFraction,
        'lockThresholdFraction': lockThresholdFraction,
        'continuousNudgeMinutes': continuousNudgeMinutes,
        'continuousFrictionMinutes': continuousFrictionMinutes,
        'cooldownMinutes': cooldownMinutes,
        'maxEmergencyUnlocksPerDay': maxEmergencyUnlocksPerDay,
        'resetHour': resetHour,
        'guardedApps': guardedApps,
      };
}

@immutable
class LiveState {
  const LiveState({
    this.appId = '',
    this.inFeed = false,
    this.sessionSeconds = 0,
    this.swipeCount = 0,
    this.todayFeedSeconds = 0,
    this.dailyBudgetSeconds = 1800,
    this.budgetFraction = 0.0,
    this.intensity = 0,
    this.penaltyLevel = 0,
    this.strikesToday = 0,
    this.emergencyUnlocksRemaining = 1,
    this.isPaused = false,
    this.pausedUntilMs = 0,
  });

  factory LiveState.fromMap(Map<dynamic, dynamic> map) {
    return LiveState(
      appId: (map['appId'] as String?) ?? '',
      inFeed: (map['inFeed'] as bool?) ?? false,
      sessionSeconds: (map['sessionSeconds'] as num?)?.toInt() ?? 0,
      swipeCount: (map['swipeCount'] as num?)?.toInt() ?? 0,
      todayFeedSeconds: (map['todayFeedSeconds'] as num?)?.toInt() ?? 0,
      dailyBudgetSeconds: (map['dailyBudgetSeconds'] as num?)?.toInt() ?? 1800,
      budgetFraction: (map['budgetFraction'] as num?)?.toDouble() ?? 0.0,
      intensity: (map['intensity'] as num?)?.toInt() ?? 0,
      penaltyLevel: (map['activePenaltyLevel'] as num?)?.toInt() ?? 0,
      strikesToday: (map['strikesToday'] as num?)?.toInt() ?? 0,
      emergencyUnlocksRemaining:
          (map['emergencyUnlocksRemaining'] as num?)?.toInt() ?? 1,
      isPaused: (map['isPaused'] as bool?) ?? false,
      pausedUntilMs: (map['pausedUntilMs'] as num?)?.toInt() ?? 0,
    );
  }

  final String appId;
  final bool inFeed;
  final int sessionSeconds;
  final int swipeCount;
  final int todayFeedSeconds;
  final int dailyBudgetSeconds;
  final double budgetFraction;
  final int intensity;
  final int penaltyLevel;
  final int strikesToday;
  final int emergencyUnlocksRemaining;
  final bool isPaused;
  final int pausedUntilMs;

  /// Whether the current session exhibits rapid compulsive doomscrolling behavior
  /// (high intensity or high swipes-per-minute rate).
  bool get isDoomscrolling =>
      intensity >= 50 ||
      (sessionSeconds > 30 && (swipeCount / (sessionSeconds / 60.0)) >= 10);
}


@immutable
class GuardStatus {
  const GuardStatus({
    this.isAccessibilityServiceEnabled = false,
    this.hasUsageStatsPermission = false,
    this.hasNotificationPermission = false,
    this.isIgnoringBatteryOptimizations = false,
    this.isServiceRunning = false,
    this.activePenaltyLevel = 0,
    this.strikesToday = 0,
    this.emergencyUnlocksRemaining = 1,
    this.isPaused = false,
    this.pausedUntilMs = 0,
  });

  factory GuardStatus.fromMap(Map<dynamic, dynamic> map) {
    return GuardStatus(
      isAccessibilityServiceEnabled:
          (map['isAccessibilityServiceEnabled'] as bool?) ?? false,
      hasUsageStatsPermission:
          (map['hasUsageStatsPermission'] as bool?) ?? false,
      hasNotificationPermission:
          (map['hasNotificationPermission'] as bool?) ?? false,
      isIgnoringBatteryOptimizations:
          (map['isIgnoringBatteryOptimizations'] as bool?) ?? false,
      isServiceRunning: (map['isServiceRunning'] as bool?) ?? false,
      activePenaltyLevel: (map['activePenaltyLevel'] as num?)?.toInt() ?? 0,
      strikesToday: (map['strikesToday'] as num?)?.toInt() ?? 0,
      emergencyUnlocksRemaining:
          (map['emergencyUnlocksRemaining'] as num?)?.toInt() ?? 1,
      isPaused: (map['isPaused'] as bool?) ?? false,
      pausedUntilMs: (map['pausedUntilMs'] as num?)?.toInt() ?? 0,
    );
  }

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

  bool get isFullyProtected =>
      isAccessibilityServiceEnabled &&
      hasUsageStatsPermission &&
      hasNotificationPermission;
}

@immutable
class SessionRecord {
  const SessionRecord({
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
    this.synced = false,
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

@immutable
class DailyStatsRecord {
  const DailyStatsRecord({
    required this.dateIso,
    required this.feedSeconds,
    required this.swipeCount,
    required this.lockCount,
    required this.strikeCount,
    this.synced = false,
  });

  final String dateIso;
  final int feedSeconds;
  final int swipeCount;
  final int lockCount;
  final int strikeCount;
  final bool synced;
}

@immutable
class PenaltyEventRecord {
  const PenaltyEventRecord({
    required this.id,
    required this.ts,
    required this.appId,
    required this.level,
    required this.reason,
    required this.budgetFraction,
    required this.metaJson,
    this.synced = false,
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

@immutable
class PendingSyncItem {
  const PendingSyncItem({
    required this.id,
    required this.type,
    required this.payloadJson,
  });

  final String id;
  final String type;
  final String payloadJson;
}
