import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/app/router/app_router.dart';
import 'package:scrollguard/app/view/app.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';

void main() {
  group('Router Gating Tests', () {
    testWidgets('Redirects to /onboarding when not onboarded', (tester) async {
      final fakeBridge = FakeNativeBridge(
        initialStatus: const GuardStatus(
          isAccessibilityServiceEnabled: true,
          hasUsageStatsPermission: true,
          hasNotificationPermission: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(fakeBridge),
            onboardingCompletedProvider.overrideWith((ref) => false),
          ],
          child: const ScrollGuardApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reclaim Your Focus'), findsOneWidget);
    });

    testWidgets(
        'Redirects to /permissions when onboarded but missing accessibility',
        (tester) async {
      final fakeBridge = FakeNativeBridge(
        initialStatus: const GuardStatus(
          hasUsageStatsPermission: true,
          hasNotificationPermission: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(fakeBridge),
            onboardingCompletedProvider.overrideWith((ref) => true),
          ],
          child: const ScrollGuardApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enable Protection'), findsOneWidget);
    });

    testWidgets(
        'Redirects to /dashboard when onboarded and permissions granted',
        (tester) async {
      final fakeBridge = FakeNativeBridge(
        initialStatus: const GuardStatus(
          isAccessibilityServiceEnabled: true,
          hasUsageStatsPermission: true,
          hasNotificationPermission: true,
          isServiceRunning: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(fakeBridge),
            onboardingCompletedProvider.overrideWith((ref) => true),
          ],
          child: const ScrollGuardApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Daily Feed Budget'),
        findsOneWidget,
      );
    });
  });
}
