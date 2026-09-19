import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';
import 'package:scrollguard/features/sessions/sessions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeBridge fakeBridge;

  final now = DateTime.now();

  final sampleSessions = <SessionRecord>[
    SessionRecord(
      id: 'sess-1',
      appId: 'com.google.android.youtube',
      startTs: now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
      endTs: now.subtract(const Duration(minutes: 12)).millisecondsSinceEpoch,
      feedSeconds: 480, // 8 min
      swipeCount: 35,
      avgDwellMs: 13700,
      minDwellMs: 3200,
      peakSpm: 8,
      scoreMax: 4,
      levelReached: 1,
    ),
    SessionRecord(
      id: 'sess-2',
      appId: 'com.instagram.android',
      startTs: now.subtract(const Duration(minutes: 60)).millisecondsSinceEpoch,
      endTs: now.subtract(const Duration(minutes: 55)).millisecondsSinceEpoch,
      feedSeconds: 300, // 5 min
      swipeCount: 22,
      avgDwellMs: 13600,
      minDwellMs: 4000,
      peakSpm: 6,
      scoreMax: 2,
      levelReached: 0,
    ),
  ];

  setUp(() {
    fakeBridge = FakeNativeBridge();
  });

  Widget createTestWidget({List<SessionRecord> sessions = const []}) {
    return ProviderScope(
      overrides: [
        nativeBridgeProvider.overrideWithValue(fakeBridge),
        recentSessionsProvider.overrideWith((ref) => sessions),
      ],
      child: const MaterialApp(
        home: SessionsScreen(),
      ),
    );
  }

  testWidgets('SessionsScreen renders empty state when no sessions exist',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(sessions: []));
    await tester.pumpAndSettle();

    expect(find.text('Session History'), findsOneWidget);
    expect(find.text('No sessions recorded'), findsOneWidget);
    expect(
      find.text('Short-video feeds you visit will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'SessionsScreen renders sessions grouped by day and opens detail sheet on tap',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(sessions: sampleSessions));
    await tester.pumpAndSettle();

    expect(find.text('Session History'), findsOneWidget);
    expect(find.text('All Apps'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsWidgets);
    expect(find.text('Instagram Reels'), findsWidgets);

    // Verify session details in the tile
    expect(find.text('8m 0s'), findsOneWidget);
    expect(find.text('35 swipes'), findsOneWidget);
    expect(find.text('L1'), findsOneWidget);

    // Tap on YouTube Shorts session to open modal sheet
    await tester.tap(find.text('8m 0s'));
    await tester.pumpAndSettle();

    // Modal sheet should be open
    expect(find.text('Feed Duration'), findsOneWidget);
    expect(find.text('Average Dwell per Video'), findsOneWidget);
    expect(find.text('Peak Velocity'), findsOneWidget);
    expect(find.text('13.7 s'), findsOneWidget);
    expect(find.text('8.0 SPM'), findsOneWidget);
    expect(
      find.text(
        '100% Privacy Protected: ScrollGuard only recorded structural '
        'timing signals. No video titles, creators, or content were accessed.',
      ),
      findsOneWidget,
    );

    // Close sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Feed Duration'), findsNothing);
  });

  testWidgets('Filter chips filter sessions list by package', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(sessions: sampleSessions));
    await tester.pumpAndSettle();

    // Initially both sessions are visible
    expect(find.text('8m 0s'), findsOneWidget);
    expect(find.text('5m 0s'), findsOneWidget);

    // Filter by Instagram Reels
    final instaFilter = find.widgetWithText(FilterChip, 'Instagram Reels');
    expect(instaFilter, findsOneWidget);
    await tester.tap(instaFilter);
    await tester.pumpAndSettle();

    // Only Instagram session remains visible
    expect(find.text('5m 0s'), findsOneWidget);
    expect(find.text('8m 0s'), findsNothing);
  });
}
