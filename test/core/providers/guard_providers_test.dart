import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

void main() {
  group('Guard Providers Baseline Tests', () {
    late FakeNativeBridge fakeBridge;
    late ProviderContainer container;

    setUp(() {
      fakeBridge = FakeNativeBridge();
      container = ProviderContainer(
        overrides: [
          nativeBridgeProvider.overrideWithValue(fakeBridge),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeBridge.dispose();
    });

    test('guardStatusProvider receives emitted updates from bridge', () async {
      final listener = container.listen(
        guardStatusProvider,
        (previous, next) {},
      );

      fakeBridge.emitStatus(
        const GuardStatus(
          isAccessibilityServiceEnabled: true,
          hasUsageStatsPermission: true,
          isServiceRunning: true,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(guardStatusProvider);
      expect(state.hasValue, isTrue);
      expect(state.value?.isAccessibilityServiceEnabled, isTrue);
      expect(state.value?.hasNotificationPermission, isFalse);

      listener.close();
    });

    test('liveStateProvider receives emitted live doomscroll state', () async {
      final listener = container.listen(
        liveStateProvider,
        (previous, next) {},
      );

      fakeBridge.emitLiveState(
        const LiveState(
          inFeed: true,
          appId: 'youtube_shorts',
          sessionSeconds: 30,
          swipeCount: 8,
          intensity: 65,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(liveStateProvider);
      expect(state.hasValue, isTrue);
      expect(state.value?.inFeed, isTrue);
      expect(state.value?.intensity, equals(65));

      listener.close();
    });

    test('guardConfigProvider reads and mutates config', () async {
      final initial = await container.read(guardConfigProvider.future);
      expect(initial.dailyBudgetSeconds, equals(1800));

      const updatedConfig = GuardConfig(
        dailyBudgetSeconds: 2400,
        continuousNudgeMinutes: 8,
      );

      await container
          .read(guardConfigProvider.notifier)
          .updateConfig(updatedConfig);

      final current = await container.read(guardConfigProvider.future);
      expect(current.dailyBudgetSeconds, equals(2400));
      expect(current.continuousNudgeMinutes, equals(8));
      expect(fakeBridge.currentConfig.dailyBudgetSeconds, equals(2400));
    });

    test('sessionsProvider fetches sessions list through family', () async {
      fakeBridge.sessions.add(
        const SessionRecord(
          id: 'sess-abc',
          appId: 'instagram_reels',
          startTs: 1000,
          endTs: 1060,
          feedSeconds: 60,
          swipeCount: 15,
          avgDwellMs: 4000,
          minDwellMs: 2000,
          peakSpm: 15,
          scoreMax: 70,
          levelReached: 1,
        ),
      );

      const range = SessionQueryRange(fromEpochMs: 500, toEpochMs: 1500);
      final list = await container.read(sessionsProvider(range).future);

      expect(list.length, equals(1));
      expect(list.first.appId, equals('instagram_reels'));
    });
  });
}
