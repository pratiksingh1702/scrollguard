import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/repositories/guard_config_repository.dart';
import 'package:scrollguard/features/rules/rules_screen.dart';

void main() {
  late FakeNativeBridge fakeBridge;

  setUp(() {
    fakeBridge = FakeNativeBridge(
      initialConfig: const GuardConfig(
        guardedApps: [
          'com.google.android.youtube',
          'com.instagram.android',
        ],
      ),
    );
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        nativeBridgeProvider.overrideWithValue(fakeBridge),
        guardConfigRepositoryProvider.overrideWithValue(
          BridgeGuardConfigRepository(fakeBridge, fakeBridge.currentConfig),
        ),
      ],
      child: const MaterialApp(
        home: RulesScreen(),
      ),
    );
  }

  testWidgets('RulesScreen renders loaded config and controls', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify Title and Guarded Platforms Card
    expect(find.text('Rules & Budgets'), findsOneWidget);
    expect(find.text('Guarded Platforms'), findsOneWidget);
    expect(find.text('2 active'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('Instagram Reels'), findsOneWidget);

    // Verify Daily budget card
    expect(find.text('Daily Budget'), findsOneWidget);
    expect(find.text('30 min/day'), findsOneWidget);

    // Verify Ladder thresholds card
    expect(find.text('Penalty Ladder Thresholds'), findsOneWidget);
    expect(find.text('50% budget'), findsOneWidget);
    expect(find.text('80% budget'), findsOneWidget);
    expect(find.text('100% budget'), findsOneWidget);

    // Verify Continuous Limits Card
    expect(find.text('Continuous Doomscroll Limits'), findsOneWidget);
    expect(find.text('10 min continuous'), findsOneWidget);
    expect(find.text('20 min continuous'), findsOneWidget);

    // Verify Save Button is enabled
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('rules_save_button')),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('Toggling an app checkbox updates active count', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('2 active'), findsOneWidget);

    // Tap TikTok checkbox to enable it
    await tester.tap(find.text('TikTok'));
    await tester.pumpAndSettle();

    expect(find.text('3 active'), findsOneWidget);
  });

  testWidgets('Selecting a preset budget updates budget display', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('30 min/day'), findsOneWidget);

    // Tap 60m chip
    await tester.ensureVisible(find.text('60m'));
    await tester.tap(find.text('60m'));
    await tester.pumpAndSettle();

    expect(find.text('60 min/day'), findsOneWidget);
  });

  testWidgets('Saving applies config to bridge', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Change budget to 45m
    await tester.ensureVisible(find.text('45m'));
    await tester.tap(find.text('45m'));
    await tester.pumpAndSettle();

    // Tap Save button
    await tester.tap(find.byKey(const Key('rules_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Rules applied successfully.'), findsOneWidget);
    expect(fakeBridge.appliedConfig?.dailyBudgetSeconds, 45 * 60);
  });

  testWidgets('Reset button restores default config', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap 90m chip
    await tester.ensureVisible(find.text('90m'));
    await tester.tap(find.text('90m'));
    await tester.pumpAndSettle();
    expect(find.text('90 min/day'), findsOneWidget);

    // Tap Reset
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Reset to default values.'), findsOneWidget);
    expect(find.text('30 min/day'), findsOneWidget); // Default is 30m
  });

  testWidgets('Disabling all apps triggers validation error and disables save button',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Initially 2 active
    expect(find.text('2 active'), findsOneWidget);

    // Uncheck YouTube
    await tester.tap(find.text('YouTube Shorts'));
    await tester.pumpAndSettle();

    // Uncheck Instagram
    await tester.tap(find.text('Instagram Reels'));
    await tester.pumpAndSettle();

    expect(find.text('0 active'), findsOneWidget);
    expect(find.text('Select at least one app to guard.'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('rules_save_button')),
    );
    expect(saveButton.onPressed, isNull);
  });
}
