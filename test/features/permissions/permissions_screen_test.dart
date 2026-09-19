import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/features/permissions/permissions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeBridge fakeBridge;

  setUp(() {
    fakeBridge = FakeNativeBridge(
      initialStatus: const GuardStatus(),
    );
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        nativeBridgeProvider.overrideWithValue(fakeBridge),
      ],
      child: const MaterialApp(
        home: PermissionsScreen(),
      ),
    );
  }

  testWidgets('PermissionsScreen renders all permission items and handles clicks',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Enable Protection'), findsOneWidget);
    expect(find.text('Accessibility Service'), findsOneWidget);
    expect(find.text('Usage Access'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Battery Optimization'), findsOneWidget);

    // Tapping 'Grant' on Accessibility tile (first Grant button)
    final grantButtons = find.text('Grant');
    expect(grantButtons, findsNWidgets(4));
    await tester.tap(grantButtons.at(0));
    await tester.pumpAndSettle();

    expect(fakeBridge.accessibilitySettingsOpened, isTrue);

    // Tapping 'Grant' on Usage Access tile (second Grant button)
    await tester.tap(grantButtons.at(1));
    await tester.pumpAndSettle();

    expect(fakeBridge.usageSettingsOpened, isTrue);
  });

  testWidgets('PermissionsScreen loads and opens OEM guides bottom sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final oemButton = find.text('OEM Battery Survival Guide');
    expect(oemButton, findsOneWidget);
    await tester.tap(oemButton);
    await tester.pumpAndSettle();

    // Bottom sheet should open with OEM Background Survival Guide
    expect(find.text('OEM Background Survival Guide'), findsOneWidget);
    expect(find.text('Xiaomi / MIUI / HyperOS'), findsOneWidget);
    expect(find.text('Samsung'), findsOneWidget);
  });
}
