import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/features/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeBridge fakeBridge;

  setUp(() {
    fakeBridge = FakeNativeBridge();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        nativeBridgeProvider.overrideWithValue(fakeBridge),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    );
  }

  testWidgets('DashboardScreen renders budget ring and idle live card by default',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('ScrollGuard'), findsOneWidget);
    expect(find.text('Guard Active & Protecting'), findsOneWidget);
    expect(find.text('Daily Feed Budget'), findsOneWidget);
    expect(find.text('0 / 30 min spent in short-video feeds'), findsOneWidget);
    expect(find.text('No Active Short-Video Feed'), findsOneWidget);
    expect(find.text('Quick Pause'), findsOneWidget);
    expect(find.text('Unlock (1)'), findsOneWidget);
    expect(find.text("Today's Activity"), findsOneWidget);
  });

  testWidgets('DashboardScreen switches to LIVE card when inFeed is active',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Emit live state
    fakeBridge.emitLiveState(
      const LiveState(
        inFeed: true,
        appId: 'com.google.android.youtube',
        sessionSeconds: 125,
        swipeCount: 14,
        intensity: 2,
        penaltyLevel: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE IN FEED'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('2m 5s'), findsOneWidget);
    expect(find.text('14'), findsWidgets); // swipes
    expect(find.text('High'), findsOneWidget); // intensity
    expect(find.text('L1'), findsOneWidget); // penalty level
  });

  testWidgets('Quick Pause dialog allows pausing for 10 minutes',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final pauseButton = find.text('Quick Pause');
    await tester.tap(pauseButton);
    await tester.pumpAndSettle();

    expect(find.text('Pause Protection'), findsOneWidget);
    final tenMinChip = find.text('10 min');
    expect(tenMinChip, findsOneWidget);
    await tester.tap(tenMinChip);
    await tester.pumpAndSettle();

    final confirmPause = find.widgetWithText(FilledButton, 'Pause Guard');
    await tester.tap(confirmPause);
    await tester.pumpAndSettle();

    final status = await fakeBridge.getStatus();
    expect(status.isPaused, isTrue);
  });

  testWidgets(
      'Emergency Unlock dialog enforces >= 10 chars reason and calls bridge',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final unlockButton = find.text('Unlock (1)');
    await tester.tap(unlockButton);
    await tester.pumpAndSettle();

    expect(find.text('Emergency Unlock'), findsOneWidget);

    final unlockNowButton = find.widgetWithText(FilledButton, 'Unlock Now');

    // Try with short reason (< 10 chars)
    final input = find.byType(TextField);
    await tester.enterText(input, 'short');
    await tester.tap(unlockNowButton);
    await tester.pumpAndSettle();

    // Reason error shown
    expect(find.text('Reason must be at least 10 characters'), findsOneWidget);

    // Enter valid reason >= 10 chars
    await tester.enterText(input, 'Need to review an educational tutorial');
    await tester.tap(unlockNowButton);
    await tester.pumpAndSettle();

    final status = await fakeBridge.getStatus();
    expect(status.emergencyUnlocksRemaining, equals(0));
    expect(status.strikesToday, equals(1));
  });

  testWidgets(
      'DashboardScreen shows disabled banner and tapping opens settings when disabled',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeBridge.emitStatus(
      const GuardStatus(),
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final disabledBanner = find.text('Guard Disabled (Tap to enable)');
    expect(disabledBanner, findsOneWidget);

    await tester.tap(disabledBanner);
    await tester.pumpAndSettle();

    expect(fakeBridge.accessibilitySettingsOpened, isTrue);
  });
}
