import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider for GoRouter instance.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const PlaceholderScreen(
          title: 'ScrollGuard Home',
          subtitle: 'Feed-level addiction guard & penalty enforcement',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Onboarding',
          subtitle: 'Welcome to ScrollGuard',
        ),
      ),
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Permissions',
          subtitle: 'Grant Accessibility & Usage Access',
        ),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Dashboard',
          subtitle: 'Live Doomscroll Guard & Daily Budget',
        ),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Stats',
          subtitle: 'Weekly & Monthly Trends',
        ),
      ),
      GoRoute(
        path: '/sessions',
        name: 'sessions',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Sessions',
          subtitle: 'Short-Video Session History',
        ),
      ),
      GoRoute(
        path: '/rules',
        name: 'rules',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Rules & Budgets',
          subtitle: 'Configure Ladders & Limits',
        ),
      ),
      GoRoute(
        path: '/penalties',
        name: 'penalties',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Penalty History',
          subtitle: 'Transparent Log of Actions',
        ),
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
        builder: (context, state) => const PlaceholderScreen(
          title: 'Settings & Diagnostics',
          subtitle: 'Account & Service Status',
        ),
      ),
    ],
  );
});

/// A simple placeholder screen for route skeleton testing.
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
