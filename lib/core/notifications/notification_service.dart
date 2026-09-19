import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract service defining app notification capabilities and alert dispatching.
abstract class NotificationService {
  /// Initializes notification plugin and background channels.
  Future<void> initialize({void Function(String? payload)? onSelectNotification});

  /// Displays an urgent notification warning the user that protection is disabled.
  Future<void> showGuardDisabledAlert();

  /// Displays daily doomscroll summary and budget adherence.
  Future<void> showDailySummary({
    required int feedMinutes,
    required int budgetMinutes,
    required int strikes,
  });

  /// Displays celebratory milestone notification for consistent focus streaks.
  Future<void> showStreakMilestone({required int streakDays});

  /// Displays a high usage alert differentiating between doomscrolling and watching with swipe counts.
  Future<void> showHighUsageAlert({
    required String appName,
    required int sessionMinutes,
    required int swipeCount,
    required bool isDoomscrolling,
  });

  /// Cancels all scheduled or active notifications.
  Future<void> cancelAll();
}

/// Notification channels used by ScrollGuard.
class NotificationChannels {
  static const alertsId = 'scrollguard_alerts';
  static const alertsName = 'Security & Guard Alerts';
  static const alertsDesc = 'Urgent notifications when protection or services are disabled.';

  static const highUsageId = 'scrollguard_high_usage';
  static const highUsageName = 'High Usage & Doomscroll Alerts';
  static const highUsageDesc = 'Alerts for high usage, differentiating doomscrolling vs watching with swipe counts.';

  static const dailySummaryId = 'scrollguard_daily_summary';
  static const dailySummaryName = 'Daily Focus Summaries';
  static const dailySummaryDesc = 'Evening breakdown of scroll budget and streaks.';

  static const milestonesId = 'scrollguard_milestones';
  static const milestonesName = 'Milestones & Streaks';
  static const milestonesDesc = 'Celebrations when reaching focus streaks.';
}


/// Implementation of [NotificationService] using [FlutterLocalNotificationsPlugin].
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String? payload)? _onSelectNotification;
  bool _isInitialized = false;

  @override
  Future<void> initialize({void Function(String? payload)? onSelectNotification}) async {
    if (_isInitialized) return;
    _onSelectNotification = onSelectNotification;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          _onSelectNotification?.call(response.payload);
        },
      );
      _isInitialized = true;
    } on Object {
      // Ignored in environments where platform channel is not registered (e.g. unit tests)
    }
  }

  @override
  Future<void> showGuardDisabledAlert() async {
    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.alertsId,
      NotificationChannels.alertsName,
      channelDescription: NotificationChannels.alertsDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      ticker: 'ScrollGuard Protection Off',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1001,
      '⚠️ ScrollGuard Protection Is Off',
      'Accessibility service was disabled. Tap to restore protection and guard your focus.',
      details,
      payload: '/permissions',
    );
  }

  @override
  Future<void> showDailySummary({
    required int feedMinutes,
    required int budgetMinutes,
    required int strikes,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.dailySummaryId,
      NotificationChannels.dailySummaryName,
      channelDescription: NotificationChannels.dailySummaryDesc,
      category: AndroidNotificationCategory.status,
    );

    const details = NotificationDetails(android: androidDetails);

    final statusWord = feedMinutes <= budgetMinutes ? 'Success' : 'Exceeded';
    final strikesWord = strikes == 1 ? '1 strike' : '$strikes strikes';

    await _plugin.show(
      1002,
      'Daily Focus Summary: $statusWord',
      'You spent $feedMinutes of $budgetMinutes min watching feeds today ($strikesWord).',
      details,
      payload: '/stats',
    );
  }

  @override
  Future<void> showStreakMilestone({required int streakDays}) async {
    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.milestonesId,
      NotificationChannels.milestonesName,
      channelDescription: NotificationChannels.milestonesDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.event,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1003,
      '🔥 $streakDays-Day Focus Streak!',
      'Incredible discipline! You stayed within your limits for $streakDays straight days.',
      details,
      payload: '/dashboard',
    );
  }

  @override
  Future<void> showHighUsageAlert({
    required String appName,
    required int sessionMinutes,
    required int swipeCount,
    required bool isDoomscrolling,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.highUsageId,
      NotificationChannels.highUsageName,
      channelDescription: NotificationChannels.highUsageDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );

    const details = NotificationDetails(android: androidDetails);

    final title = isDoomscrolling
        ? '⚠️ High Usage: Doomscrolling Detected'
        : '⏱️ High Usage: Extended Watching';

    final body = isDoomscrolling
        ? "You've swiped $swipeCount times in ${sessionMinutes}m in $appName ($swipeCount swipes). Rapid scrolling detected—take a mindful pause!"
        : "You've been watching $appName for ${sessionMinutes}m ($swipeCount swipes). Time to take an eye break!";


    await _plugin.show(
      1004,
      title,
      body,
      details,
      payload: '/dashboard',
    );
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

/// Fake implementation of [NotificationService] for unit and widget testing.
class FakeNotificationService implements NotificationService {
  final List<({int id, String? title, String? body, String? payload})> sent = [];
  void Function(String? payload)? onSelectNotification;

  @override
  Future<void> initialize({void Function(String? payload)? onSelectNotification}) async {
    this.onSelectNotification = onSelectNotification;
  }

  @override
  Future<void> showGuardDisabledAlert() async {
    sent.add((
      id: 1001,
      title: '⚠️ ScrollGuard Protection Is Off',
      body: 'Accessibility service was disabled. Tap to restore protection and guard your focus.',
      payload: '/permissions',
    ));
  }

  @override
  Future<void> showDailySummary({
    required int feedMinutes,
    required int budgetMinutes,
    required int strikes,
  }) async {
    sent.add((
      id: 1002,
      title: 'Daily Focus Summary',
      body: 'You spent $feedMinutes of $budgetMinutes min ($strikes strikes).',
      payload: '/stats',
    ));
  }

  @override
  Future<void> showStreakMilestone({required int streakDays}) async {
    sent.add((
      id: 1003,
      title: '🔥 $streakDays-Day Focus Streak!',
      body: 'Streak milestone reached: $streakDays days.',
      payload: '/dashboard',
    ));
  }

  @override
  Future<void> showHighUsageAlert({
    required String appName,
    required int sessionMinutes,
    required int swipeCount,
    required bool isDoomscrolling,
  }) async {
    final title = isDoomscrolling
        ? '⚠️ High Usage: Doomscrolling Detected'
        : '⏱️ High Usage: Extended Watching';

    final body = isDoomscrolling
        ? "You've swiped $swipeCount times in ${sessionMinutes}m in $appName ($swipeCount swipes). Rapid scrolling detected—take a mindful pause!"
        : "You've been watching $appName for ${sessionMinutes}m ($swipeCount swipes). Time to take an eye break!";


    sent.add((
      id: 1004,
      title: title,
      body: body,
      payload: '/dashboard',
    ));
  }

  @override
  Future<void> cancelAll() async {
    sent.clear();
  }


  void simulateTap(String? payload) {
    onSelectNotification?.call(payload);
  }
}

/// Riverpod provider exposing the active [NotificationService].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});
