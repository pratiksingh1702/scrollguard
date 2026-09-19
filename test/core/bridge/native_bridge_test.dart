import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';

void main() {
  group('FakeNativeBridge Tests', () {
    late FakeNativeBridge bridge;

    setUp(() {
      bridge = FakeNativeBridge();
    });

    tearDown(() {
      bridge.dispose();
    });

    test('getStatus returns initial default values', () async {
      final status = await bridge.getStatus();
      expect(status.isAccessibilityServiceEnabled, isTrue);
      expect(status.hasUsageStatsPermission, isTrue);
      expect(status.isFullyProtected, isTrue);
      expect(status.strikesToday, equals(0));
    });

    test('applyConfig updates bridge config immediately', () async {
      const newConfig = GuardConfig(
        dailyBudgetSeconds: 900,
        continuousNudgeMinutes: 5,
      );

      await bridge.applyConfig(newConfig);
      expect(bridge.currentConfig.dailyBudgetSeconds, equals(900));
      expect(bridge.currentConfig.continuousNudgeMinutes, equals(5));
    });

    test('requestEmergencyUnlock validates minimum length', () async {
      // Short reason fails
      final shortOk = await bridge.requestEmergencyUnlock('urgent');
      expect(shortOk, isFalse);

      // Valid reason succeeds and increments strikes
      final validOk = await bridge.requestEmergencyUnlock(
        'Need urgent navigation to hospital',
      );
      expect(validOk, isTrue);

      final status = await bridge.getStatus();
      expect(status.strikesToday, equals(1));
      expect(status.emergencyUnlocksRemaining, equals(0));

      // Attempting another unlock when remaining is 0 fails
      final secondOk = await bridge.requestEmergencyUnlock(
        'Another critical situation',
      );
      expect(secondOk, isFalse);
    });

    test('watchLiveState emits scripted live stream updates', () async {
      final emitted = <LiveState>[];
      final subscription = bridge.watchLiveState().listen(emitted.add);

      const state1 = LiveState(
        inFeed: true,
        appId: 'youtube_shorts',
        sessionSeconds: 12,
        swipeCount: 3,
      );
      const state2 = LiveState(
        inFeed: true,
        appId: 'youtube_shorts',
        sessionSeconds: 25,
        swipeCount: 7,
      );

      bridge
        ..emitLiveState(state1)
        ..emitLiveState(state2);

      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, equals(2));
      expect(emitted[0].sessionSeconds, equals(12));
      expect(emitted[1].swipeCount, equals(7));

      await subscription.cancel();
    });

    test('ProviderContainer swapping with fake works cleanly', () async {
      final container = ProviderContainer(
        overrides: [
          nativeBridgeProvider.overrideWithValue(bridge),
        ],
      );

      final resolvedBridge = container.read(nativeBridgeProvider);
      expect(resolvedBridge, isA<FakeNativeBridge>());

      final status = await resolvedBridge.getStatus();
      expect(status.isServiceRunning, isTrue);

      container.dispose();
    });
  });
}
