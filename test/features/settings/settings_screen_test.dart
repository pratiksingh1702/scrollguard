import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/auth/auth_models.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';
import 'package:scrollguard/features/settings/settings_screen.dart';

void main() {
  Widget createTestWidget({
    GuardStatus status = const GuardStatus(
      isAccessibilityServiceEnabled: true,
      hasUsageStatsPermission: true,
      hasNotificationPermission: true,
      isIgnoringBatteryOptimizations: true,
      isServiceRunning: true,
    ),
    GuardConfig config = const GuardConfig(
      guardedApps: ['com.google.android.youtube', 'com.instagram.android'],
    ),
    List<SessionRecord> sessions = const [],
    AuthRepository? authRepo,
  }) {
    return ProviderScope(
      overrides: [
        guardStatusProvider.overrideWith((ref) => Stream.value(status)),
        guardConfigProvider.overrideWith(
          () => _FakeConfigNotifier(config),
        ),
        recentSessionsProvider.overrideWith((ref) async => sessions),
        authRepositoryProvider.overrideWithValue(
          authRepo ??
              FakeAuthRepository(
                initialUser: const UserAccount(
                  id: 'usr-1',
                  email: 'test@scrollguard.app',
                ),
              ),
        ),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen renders healthy engine status, rules, and telemetry',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Settings & Diagnostics'), findsOneWidget);
    expect(find.text('Engine & Service Status'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    expect(find.text('Detector Rules Diagnostics'), findsOneWidget);
    expect(find.text('Rules v1 (Bundled)'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('Instagram Reels'), findsOneWidget);

    expect(find.text('Anti-Tamper & Integrity Telemetry'), findsOneWidget);
    expect(find.text('Rules Stale Flag'), findsOneWidget);
    expect(find.text('UsageStats Divergence'), findsOneWidget);

    expect(find.text('Zero Screen-Reading Mandate'), findsOneWidget);
  });

  testWidgets('SettingsScreen indicates DEGRADED status when accessibility is off',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        status: const GuardStatus(
          hasUsageStatsPermission: true,
          hasNotificationPermission: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEGRADED'), findsOneWidget);
    expect(find.text('Repair Missing Permissions'), findsOneWidget);
  });

  testWidgets('Export Diagnostics Log opens modal with JSON preview',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Export Diagnostics Log'));
    await tester.tap(find.text('Export Diagnostics Log'));
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics Log'), findsOneWidget);
    expect(find.text('Copy to Clipboard'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics Log'), findsNothing);
  });

  testWidgets('Clear Local Database shows confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Clear Local Database'));
    await tester.tap(find.text('Clear Local Database'));
    await tester.pumpAndSettle();

    expect(find.text('Clear All Local Data?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear Data'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Clear All Local Data?'), findsNothing);
  });

  testWidgets('Export Account Data (Cloud) opens modal with user records preview',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Export Account Data (Cloud)'));
    await tester.tap(find.text('Export Account Data (Cloud)'));
    await tester.pumpAndSettle();

    expect(find.text('Exported Account Data'), findsOneWidget);
    expect(find.text('Copy to Clipboard'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Exported Account Data'), findsNothing);
  });

  testWidgets('Delete Account shows confirmation and triggers deletion',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeRepo = FakeAuthRepository(
      initialUser: const UserAccount(
        id: 'usr-1',
        email: 'delete_me@scrollguard.app',
      ),
    );

    await tester.pumpWidget(createTestWidget(authRepo: fakeRepo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete Account & Cloud Data'));
    await tester.tap(find.text('Delete Account & Cloud Data'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account & Cloud Data?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete Permanently'), findsOneWidget);

    await tester.tap(find.text('Delete Permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account & Cloud Data?'), findsNothing);
    expect(find.text('Account deleted successfully.'), findsOneWidget);
    expect(fakeRepo.currentUser, isNull);
  });
}

class _FakeConfigNotifier extends AsyncNotifier<GuardConfig>
    implements GuardConfigNotifier {
  _FakeConfigNotifier(this._config);

  final GuardConfig _config;

  @override
  Future<GuardConfig> build() async => _config;

  @override
  Future<void> updateConfig(GuardConfig newConfig) async {}
}
