import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';
import 'package:scrollguard/features/dashboard/dashboard_screen.dart';
import 'package:scrollguard/features/onboarding/onboarding_screen.dart';
import 'package:scrollguard/features/penalties/penalties_screen.dart';
import 'package:scrollguard/features/permissions/permissions_screen.dart';
import 'package:scrollguard/features/rules/rules_screen.dart';
import 'package:scrollguard/features/sessions/sessions_screen.dart';
import 'package:scrollguard/features/settings/settings_screen.dart';
import 'package:scrollguard/features/stats/stats_screen.dart';

/// Tracks whether the user has completed the initial onboarding flow.
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

/// Helper ChangeNotifier for GoRouter refreshListenable, monitoring
/// onboarding state, guard permissions status, and app resume lifecycle.
class RouterNotifier extends ChangeNotifier with WidgetsBindingObserver {
  RouterNotifier(this._ref) {
    WidgetsBinding.instance.addObserver(this);

    _ref
      ..listen(onboardingCompletedProvider, (_, __) {
        notifyListeners();
      })
      ..listen(guardStatusProvider, (_, __) {
        notifyListeners();
      });
  }

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-query status when returning to app from settings
      _ref.invalidate(guardStatusProvider);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final isOnboarded = _ref.read(onboardingCompletedProvider);
    final guardStatusAsync = _ref.read(guardStatusProvider);
    final status = guardStatusAsync.value ?? const GuardStatus();

    final location = state.uri.path;
    final isOnboarding = location == '/onboarding';
    final isPermissions = location == '/permissions';

    // 1. If not onboarded -> redirect to onboarding
    if (!isOnboarded) {
      return isOnboarding ? null : '/onboarding';
    }

    // 2. If onboarded but critical permission (Accessibility) is missing -> redirect to permissions
    if (!status.isAccessibilityServiceEnabled) {
      return isPermissions ? null : '/permissions';
    }

    // 3. If fully onboarded and permitted, redirect out of gate screens to dashboard
    if (isOnboarding || isPermissions || location == '/') {
      return '/dashboard';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Provider for GoRouter instance with reactive gating.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        name: 'gate',
        builder: (context, state) => const PlaceholderScreen(
          title: 'ScrollGuard Gate',
          subtitle: 'Evaluating access state...',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: '/sessions',
        name: 'sessions',
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/rules',
        name: 'rules',
        builder: (context, state) => const RulesScreen(),
      ),
      GoRoute(
        path: '/penalties',
        name: 'penalties',
        builder: (context, state) => const PenaltiesScreen(),
      ),
      GoRoute(
        path: '/contract',
        name: 'contract',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Commitment Contract',
          subtitle: 'Voluntary Stake & Consequence System',
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// A placeholder screen for route skeleton testing.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
