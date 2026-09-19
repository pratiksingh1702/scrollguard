import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

/// Preset list of supported apps with human-readable labels and package names.
const kSupportedGuardedApps = [
  (package: 'com.google.android.youtube', label: 'YouTube Shorts', icon: Icons.play_circle_fill),
  (package: 'com.instagram.android', label: 'Instagram Reels', icon: Icons.camera_alt),
  (package: 'com.zhiliaoapp.musically', label: 'TikTok', icon: Icons.music_note),
  (package: 'com.facebook.katana', label: 'Facebook Reels', icon: Icons.video_library),
  (package: 'com.snapchat.android', label: 'Snapchat Spotlight', icon: Icons.chat_bubble),
];

/// Screen allowing the user to configure daily budgets, ladder thresholds,
/// continuous scroll limits, guarded apps, and cooldowns.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  bool _initialized = false;

  late int _dailyBudgetMinutes;
  late double _nudgeFraction;
  late double _frictionFraction;
  late double _lockFraction;
  late int _continuousNudgeMinutes;
  late int _continuousFrictionMinutes;
  late int _cooldownMinutes;
  late int _resetHour;
  late int _maxEmergencyUnlocks;
  late Set<String> _guardedApps;

  void _syncFromConfig(GuardConfig config) {
    _dailyBudgetMinutes = (config.dailyBudgetSeconds / 60).round();
    _nudgeFraction = config.nudgeThresholdFraction;
    _frictionFraction = config.frictionThresholdFraction;
    _lockFraction = config.lockThresholdFraction;
    _continuousNudgeMinutes = config.continuousNudgeMinutes;
    _continuousFrictionMinutes = config.continuousFrictionMinutes;
    _cooldownMinutes = config.cooldownMinutes;
    _resetHour = config.resetHour;
    _maxEmergencyUnlocks = config.maxEmergencyUnlocksPerDay;
    _guardedApps = Set.from(config.guardedApps);
    _initialized = true;
  }

  String? _getValidationError() {
    if (_guardedApps.isEmpty) {
      return 'Select at least one app to guard.';
    }
    if (_dailyBudgetMinutes < 5) {
      return 'Daily budget must be at least 5 minutes.';
    }
    if (_nudgeFraction >= _frictionFraction) {
      return 'Nudge threshold (${(_nudgeFraction * 100).round()}%) must be less than friction threshold (${(_frictionFraction * 100).round()}%).';
    }
    if (_frictionFraction >= _lockFraction) {
      return 'Friction threshold (${(_frictionFraction * 100).round()}%) must be less than lock threshold (${(_lockFraction * 100).round()}%).';
    }
    if (_continuousNudgeMinutes >= _continuousFrictionMinutes) {
      return 'Continuous nudge limit (${_continuousNudgeMinutes}m) must be less than continuous friction limit (${_continuousFrictionMinutes}m).';
    }
    return null;
  }

  void _resetToDefaults() {
    setState(() {
      _syncFromConfig(const GuardConfig());
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to default values.')),
    );
  }

  Future<void> _saveConfig() async {
    final validationError = _getValidationError();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final newConfig = GuardConfig(
      dailyBudgetSeconds: _dailyBudgetMinutes * 60,
      nudgeThresholdFraction: _nudgeFraction,
      frictionThresholdFraction: _frictionFraction,
      lockThresholdFraction: _lockFraction,
      continuousNudgeMinutes: _continuousNudgeMinutes,
      continuousFrictionMinutes: _continuousFrictionMinutes,
      cooldownMinutes: _cooldownMinutes,
      maxEmergencyUnlocksPerDay: _maxEmergencyUnlocks,
      resetHour: _resetHour,
      guardedApps: _guardedApps.toList(),
    );

    try {
      await ref.read(guardConfigProvider.notifier).updateConfig(newConfig);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rules applied successfully.')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rules: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(guardConfigProvider);

    if (!_initialized && configAsync.hasValue) {
      _syncFromConfig(configAsync.value!);
    } else if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rules & Budgets')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final validationError = _getValidationError();
    final isValid = validationError == null;
    final isSaving = configAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules & Budgets'),
        actions: [
          TextButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor.withAlpha(50)),
            ),
          ),
          child: FilledButton.icon(
            key: const Key('rules_save_button'),
            onPressed: isValid && !isSaving ? _saveConfig : null,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(isSaving ? 'Applying...' : 'Save & Apply Rules'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (validationError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        validationError,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _buildGuardedAppsSection(theme),
            const SizedBox(height: 20),
            _buildDailyBudgetSection(theme),
            const SizedBox(height: 20),
            _buildLadderThresholdsSection(theme),
            const SizedBox(height: 20),
            _buildContinuousLimitsSection(theme),
            const SizedBox(height: 20),
            _buildCooldownAndResetSection(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardedAppsSection(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Guarded Platforms',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_guardedApps.length} active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Enforcement occurs strictly when short-video feeds are detected inside these apps.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
            const SizedBox(height: 12),
            ...kSupportedGuardedApps.map((app) {
              final isChecked = _guardedApps.contains(app.package);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: isChecked,
                activeColor: theme.colorScheme.primary,
                secondary: Icon(app.icon, size: 22),
                title: Text(app.label, style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  app.package,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.labelSmall?.color?.withAlpha(120),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val ?? false) {
                      _guardedApps.add(app.package);
                    } else {
                      _guardedApps.remove(app.package);
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBudgetSection(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Budget',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_dailyBudgetMinutes min/day',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Total allowed short-form video watch time before the hard lock triggers.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              key: const Key('daily_budget_slider'),
              value: _dailyBudgetMinutes.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              label: '$_dailyBudgetMinutes min',
              onChanged: (val) {
                setState(() {
                  _dailyBudgetMinutes = val.round();
                });
              },
            ),
            Wrap(
              spacing: 8,
              children: [15, 30, 45, 60, 90].map((preset) {
                final isSelected = _dailyBudgetMinutes == preset;
                return ChoiceChip(
                  label: Text('${preset}m'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _dailyBudgetMinutes = preset;
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLadderThresholdsSection(ThemeData theme) {
    final nudgeMin = (_dailyBudgetMinutes * _nudgeFraction).round();
    final frictionMin = (_dailyBudgetMinutes * _frictionFraction).round();
    final lockMin = (_dailyBudgetMinutes * _lockFraction).round();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Penalty Ladder Thresholds',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Percentage of your daily budget that activates each escalation tier. Must follow L0 < L1 < L2.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            // L0 Nudge
            _buildLadderSlider(
              theme: theme,
              title: 'L0: Gentle Nudge Banner',
              description: 'Toast banner alerting you that you reached $nudgeMin min.',
              color: Colors.amber,
              value: _nudgeFraction,
              sliderKey: 'nudge_slider',
              onChanged: (v) => setState(() => _nudgeFraction = (v * 100).round() / 100),
            ),
            const Divider(height: 24),
            // L1 Friction
            _buildLadderSlider(
              theme: theme,
              title: 'L1: Countdown & Friction',
              description: '10-second blocking overlay with breathing prompt at $frictionMin min.',
              color: Colors.orange,
              value: _frictionFraction,
              sliderKey: 'friction_slider',
              onChanged: (v) => setState(() => _frictionFraction = (v * 100).round() / 100),
            ),
            const Divider(height: 24),
            // L2 Lock
            _buildLadderSlider(
              theme: theme,
              title: 'L2: Hard Lockout',
              description: 'Immediate feed exit and blocking screen at $lockMin min.',
              color: Colors.redAccent,
              value: _lockFraction,
              sliderKey: 'lock_slider',
              onChanged: (v) => setState(() => _lockFraction = (v * 100).round() / 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLadderSlider({
    required ThemeData theme,
    required String title,
    required String description,
    required Color color,
    required double value,
    required String sliderKey,
    required ValueChanged<double> onChanged,
  }) {
    final pct = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              '$pct% budget',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withAlpha(160),
          ),
        ),
        Slider(
          key: Key(sliderKey),
          value: value,
          min: 0.1,
          divisions: 18,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildContinuousLimitsSection(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continuous Doomscroll Limits',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Triggers ladder interventions early if you scroll without stopping, even if under daily budget.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nudge at',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_continuousNudgeMinutes min continuous',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Slider(
                        value: _continuousNudgeMinutes.toDouble(),
                        min: 3,
                        max: 30,
                        divisions: 27,
                        onChanged: (v) {
                          setState(() {
                            _continuousNudgeMinutes = v.round();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friction at',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_continuousFrictionMinutes min continuous',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Slider(
                        value: _continuousFrictionMinutes.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 55,
                        onChanged: (v) {
                          setState(() {
                            _continuousFrictionMinutes = v.round();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownAndResetSection(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cooldown & Day Rollover',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lockout Cooldown Duration'),
              subtitle: Text('$_cooldownMinutes minutes before lockout unlocks'),
              trailing: DropdownButton<int>(
                value: _cooldownMinutes,
                items: [10, 15, 20, 30, 45, 60].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('${m}m'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _cooldownMinutes = v);
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Budget Reset Hour'),
              subtitle: Text('$_resetHour:00 (prevents midnight binge loopholes)'),
              trailing: DropdownButton<int>(
                value: _resetHour,
                items: List.generate(24, (h) => h).map((h) {
                  final formatted = h == 0
                      ? '12 AM'
                      : h < 12
                          ? '$h AM'
                          : h == 12
                              ? '12 PM'
                              : '${h - 12} PM';
                  return DropdownMenuItem(
                    value: h,
                    child: Text(formatted),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _resetHour = v);
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Emergency Unlocks'),
              subtitle: Text(
                '$_maxEmergencyUnlocks allowed per logical day (requires typed reason)',
              ),
              trailing: DropdownButton<int>(
                value: _maxEmergencyUnlocks,
                items: [0, 1, 2, 3].map((count) {
                  return DropdownMenuItem(
                    value: count,
                    child: Text('$count / day'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _maxEmergencyUnlocks = v);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
