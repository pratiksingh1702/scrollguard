import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

/// Screen displaying the history of short-video feed sessions, grouped by day,
/// with per-app filters and interactive detail sheets.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String _selectedAppFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(recentSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentSessionsProvider);
          },
          child: sessionsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load sessions: $err'),
              ),
            ),
            data: (allSessions) {
              final filteredSessions = _selectedAppFilter == 'all'
                  ? allSessions
                  : allSessions
                      .where((s) => s.appId == _selectedAppFilter)
                      .toList();

              // Sort latest first
              final sortedSessions = List<SessionRecord>.from(filteredSessions)
                ..sort((a, b) => b.startTs.compareTo(a.startTs));

              final grouped = _groupSessionsByDate(sortedSessions);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _buildFilterChips(allSessions),
                    ),
                  ),
                  if (sortedSessions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sessions recorded',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Short-video feeds you visit will appear here.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final dateKey = grouped.keys.elementAt(index);
                          final sessionsForDate = grouped[dateKey]!;
                          return _buildDayGroup(
                            theme: theme,
                            dateLabel: dateKey,
                            sessions: sessionsForDate,
                          );
                        },
                        childCount: grouped.length,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<SessionRecord> sessions) {
    final appIds = sessions.map((s) => s.appId).toSet().toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Apps'),
            selected: _selectedAppFilter == 'all',
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedAppFilter = 'all');
              }
            },
          ),
          ...appIds.map((pkg) {
            final isSelected = _selectedAppFilter == pkg;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(_formatAppName(pkg)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedAppFilter = selected ? pkg : 'all';
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayGroup({
    required ThemeData theme,
    required String dateLabel,
    required List<SessionRecord> sessions,
  }) {
    final totalFeedSeconds =
        sessions.fold<int>(0, (sum, s) => sum + s.feedSeconds);
    final totalMinutes = totalFeedSeconds ~/ 60;
    final totalSwipes =
        sessions.fold<int>(0, (sum, s) => sum + s.swipeCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '$totalMinutes min · $totalSwipes swipes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final session = sessions[idx];
            return _buildSessionCard(theme, session);
          },
        ),
      ],
    );
  }

  Widget _buildSessionCard(ThemeData theme, SessionRecord session) {
    final durationMins = session.feedSeconds ~/ 60;
    final durationSecs = session.feedSeconds % 60;
    final startTime = DateTime.fromMillisecondsSinceEpoch(session.startTs);
    final endTime = DateTime.fromMillisecondsSinceEpoch(session.endTs);
    final timeRange =
        '${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _showSessionDetails(context, session),
        leading: CircleAvatar(
          backgroundColor: _getAppColor(session.appId, theme).withValues(alpha: 0.15),
          child: Icon(
            _getAppIcon(session.appId),
            color: _getAppColor(session.appId, theme),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _formatAppName(session.appId),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (session.levelReached > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'L${session.levelReached}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                timeRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text('·', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Text(
                '${session.swipeCount} swipes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          '${durationMins}m ${durationSecs}s',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: durationMins >= 10
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _showSessionDetails(BuildContext context, SessionRecord session) {
    final theme = Theme.of(context);
    final durationMins = session.feedSeconds ~/ 60;
    final durationSecs = session.feedSeconds % 60;
    final startTime = DateTime.fromMillisecondsSinceEpoch(session.startTs);
    final endTime = DateTime.fromMillisecondsSinceEpoch(session.endTs);
    final avgDwellSec = (session.avgDwellMs / 1000).toStringAsFixed(1);
    final minDwellSec = (session.minDwellMs / 1000).toStringAsFixed(1);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        _getAppColor(session.appId, theme).withValues(alpha: 0.15),
                    child: Icon(
                      _getAppIcon(session.appId),
                      color: _getAppColor(session.appId, theme),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatAppName(session.appId),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${DateFormat.yMMMd().format(startTime)} · ${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow('Feed Duration', '${durationMins}m ${durationSecs}s'),
                      const Divider(height: 16),
                      _buildDetailRow('Swipes', '${session.swipeCount}'),
                      const Divider(height: 16),
                      _buildDetailRow('Average Dwell per Video', '$avgDwellSec s'),
                      const Divider(height: 16),
                      _buildDetailRow('Shortest Video Dwell', '$minDwellSec s'),
                      const Divider(height: 16),
                      _buildDetailRow('Peak Velocity', '${session.peakSpm.toStringAsFixed(1)} SPM'),
                      const Divider(height: 16),
                      _buildDetailRow('Intensity Score Max', '${session.scoreMax}/10'),
                      const Divider(height: 16),
                      _buildDetailRow('Highest Penalty Level', 'L${session.levelReached}'),
                      const Divider(height: 16),
                      _buildDetailRow('Cloud Synced', session.synced ? 'Yes' : 'Local Only'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '100% Privacy Protected: ScrollGuard only recorded structural '
                        'timing signals. No video titles, creators, or content were accessed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Map<String, List<SessionRecord>> _groupSessionsByDate(
    List<SessionRecord> sessions,
  ) {
    final grouped = <String, List<SessionRecord>>{};
    final now = DateTime.now();
    final todayStr = DateFormat.yMMMd().format(now);
    final yesterdayStr =
        DateFormat.yMMMd().format(now.subtract(const Duration(days: 1)));

    for (final s in sessions) {
      final date = DateTime.fromMillisecondsSinceEpoch(s.startTs);
      final formatted = DateFormat.yMMMd().format(date);
      String label;
      if (formatted == todayStr) {
        label = 'Today, ${DateFormat.MMMd().format(date)}';
      } else if (formatted == yesterdayStr) {
        label = 'Yesterday, ${DateFormat.MMMd().format(date)}';
      } else {
        label = formatted;
      }

      grouped.putIfAbsent(label, () => []).add(s);
    }
    return grouped;
  }

  String _formatAppName(String pkg) {
    if (pkg.contains('youtube')) return 'YouTube Shorts';
    if (pkg.contains('instagram')) return 'Instagram Reels';
    if (pkg.contains('musically') || pkg.contains('tiktok')) return 'TikTok';
    if (pkg.contains('katana')) return 'Facebook Reels';
    if (pkg.contains('snapchat')) return 'Snapchat Spotlight';
    return pkg;
  }

  IconData _getAppIcon(String pkg) {
    if (pkg.contains('youtube')) return Icons.play_arrow;
    if (pkg.contains('instagram')) return Icons.camera_alt;
    if (pkg.contains('musically') || pkg.contains('tiktok')) return Icons.music_note;
    if (pkg.contains('katana')) return Icons.facebook;
    return Icons.smartphone;
  }

  Color _getAppColor(String pkg, ThemeData theme) {
    if (pkg.contains('youtube')) return Colors.red;
    if (pkg.contains('instagram')) return Colors.purple;
    if (pkg.contains('musically') || pkg.contains('tiktok')) return Colors.teal;
    return theme.colorScheme.primary;
  }
}
