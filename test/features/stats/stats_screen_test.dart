import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';
import 'package:scrollguard/features/stats/stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeBridge fakeBridge;

  final sampleRecords = <DailyStatsRecord>[
    const DailyStatsRecord(
      dateIso: '2026-09-14',
      feedSeconds: 600, // 10 min
      swipeCount: 40,
      lockCount: 0,
      strikeCount: 0,
    ),
    const DailyStatsRecord(
      dateIso: '2026-09-15',
      feedSeconds: 1200, // 20 min
      swipeCount: 85,
      lockCount: 1,
      strikeCount: 0,
    ),
    const DailyStatsRecord(
      dateIso: '2026-09-16',
      feedSeconds: 2400, // 40 min (exceeded 30 min budget)
      swipeCount: 160,
      lockCount: 2,
      strikeCount: 1,
    ),
  ];

  final sampleSessions = <SessionRecord>[
    const SessionRecord(
      id: 'sess-1',
      appId: 'com.google.android.youtube',
      startTs: 1000,
      endTs: 2000,
      feedSeconds: 1000,
      swipeCount: 65,
      avgDwellMs: 15000,
      minDwellMs: 3000,
      peakSpm: 12,
      scoreMax: 5,
      levelReached: 1,
    ),
    const SessionRecord(
      id: 'sess-2',
      appId: 'com.instagram.android',
      startTs: 3000,
      endTs: 4000,
      feedSeconds: 800,
      swipeCount: 60,
      avgDwellMs: 13000,
      minDwellMs: 2500,
      peakSpm: 10,
      scoreMax: 4,
      levelReached: 0,
    ),
  ];

  setUp(() {
    fakeBridge = FakeNativeBridge();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        nativeBridgeProvider.overrideWithValue(fakeBridge),
        weeklyStatsProvider.overrideWith((ref) => sampleRecords),
        monthlyStatsProvider.overrideWith((ref) => sampleRecords),
        sessionsProvider.overrideWith((ref, range) => sampleSessions),
      ],
      child: const MaterialApp(
        home: StatsScreen(),
      ),
    );
  }

  testWidgets('StatsScreen renders chart, summary tiles, and per-app breakdown',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Trends & Analytics'), findsOneWidget);
    expect(find.text('Past 7 Days'), findsOneWidget);
    expect(find.text('Past 30 Days'), findsOneWidget);

    // Feed time legend & chart
    expect(find.text('Feed Time (Minutes)'), findsOneWidget);
    expect(find.text('Within Budget'), findsOneWidget);
    expect(find.text('Exceeded'), findsOneWidget);

    // Summary tiles
    expect(find.text('Daily Average'), findsOneWidget);
    expect(find.text('23 min'), findsOneWidget); // (600 + 1200 + 2400)/3/60 = 23.33 min
    expect(find.text('Total Swipes'), findsOneWidget);
    expect(find.text('285'), findsOneWidget); // 40 + 85 + 160
    expect(find.text('Best Day'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('Peak Day'), findsOneWidget);
    expect(find.text('40 min'), findsOneWidget);

    // Per-App Breakdown
    expect(find.text('Per-App Breakdown'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('Instagram Reels'), findsOneWidget);
  });

  testWidgets('StatsScreen can toggle to 30 days period', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final monthlyButton = find.text('Past 30 Days');
    await tester.tap(monthlyButton);
    await tester.pumpAndSettle();

    expect(find.text('Feed Time (Minutes)'), findsOneWidget);
  });
}
