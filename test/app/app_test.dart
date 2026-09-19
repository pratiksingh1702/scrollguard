import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/app/theme/app_theme.dart';
import 'package:scrollguard/app/view/app.dart';

void main() {
  group('ScrollGuardApp', () {
    testWidgets('renders placeholder home and title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: ScrollGuardApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ScrollGuard Home'), findsWidgets);
      expect(
        find.text('Feed-level addiction guard & penalty enforcement'),
        findsOneWidget,
      );
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
