import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

/// Main Dashboard screen providing live doomscroll monitoring, daily budget
/// tracking, quick pause, and emergency unlock actions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _showPauseDialog(BuildContext context, NativeBridge bridge) {
    var selectedMinutes = 5;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pause Protection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Temporarily pause enforcement. Protection will resume '
                'automatically when time expires (max 15 minutes).',
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 15].map((mins) {
                  final isSelected = selectedMinutes == mins;
                  return ChoiceChip(
                    label: Text('$mins min'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setDialogState(() => selectedMinutes = mins);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await bridge.setGuardPaused(Duration(minutes: selectedMinutes));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Guard paused for $selectedMinutes minutes'),
                    ),
                  );
                }
              },
              child: const Text('Pause Guard'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyUnlockDialog(
    BuildContext context,
    NativeBridge bridge,
    int remainingUnlocks,
  ) {
    final reasonController = TextEditingController();
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Emergency Unlock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have $remainingUnlocks emergency unlock(s) remaining today.\n'
                'Please write a brief justification (minimum 10 characters) '
                'to hold yourself accountable.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Reason for emergency unlock',
                  hintText: 'e.g. Need to review a tutorial for work',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
                onChanged: (text) {
                  if (errorMessage != null && text.trim().length >= 10) {
                    setDialogState(() => errorMessage = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.length < 10) {
                  setDialogState(() {
                    errorMessage = 'Reason must be at least 10 characters';
                  });
                  return;
                }

                Navigator.of(ctx).pop();
                final success = await bridge.requestEmergencyUnlock(reason);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Emergency unlock granted'
                            : 'Emergency unlock failed (cap reached)',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Unlock Now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bridge = ref.watch(nativeBridgeProvider);
    final guardStatusAsync = ref.watch(guardStatusProvider);
    final liveStateAsync = ref.watch(liveStateProvider);
    final configAsync = ref.watch(guardConfigProvider);
    final todayStatsAsync = ref.watch(currentDayStatsProvider);

    final status = guardStatusAsync.value ?? const GuardStatus();
    final liveState = liveStateAsync.value ?? const LiveState();
    final config = configAsync.value ?? const GuardConfig();
    final todayStats = todayStatsAsync.value;

    final usedSeconds = (todayStats?.feedSeconds ?? 0) +
        (liveState.inFeed ? liveState.sessionSeconds : 0);
    final budgetSeconds = math.max(1, config.dailyBudgetSeconds);
    final budgetFraction = usedSeconds / budgetSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScrollGuard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Penalty History',
            onPressed: () => context.push('/penalties'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Diagnostics',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(currentDayStatsProvider)
              ..invalidate(guardStatusProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(theme, status, bridge),
                const SizedBox(height: 20),
                _buildBudgetRingCard(
                  theme: theme,
                  usedSeconds: usedSeconds,
                  budgetSeconds: budgetSeconds,
                  fraction: budgetFraction,
                ),
                const SizedBox(height: 20),
                if (liveState.inFeed)
                  _buildLiveActiveCard(theme, liveState)
                else
                  _buildLiveIdleCard(theme),
                const SizedBox(height: 20),
                _buildQuickActions(theme, bridge, status),
                const SizedBox(height: 20),
                _buildTodaySummaryGrid(theme, todayStats, status, liveState),
                const SizedBox(height: 20),
                _buildNextPenaltyCard(theme, budgetFraction, config),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(
    ThemeData theme,
    GuardStatus status,
    NativeBridge bridge,
  ) {
    final isPaused = status.isPaused;
    final isServiceRunning = status.isAccessibilityServiceEnabled;

    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (!isServiceRunning) {
      bg = theme.colorScheme.errorContainer;
      fg = theme.colorScheme.onErrorContainer;
      label = 'Guard Disabled (Tap to enable)';
      icon = Icons.warning_amber_rounded;
    } else if (isPaused) {
      bg = theme.colorScheme.tertiaryContainer;
      fg = theme.colorScheme.onTertiaryContainer;
      final remainingMs = math.max(0, status.pausedUntilMs - DateTime.now().millisecondsSinceEpoch);
      final remainingMins = (remainingMs / 60000).ceil();
      label = 'Protection Paused (~$remainingMins min left)';
      icon = Icons.pause_circle_outline;
    } else {
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.onPrimaryContainer;
      label = 'Guard Active & Protecting';
      icon = Icons.verified_user_outlined;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: !isServiceRunning ? bridge.openAccessibilitySettings : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isServiceRunning)
              Icon(Icons.chevron_right, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRingCard({
    required ThemeData theme,
    required int usedSeconds,
    required int budgetSeconds,
    required double fraction,
  }) {
    final usedMinutes = usedSeconds ~/ 60;
    final budgetMinutes = budgetSeconds ~/ 60;
    final remainingMinutes = math.max(0, budgetMinutes - usedMinutes);

    Color ringColor;
    if (fraction >= 1.0) {
      ringColor = theme.colorScheme.error;
    } else if (fraction >= 0.75) {
      ringColor = Colors.orange;
    } else {
      ringColor = theme.colorScheme.primary;
    }

    final percentDisplay = (fraction * 100).clamp(0, 999).toStringAsFixed(0);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Daily Feed Budget',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    strokeWidth: 14,
                    color: ringColor,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentDisplay%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ringColor,
                        ),
                      ),
                      Text(
                        fraction >= 1.0 ? 'Exceeded' : '$remainingMinutes min left',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 18, color: ringColor),
                const SizedBox(width: 8),
                Text(
                  '$usedMinutes / $budgetMinutes min spent in short-video feeds',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveActiveCard(ThemeData theme, LiveState live) {
    final appDisplayName = _formatPackageName(live.appId);
    final durationMins = live.sessionSeconds ~/ 60;
    final durationSecs = live.sessionSeconds % 60;

    return Card(
      elevation: 2,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'LIVE IN FEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  appDisplayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLiveStatItem(
                  theme,
                  '${durationMins}m ${durationSecs}s',
                  'Session Time',
                ),
                _buildLiveStatItem(
                  theme,
                  '${live.swipeCount}',
                  'Swipes',
                ),
                _buildLiveStatItem(
                  theme,
                  _intensityLabel(live.intensity),
                  'Intensity',
                ),
                _buildLiveStatItem(
                  theme,
                  'L${live.penaltyLevel}',
                  'Penalty Level',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _intensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return 'Med';
      case 2:
        return 'High';
      case 3:
        return 'Max';
      default:
        return 'Low';
    }
  }

  Widget _buildLiveIdleCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.spa_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Short-Video Feed',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ScrollGuard is standing by in background.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatItem(ThemeData theme, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    ThemeData theme,
    NativeBridge bridge,
    GuardStatus status,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.pause),
            label: const Text('Quick Pause'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _showPauseDialog(context, bridge),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.lock_open),
            label: Text('Unlock (${status.emergencyUnlocksRemaining})'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: status.emergencyUnlocksRemaining > 0
                ? () => _showEmergencyUnlockDialog(
                      context,
                      bridge,
                      status.emergencyUnlocksRemaining,
                    )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySummaryGrid(
    ThemeData theme,
    DailyStatsRecord? stats,
    GuardStatus status,
    LiveState live,
  ) {
    final swipes = (stats?.swipeCount ?? 0) + (live.inFeed ? live.swipeCount : 0);
    final locks = stats?.lockCount ?? 0;
    final strikes = status.strikesToday;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Activity",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryStatTile(
                  theme: theme,
                  icon: Icons.touch_app_outlined,
                  value: '$swipes',
                  label: 'Swipes',
                ),
                _buildSummaryStatTile(
                  theme: theme,
                  icon: Icons.block_outlined,
                  value: '$locks',
                  label: 'Locks Triggered',
                ),
                _buildSummaryStatTile(
                  theme: theme,
                  icon: Icons.warning_amber_outlined,
                  value: '$strikes',
                  label: 'Strikes Today',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatTile({
    required ThemeData theme,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNextPenaltyCard(
    ThemeData theme,
    double fraction,
    GuardConfig config,
  ) {
    String nextAction;
    String thresholdText;

    if (fraction < config.nudgeThresholdFraction) {
      nextAction = 'Gentle Nudge Banner';
      final min =
          (config.dailyBudgetSeconds * config.nudgeThresholdFraction) ~/ 60;
      thresholdText =
          'Triggers at ${(config.nudgeThresholdFraction * 100).toInt()}% budget (~$min min)';
    } else if (fraction < config.frictionThresholdFraction) {
      nextAction = '10s Countdown Friction Screen';
      final min =
          (config.dailyBudgetSeconds * config.frictionThresholdFraction) ~/ 60;
      thresholdText =
          'Triggers at ${(config.frictionThresholdFraction * 100).toInt()}% budget (~$min min)';
    } else if (fraction < config.lockThresholdFraction) {
      nextAction = 'App Feed Lock Screen';
      final min =
          (config.dailyBudgetSeconds * config.lockThresholdFraction) ~/ 60;
      thresholdText =
          'Triggers at ${(config.lockThresholdFraction * 100).toInt()}% budget (~$min min)';
    } else {
      nextAction = 'Strike Recorded & Day Failed';
      thresholdText = 'Budget fully exhausted';
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Intervention: $nextAction',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thresholdText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPackageName(String pkg) {
    if (pkg.contains('youtube')) return 'YouTube Shorts';
    if (pkg.contains('instagram')) return 'Instagram Reels';
    if (pkg.contains('musically') || pkg.contains('tiktok')) return 'TikTok';
    if (pkg.contains('katana')) return 'Facebook Reels';
    if (pkg.contains('snapchat')) return 'Snapchat Spotlight';
    if (pkg.isEmpty) return 'Short-Video Feed';
    return pkg;
  }
}
