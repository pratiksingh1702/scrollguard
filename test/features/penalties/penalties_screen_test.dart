import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';
import 'package:scrollguard/features/penalties/penalties_screen.dart';

void main() {
  final nowMs = DateTime(2026, 9, 19, 14, 30).millisecondsSinceEpoch;

  final samplePenalties = [
    PenaltyEventRecord(
      id: 'penalty-1',
      ts: nowMs,
      appId: 'com.instagram.android',
      level: 1, // L1 Friction
      reason: 'BUDGET_REACHED: 80% limit',
      budgetFraction: 0.8,
      metaJson: '{}',
      synced: true,
    ),
    PenaltyEventRecord(
      id: 'penalty-2',
      ts: nowMs - 3600000, // 1 hour earlier
      appId: 'com.google.android.youtube',
      level: 0, // L0 Nudge
      reason: 'CONTINUOUS_LIMIT: 10m reached',
      budgetFraction: 0.5,
      metaJson: '{}',
    ),
  ];

  Widget createTestWidget({List<PenaltyEventRecord>? penalties}) {
    return ProviderScope(
      overrides: [
        recentPenaltiesProvider.overrideWith((ref) async => penalties ?? []),
      ],
      child: const MaterialApp(
        home: PenaltiesScreen(),
      ),
    );
  }

  testWidgets('PenaltiesScreen renders clean record when no penalties exist',
      (tester) async {
    await tester.pumpWidget(createTestWidget(penalties: []));
    await tester.pumpAndSettle();

    expect(find.text('Penalty History'), findsOneWidget);
    expect(find.text('Clean Record!'), findsOneWidget);
    expect(find.text('0 total'), findsOneWidget);
  });

  testWidgets('PenaltiesScreen renders summary header, badges, and cards',
      (tester) async {
    await tester.pumpWidget(createTestWidget(penalties: samplePenalties));
    await tester.pumpAndSettle();

    expect(find.text('Penalty History'), findsOneWidget);
    expect(find.text('Accountability Log'), findsOneWidget);
    expect(find.text('2 total'), findsOneWidget);

    // Verify stat pills
    expect(find.text('L0 Nudge'), findsWidgets);
    expect(find.text('L1 Friction'), findsWidgets);

    // Verify penalty cards
    expect(find.text('Instagram Reels'), findsWidgets);
    expect(find.text('YouTube Shorts'), findsWidgets);
    expect(find.text('Budget reached: 80% daily limit in Instagram Reels'), findsOneWidget);
    expect(find.text('Continuous doomscroll threshold reached in YouTube Shorts'), findsOneWidget);
    expect(find.text('80% budget'), findsOneWidget);
    expect(find.text('50% budget'), findsOneWidget);
  });

  testWidgets('Tapping tier filter chip filters penalties list', (tester) async {
    await tester.pumpWidget(createTestWidget(penalties: samplePenalties));
    await tester.pumpAndSettle();

    expect(
      find.text('Budget reached: 80% daily limit in Instagram Reels'),
      findsOneWidget,
    );
    expect(
      find.text('Continuous doomscroll threshold reached in YouTube Shorts'),
      findsOneWidget,
    );

    // Tap "L0 Nudge" filter chip
    await tester.tap(find.widgetWithText(FilterChip, 'L0 Nudge'));
    await tester.pumpAndSettle();

    // Now only YouTube Shorts (L0) should be visible in the cards
    expect(
      find.text('Budget reached: 80% daily limit in Instagram Reels'),
      findsNothing,
    );
    expect(
      find.text('Continuous doomscroll threshold reached in YouTube Shorts'),
      findsOneWidget,
    );
  });

  testWidgets('Tapping penalty card opens detail modal sheet', (tester) async {
    await tester.pumpWidget(createTestWidget(penalties: samplePenalties));
    await tester.pumpAndSettle();

    // Tap Instagram Reels penalty card
    await tester.tap(find.text('Budget reached: 80% daily limit in Instagram Reels'));
    await tester.pumpAndSettle();

    // Verify detail sheet is open
    expect(find.text('Friction Countdown Screen'), findsOneWidget);
    expect(find.text('Event ID'), findsOneWidget);
    expect(find.text('penalty-1'), findsOneWidget);
    expect(find.text('Synced to Cloud'), findsOneWidget);

    // Tap Close button
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('penalty-1'), findsNothing);
  });
}
