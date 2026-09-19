import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollguard/app/router/app_router.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Configuration state gathered during onboarding
  final Set<String> _selectedApps = {
    'com.google.android.youtube',
    'com.instagram.android',
    'com.zhiliaoapp.musically',
  };
  int _dailyBudgetMinutes = 30;
  bool _disclosureAccepted = false;

  void _nextPage() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final newConfig = GuardConfig(
      dailyBudgetSeconds: _dailyBudgetMinutes * 60,
      guardedApps: _selectedApps.toList(),
    );
    await ref.read(guardConfigProvider.notifier).updateConfig(newConfig);
    ref.read(onboardingCompletedProvider.notifier).state = true;
    if (mounted) {
      try {
        context.go('/permissions');
      } on Object catch (_) {
        // Safe fallback if screen is rendered outside GoRouter in tests
      }
    }
  }

  void _showDeclineDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Consent Required for Protection'),
        content: const Text(
          'Without Accessibility permission, ScrollGuard cannot detect when '
          'short-video feeds (like Shorts or Reels) are active, and cannot enforce '
          'your daily budget.\n\n'
          'No messages, comments, or video titles will ever be read. '
          'You may reconsider at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Review Disclosure'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Exit safely back to step 0
              _pageController.jumpToPage(0);
            },
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup ScrollGuard (${_currentStep + 1}/5)'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                children: [
                  _buildStep0ValuePitch(theme),
                  _buildStep1AppSelection(theme),
                  _buildStep2BudgetSetup(theme),
                  _buildStep3ProminentDisclosure(theme),
                  _buildStep4Ready(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 0: Value Pitch
  Widget _buildStep0ValuePitch(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 64,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Reclaim Your Focus',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Stop losing hours to addictive algorithmic feeds. '
            'ScrollGuard intervenes right when you need it most.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          _buildFeatureRow(
            theme,
            Icons.speed,
            'Feed-Level Detection',
            'Blocks only Shorts & Reels, not educational videos or DMs.',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            theme,
            Icons.lock_outline,
            '100% On-Device Privacy',
            'Never reads, records, or uploads personal messages or video titles.',
          ),
          const Spacer(),
          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  // Step 1: Select Guarded Apps
  Widget _buildStep1AppSelection(ThemeData theme) {
    final availableApps = <({String pkg, String name, IconData icon})>[
      (pkg: 'com.google.android.youtube', name: 'YouTube Shorts', icon: Icons.play_arrow),
      (pkg: 'com.instagram.android', name: 'Instagram Reels', icon: Icons.camera_alt),
      (pkg: 'com.zhiliaoapp.musically', name: 'TikTok', icon: Icons.music_note),
      (pkg: 'com.facebook.katana', name: 'Facebook Reels', icon: Icons.facebook),
      (pkg: 'com.snapchat.android', name: 'Snapchat Spotlight', icon: Icons.chat_bubble_outline),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Guarded Apps',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select which apps ScrollGuard should protect you from.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: availableApps.length,
              itemBuilder: (ctx, idx) {
                final app = availableApps[idx];
                final pkg = app.pkg;
                final name = app.name;
                final icon = app.icon;
                final selected = _selectedApps.contains(pkg);

                return CheckboxListTile(
                  value: selected,
                  onChanged: (val) {
                    setState(() {
                      if (val ?? false) {
                        _selectedApps.add(pkg);
                      } else {
                        _selectedApps.remove(pkg);
                      }
                    });
                  },
                  secondary: Icon(icon),
                  title: Text(name),
                  subtitle: Text(pkg, style: theme.textTheme.bodySmall),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: _selectedApps.isNotEmpty ? _nextPage : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // Step 2: Set Budget
  Widget _buildStep2BudgetSetup(ThemeData theme) {
    const budgetOptions = [15, 30, 45, 60];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Your Daily Budget',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How much short-video scrolling do you want to allow each day?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: Text(
              '$_dailyBudgetMinutes min',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Slider(
            value: _dailyBudgetMinutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: '$_dailyBudgetMinutes min',
            onChanged: (val) {
              setState(() {
                _dailyBudgetMinutes = val.toInt();
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: budgetOptions.map((mins) {
              final isSelected = _dailyBudgetMinutes == mins;
              return ChoiceChip(
                label: Text('$mins min'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _dailyBudgetMinutes = mins;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // Step 3: Prominent Disclosure for Accessibility (Mandatory for Play Store Policy)
  Widget _buildStep3ProminentDisclosure(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How ScrollGuard uses Accessibility Services',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ScrollGuard uses the Android AccessibilityService API to detect '
                        'when you are actively viewing short-form video feeds (such as YouTube '
                        'Shorts and Instagram Reels) and count your scroll interactions.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'What we inspect:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBulletPoint(theme, 'The active app package name (to activate only in selected apps)'),
                      _buildBulletPoint(theme, 'View identifiers and scroll events (to detect vertical video feed containers)'),
                      _buildBulletPoint(theme, 'Durations and swipe intervals (to compute your doomscroll score and enforce your limits)'),
                      const SizedBox(height: 16),
                      Text(
                        'What we NEVER inspect or collect:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBulletPoint(theme, 'We never read, store, or transmit your messages, comments, or video titles.'),
                      _buildBulletPoint(theme, 'We never collect personal account information or on-screen text.'),
                      const SizedBox(height: 16),
                      Text(
                        'By tapping Agree, you give ScrollGuard permission to monitor '
                        'feed containers and show intervention overlays according to your budget.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _showDeclineDialog,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _disclosureAccepted = true;
                    });
                    _nextPage();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Agree'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 4: Ready
  Widget _buildStep4Ready(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            Icons.check_circle_outline,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Enable Guard',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Next, grant the required Android permissions so ScrollGuard can protect you in the background.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _disclosureAccepted ? _finishOnboarding : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    ThemeData theme,
    IconData icon,
    String title,
    String desc,
  ) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
