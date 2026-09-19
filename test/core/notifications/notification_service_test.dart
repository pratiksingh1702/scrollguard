import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/notifications/notification_service.dart';

void main() {
  group('FakeNotificationService', () {
    late FakeNotificationService service;

    setUp(() {
      service = FakeNotificationService();
    });

    test('showGuardDisabledAlert dispatches alert with /permissions payload',
        () async {
      await service.showGuardDisabledAlert();

      expect(service.sent.length, 1);
      final notif = service.sent.first;
      expect(notif.id, 1001);
      expect(notif.title, contains('ScrollGuard Protection Is Off'));
      expect(notif.payload, '/permissions');
    });

    test('showDailySummary dispatches summary with /stats payload', () async {
      await service.showDailySummary(
        feedMinutes: 20,
        budgetMinutes: 30,
        strikes: 0,
      );

      expect(service.sent.length, 1);
      final notif = service.sent.first;
      expect(notif.id, 1002);
      expect(notif.title, 'Daily Focus Summary');
      expect(notif.payload, '/stats');
    });

    test('showStreakMilestone dispatches milestone with /dashboard payload',
        () async {
      await service.showStreakMilestone(streakDays: 7);

      expect(service.sent.length, 1);
      final notif = service.sent.first;
      expect(notif.id, 1003);
      expect(notif.title, contains('7-Day Focus Streak'));
      expect(notif.payload, '/dashboard');
    });

    test('showHighUsageAlert dispatches doomscrolling alert with swipe count',
        () async {
      await service.showHighUsageAlert(
        appName: 'YouTube Shorts',
        sessionMinutes: 5,
        swipeCount: 42,
        isDoomscrolling: true,
      );

      expect(service.sent.length, 1);
      final notif = service.sent.first;
      expect(notif.id, 1004);
      expect(notif.title, contains('Doomscrolling Detected'));
      expect(notif.body, contains('42 swipes'));
      expect(notif.body, contains('5m'));
      expect(notif.body, contains('YouTube Shorts'));
      expect(notif.payload, '/dashboard');
    });

    test('showHighUsageAlert dispatches watching alert with swipe count',
        () async {
      await service.showHighUsageAlert(
        appName: 'Instagram Reels',
        sessionMinutes: 10,
        swipeCount: 8,
        isDoomscrolling: false,
      );

      expect(service.sent.length, 1);
      final notif = service.sent.first;
      expect(notif.id, 1004);
      expect(notif.title, contains('Extended Watching'));
      expect(notif.body, contains('8 swipes'));
      expect(notif.body, contains('10m'));
      expect(notif.body, contains('Instagram Reels'));
      expect(notif.payload, '/dashboard');
    });

    test('simulateTap triggers onSelectNotification callback with deep link',
        () async {
      String? receivedPayload;
      await service.initialize(
        onSelectNotification: (payload) {
          receivedPayload = payload;
        },
      );

      service.simulateTap('/stats');
      expect(receivedPayload, '/stats');

      service.simulateTap('/permissions');
      expect(receivedPayload, '/permissions');
    });

    test('cancelAll clears notifications', () async {
      await service.showGuardDisabledAlert();
      expect(service.sent.length, 1);

      await service.cancelAll();
      expect(service.sent, isEmpty);
    });
  });
}
