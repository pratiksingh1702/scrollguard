import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/features/onboarding/onboarding_screen.dart';

void main() {
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
        home: OnboardingScreen(),
      ),
    );
  }

  testWidgets('OnboardingScreen progresses through all 5 steps and completes',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Step 0: Pitch
    expect(find.text('Reclaim Your Focus'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Step 1: Apps selection
    expect(find.text('Choose Guarded Apps'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('Instagram Reels'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2: Budget
    expect(find.text('Set Your Daily Budget'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3: Prominent Disclosure (Play Compliance)
    expect(
      find.text('How ScrollGuard uses Accessibility Services'),
      findsOneWidget,
    );
    expect(find.text('What we inspect:'), findsOneWidget);
    expect(find.text('What we NEVER inspect or collect:'), findsOneWidget);

    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();

    // Step 4: Finish
    expect(find.text('Ready to Enable Guard'), findsOneWidget);
    await tester.tap(find.text('Grant Permissions'));
    await tester.pumpAndSettle();

    // Verify config was applied to bridge
    expect(fakeBridge.configApplied, isTrue);
    expect(
      fakeBridge.appliedConfig?.guardedApps,
      contains('com.google.android.youtube'),
    );
  });

  testWidgets('Decline on prominent disclosure screen shows explanation dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Navigate to Step 3:
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('How ScrollGuard uses Accessibility Services'),
      findsOneWidget,
    );

    // Tap Decline
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    // Dialog appears explaining requirement
    expect(find.text('Consent Required for Protection'), findsOneWidget);
    expect(find.text('I Understand'), findsOneWidget);

    await tester.tap(find.text('I Understand'));
    await tester.pumpAndSettle();

    // Safely navigates back to Step 0
    expect(find.text('Reclaim Your Focus'), findsOneWidget);
  });
}
