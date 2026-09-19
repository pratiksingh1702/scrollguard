import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/app/view/app.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';

void main() {
  testWidgets('App smoke test renders onboarding on initial launch',
      (tester) async {
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
}
