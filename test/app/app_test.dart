import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/app/theme/app_theme.dart';
import 'package:scrollguard/app/view/app.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';

void main() {
  group('ScrollGuardApp', () {
    testWidgets('renders onboarding screen on initial start', (tester) async {
      final fakeBridge = FakeNativeBridge();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(fakeBridge),
          ],
          child: const ScrollGuardApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reclaim Your Focus'), findsOneWidget);
    });

    test('theme provides light and dark Material 3 variants', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.brightness, equals(Brightness.light));
      expect(dark.brightness, equals(Brightness.dark));
    });
  });
}
