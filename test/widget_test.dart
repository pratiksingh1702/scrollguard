import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/app/view/app.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ScrollGuardApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ScrollGuard Home'), findsWidgets);
  });
}
