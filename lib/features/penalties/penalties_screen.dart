import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

/// Screen displaying the transparent history of all penalty events and interventions.
class PenaltiesScreen extends ConsumerStatefulWidget {
  const PenaltiesScreen({super.key});

  @override
  ConsumerState<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends ConsumerState<PenaltiesScreen> {
  int? _selectedLevelFilter;
  String? _selectedAppFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final penaltiesAsync = ref.watch(recentPenaltiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penalty History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(recentPenaltiesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: penaltiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Failed to load penalty history: $err'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(recentPenaltiesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (allPenalties) {
            // Apply level and app filters
            var filtered = allPenalties;
            if (_selectedLevelFilter != null) {
              filtered = filtered
                  .where((p) => p.level == _selectedLevelFilter)
                  .toList();
            }
            if (_selectedAppFilter != null) {
              filtered = filtered
                  .where((p) => p.appId == _selectedAppFilter)
                  .toList();
            }

            // Sort newest first
            filtered.sort((a, b) => b.ts.compareTo(a.ts));

            // Extract unique apps for filter chips
            final uniqueApps = allPenalties.map((p) => p.appId).toSet().toList();

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recentPenaltiesProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryHeader(theme, allPenalties),
                          const SizedBox(height: 16),
                          _buildFilterSection(theme, uniqueApps),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, allPenalties.isNotEmpty),
                    )
                  else
                    _buildGroupedPenaltiesList(theme, filtered),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(ThemeData theme, List<PenaltyEventRecord> events) {
    final l0Count = events.where((e) => e.level == 0).length;
    final l1Count = events.where((e) => e.level == 1).length;
    final l2Count = events.where((e) => e.level == 2).length;
    final l3Count = events.where((e) => e.level == 3).length;

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
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Accountability Log',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${events.length} total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Every guard intervention is recorded deterministically from native enforcement. No screen content is ever stored.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatPill('L0 Nudge', l0Count, Colors.amber, theme),
                const SizedBox(width: 8),
                _buildStatPill('L1 Friction', l1Count, Colors.orange, theme),
                const SizedBox(width: 8),
                _buildStatPill('L2 Lockout', l2Count, Colors.redAccent, theme),
                if (l3Count > 0) ...[
                  const SizedBox(width: 8),
                  _buildStatPill('L3 Stake', l3Count, Colors.deepPurpleAccent, theme),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    int count,
    Color color,
    ThemeData theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.textTheme.labelSmall?.color?.withAlpha(180),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme, List<String> uniqueApps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Tiers'),
                selected: _selectedLevelFilter == null,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedLevelFilter = null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('L0 Nudge'),
                selected: _selectedLevelFilter == 0,
                onSelected: (selected) {
                  setState(() => _selectedLevelFilter = selected ? 0 : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('L1 Friction'),
                selected: _selectedLevelFilter == 1,
                onSelected: (selected) {
                  setState(() => _selectedLevelFilter = selected ? 1 : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('L2 Lockout'),
                selected: _selectedLevelFilter == 2,
                onSelected: (selected) {
                  setState(() => _selectedLevelFilter = selected ? 2 : null);
                },
              ),
            ],
          ),
        ),
        if (uniqueApps.length > 1) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Apps'),
                  selected: _selectedAppFilter == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedAppFilter = null);
                  },
                ),
                ...uniqueApps.map((appId) {
                  final label = _formatAppName(appId);
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: _selectedAppFilter == appId,
                      onSelected: (selected) {
                        setState(() {
                          _selectedAppFilter = selected ? appId : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool hasUnfiltered) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasUnfiltered ? Icons.filter_alt_off : Icons.verified_user_outlined,
              size: 56,
              color: hasUnfiltered ? theme.colorScheme.outline : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              hasUnfiltered ? 'No Matching Penalties' : 'Clean Record!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasUnfiltered
                  ? 'No penalties match your active filter criteria.'
                  : 'You have stayed within your scrolling budget without triggering any lockout or friction interventions.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withAlpha(160),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedPenaltiesList(
    ThemeData theme,
    List<PenaltyEventRecord> penalties,
  ) {
    // Group events by day string
    final grouped = <String, List<PenaltyEventRecord>>{};
    for (final p in penalties) {
      final date = DateTime.fromMillisecondsSinceEpoch(p.ts);
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(key, () => []).add(p);
    }

    final dateKeys = grouped.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dateKey = dateKeys[index];
          final eventsInDay = grouped[dateKey]!;
          final headerDate = DateTime.parse(dateKey);
          final headerText = _formatDateHeader(headerDate);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        headerText,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${eventsInDay.length})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ),
                ...eventsInDay.map(
                  (event) => _buildPenaltyCard(theme, event),
                ),
              ],
            ),
          );
        },
        childCount: dateKeys.length,
      ),
    );
  }

  Widget _buildPenaltyCard(ThemeData theme, PenaltyEventRecord event) {
    final date = DateTime.fromMillisecondsSinceEpoch(event.ts);
    final timeStr = DateFormat('h:mm a').format(date);
    final appName = _formatAppName(event.appId);
    final tierInfo = _getTierInfo(event.level);
    final humanReason = _formatHumanReason(event, appName);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tierInfo.color.withAlpha(40)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPenaltyDetailSheet(event, appName, tierInfo),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tierInfo.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tierInfo.icon, size: 14, color: tierInfo.color),
                        const SizedBox(width: 4),
                        Text(
                          tierInfo.tag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tierInfo.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textTheme.labelSmall?.color?.withAlpha(140),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                humanReason,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: event.budgetFraction.clamp(0.0, 1.0),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: tierInfo.color,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(event.budgetFraction * 100).round()}% budget',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tierInfo.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPenaltyDetailSheet(
    PenaltyEventRecord event,
    String appName,
    ({String tag, String title, Color color, IconData icon, String description})
        tierInfo,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PenaltyDetailSheet(
        event: event,
        appName: appName,
        tierInfo: tierInfo,
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  String _formatAppName(String appId) {
    if (appId.contains('youtube')) return 'YouTube Shorts';
    if (appId.contains('instagram')) return 'Instagram Reels';
    if (appId.contains('musically') || appId.contains('trill')) return 'TikTok';
    if (appId.contains('katana')) return 'Facebook Reels';
    if (appId.contains('snapchat')) return 'Snapchat Spotlight';
    return appId;
  }

  String _formatHumanReason(PenaltyEventRecord event, String appName) {
    final reasonUpper = event.reason.toUpperCase();
    final pct = (event.budgetFraction * 100).round();

    if (reasonUpper.contains('BUDGET')) {
      return 'Budget reached: $pct% daily limit in $appName';
    }
    if (reasonUpper.contains('CONTINUOUS')) {
      return 'Continuous doomscroll threshold reached in $appName';
    }
    if (reasonUpper.contains('COOLDOWN')) {
      return 'Re-opened $appName during lockout cooldown';
    }
    return event.reason;
  }

  ({String tag, String title, Color color, IconData icon, String description})
      _getTierInfo(int level) {
    switch (level) {
      case 0:
        return (
          tag: 'L0 Nudge',
          title: 'Gentle Nudge Alert',
          color: Colors.amber,
          icon: Icons.notifications_active_outlined,
          description:
              'A non-blocking banner was displayed alerting you that you entered high-usage territory.',
        );
      case 1:
        return (
          tag: 'L1 Friction',
          title: 'Friction Countdown Screen',
          color: Colors.orange,
          icon: Icons.timer_outlined,
          description:
              'A 10-second blocking overlay intercepted your feed with a breathing pause to break the trance.',
        );
      case 2:
        return (
          tag: 'L2 Lockout',
          title: 'Hard Feed Lockout',
          color: Colors.redAccent,
          icon: Icons.lock_outline,
          description:
              'ScrollGuard terminated feed view and locked access until the cooldown or daily reset period.',
        );
      case 3:
      default:
        return (
          tag: 'L3 Stake',
          title: 'Voluntary Stake Penalty',
          color: Colors.deepPurpleAccent,
          icon: Icons.account_balance_wallet_outlined,
          description:
              'Voluntary financial commitment contract executed due to repeated lockout breach.',
        );
    }
  }
}

class _PenaltyDetailSheet extends StatelessWidget {
  const _PenaltyDetailSheet({
    required this.event,
    required this.appName,
    required this.tierInfo,
  });

  final PenaltyEventRecord event;
  final String appName;
  final ({String tag, String title, Color color, IconData icon, String description})
      tierInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = DateTime.fromMillisecondsSinceEpoch(event.ts);
    final timeStr = DateFormat('MMMM d, yyyy · h:mm:ss a').format(dt);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tierInfo.color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(tierInfo.icon, color: tierInfo.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierInfo.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tierInfo.tag,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tierInfo.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tierInfo.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withAlpha(200),
            ),
          ),
          const Divider(height: 32),
          _buildInfoRow('Platform', appName, theme),
          const SizedBox(height: 12),
          _buildInfoRow('Timestamp', timeStr, theme),
          const SizedBox(height: 12),
          _buildInfoRow('Trigger Reason', event.reason, theme),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Budget Reached',
            '${(event.budgetFraction * 100).round()}%',
            theme,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Sync State',
            event.synced ? 'Synced to Cloud' : 'Local Only',
            theme,
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Event ID', event.id, theme),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Center(child: Text('Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withAlpha(160),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
