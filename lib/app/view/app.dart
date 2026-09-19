import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/app/router/app_router.dart';
import 'package:scrollguard/app/theme/app_theme.dart';
import 'package:scrollguard/core/notifications/notification_service.dart';

/// The root application widget for ScrollGuard.
class ScrollGuardApp extends ConsumerStatefulWidget {
  const ScrollGuardApp({super.key});

  @override
  ConsumerState<ScrollGuardApp> createState() => _ScrollGuardAppState();
}

class _ScrollGuardAppState extends ConsumerState<ScrollGuardApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize(
        onSelectNotification: (payload) {
          if (payload != null && payload.isNotEmpty) {
            ref.read(routerProvider).push(payload);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ScrollGuard',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
    );
  }
}
