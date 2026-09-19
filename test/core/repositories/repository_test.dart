import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/database/app_database.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/repositories/guard_config_repository.dart';
import 'package:scrollguard/core/repositories/penalty_repository.dart';
import 'package:scrollguard/core/repositories/session_repository.dart';
import 'package:scrollguard/core/repositories/stats_repository.dart';

void main() {
  group('Domain Models Tests', () {
    test('GuardConfig serialization and copyWith', () {
      const config = GuardConfig(
        dailyBudgetSeconds: 1200,
        nudgeThresholdFraction: 0.6,
      );

      final json = config.toJson();
      final restored = GuardConfig.fromJson(json);

      expect(restored.dailyBudgetSeconds, equals(1200));
      expect(restored.nudgeThresholdFraction, equals(0.6));

      final modified = restored.copyWith(dailyBudgetSeconds: 2400);
      expect(modified.dailyBudgetSeconds, equals(2400));
      expect(modified.nudgeThresholdFraction, equals(0.6));
    });

    test('LiveState and GuardStatus map parsing', () {
      final liveMap = {
        'appId': 'com.google.android.youtube',
        'inFeed': true,
        'sessionSeconds': 45,
        'swipeCount': 10,
        'todayFeedSeconds': 300,
        'dailyBudgetSeconds': 1800,
        'budgetFraction': 0.166,
        'intensity': 42,
        'activePenaltyLevel': 1,
        'strikesToday': 0,
        'emergencyUnlocksRemaining': 1,
        'isPaused': false,
        'pausedUntilMs': 0,
      };

      final liveState = LiveState.fromMap(liveMap);
      expect(liveState.appId, equals('com.google.android.youtube'));
      expect(liveState.inFeed, isTrue);
      expect(liveState.sessionSeconds, equals(45));
      expect(liveState.swipeCount, equals(10));
      expect(liveState.intensity, equals(42));
      expect(liveState.penaltyLevel, equals(1));

      final statusMap = {
        'isAccessibilityServiceEnabled': true,
        'hasUsageStatsPermission': true,
        'hasNotificationPermission': true,
        'isIgnoringBatteryOptimizations': true,
        'isServiceRunning': true,
        'activePenaltyLevel': 0,
        'strikesToday': 0,
        'emergencyUnlocksRemaining': 1,
        'isPaused': false,
        'pausedUntilMs': 0,
      };

      final status = GuardStatus.fromMap(statusMap);
      expect(status.isFullyProtected, isTrue);
    });
  });

  group('Repositories Tests', () {
    late FakeNativeBridge fakeBridge;
    late AppDatabase inMemoryDb;

    setUp(() {
      fakeBridge = FakeNativeBridge();
      inMemoryDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      fakeBridge.dispose();
      await inMemoryDb.close();
    });

    test('GuardConfigRepository saves and reflects in bridge', () async {
      final repo = BridgeGuardConfigRepository(fakeBridge);
      const newConfig = GuardConfig(dailyBudgetSeconds: 2000);

      await repo.saveConfig(newConfig);
      final retrieved = await repo.getConfig();

      expect(retrieved.dailyBudgetSeconds, equals(2000));
      expect(fakeBridge.currentConfig.dailyBudgetSeconds, equals(2000));
    });

    test('SessionRepository fetches sessions from bridge', () async {
      fakeBridge.sessions.add(
        const SessionRecord(
          id: 'sess-1',
          appId: 'youtube_shorts',
          startTs: 1000,
          endTs: 2000,
          feedSeconds: 30,
          swipeCount: 5,
          avgDwellMs: 6000,
          minDwellMs: 4000,
          peakSpm: 10,
          scoreMax: 50,
          levelReached: 0,
        ),
      );

      final repo = BridgeSessionRepository(fakeBridge);
      final list = await repo.getSessions(500, 2500);

      expect(list.length, equals(1));
      expect(list.first.id, equals('sess-1'));
    });

    test('StatsRepository caches to Drift and retrieves', () async {
      final repo = DriftStatsRepository(
        bridge: fakeBridge,
        database: inMemoryDb,
      );

      fakeBridge.dailyStats['2026-03-15'] = const DailyStatsRecord(
        dateIso: '2026-03-15',
        feedSeconds: 600,
        swipeCount: 40,
        lockCount: 1,
        strikeCount: 0,
      );

      final result = await repo.getDailyStats('2026-03-15');
      expect(result, isNotNull);
      expect(result!.feedSeconds, equals(600));

      final history = await repo.getHistoricalStats();
      expect(history.length, equals(1));
      expect(history.first.dateIso, equals('2026-03-15'));
    });

    test('PenaltyRepository caches penalties to Drift', () async {
      final repo = DriftPenaltyRepository(
        bridge: fakeBridge,
        database: inMemoryDb,
      );

      fakeBridge.penaltyEvents.add(
        const PenaltyEventRecord(
          id: 'pen-1',
          ts: 1773560000000,
          appId: 'youtube_shorts',
          level: 2,
          reason: 'Daily budget reached',
          budgetFraction: 1,
          metaJson: '{}',
        ),
      );

      final events = await repo.getPenaltyEvents(
        1773550000000,
        1773570000000,
      );
      expect(events.length, equals(1));
      expect(events.first.id, equals('pen-1'));
    });
  });
}
