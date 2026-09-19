import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

enum StatsPeriod { weekly, monthly }

/// Screen presenting weekly and monthly doomscrolling trends, bar charts,
/// per-app breakdown, and session dwell statistics.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.weekly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeekly = _selectedPeriod == StatsPeriod.weekly;

    final statsAsync =
        isWeekly ? ref.watch(weeklyStatsProvider) : ref.watch(monthlyStatsProvider);
    final configAsync = ref.watch(guardConfigProvider);
    final config = configAsync.value ?? const GuardConfig();

    // Query sessions over the period
    final now = DateTime.now();
    final daysBack = isWeekly ? 7 : 30;
    final fromMs = now.subtract(Duration(days: daysBack)).millisecondsSinceEpoch;
    final toMs = now.millisecondsSinceEpoch;
    final sessionsAsync = ref.watch(
      sessionsProvider(SessionQueryRange(fromEpochMs: fromMs, toEpochMs: toMs)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends & Analytics'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(weeklyStatsProvider)
              ..invalidate(monthlyStatsProvider)
              ..invalidate(sessionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading stats: $err'),
                    ),
                  ),
                  data: (dailyRecords) => _buildStatsContent(
                    theme: theme,
                    records: dailyRecords,
                    budgetSeconds: config.dailyBudgetSeconds,
                    sessions: sessionsAsync.value ?? const [],
                    daysCount: daysBack,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<StatsPeriod>(
      segments: const [
        ButtonSegment(
          value: StatsPeriod.weekly,
          label: Text('Past 7 Days'),
          icon: Icon(Icons.calendar_view_week),
        ),
        ButtonSegment(
          value: StatsPeriod.monthly,
          label: Text('Past 30 Days'),
          icon: Icon(Icons.calendar_month),
        ),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (newSelection) {
        setState(() {
          _selectedPeriod = newSelection.first;
        });
      },
    );
  }

  Widget _buildStatsContent({
    required ThemeData theme,
    required List<DailyStatsRecord> records,
    required int budgetSeconds,
    required List<SessionRecord> sessions,
    required int daysCount,
  }) {
    // Sort chronological for chart
    final sortedRecords = List<DailyStatsRecord>.from(records)
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    final budgetMinutes = budgetSeconds ~/ 60;
    var totalSeconds = 0;
    var totalSwipes = 0;
    DailyStatsRecord? bestDay;
    DailyStatsRecord? worstDay;

    for (final r in sortedRecords) {
      totalSeconds += r.feedSeconds;
      totalSwipes += r.swipeCount;

      if (bestDay == null || r.feedSeconds < bestDay.feedSeconds) {
        bestDay = r;
      }
      if (worstDay == null || r.feedSeconds > worstDay.feedSeconds) {
        worstDay = r;
      }
    }

    final avgDailyMinutes = sortedRecords.isNotEmpty
        ? (totalSeconds / sortedRecords.length / 60).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChartCard(theme, sortedRecords, budgetMinutes),
        const SizedBox(height: 20),
        _buildSummaryTiles(
          theme: theme,
          avgDailyMinutes: avgDailyMinutes,
          totalSwipes: totalSwipes,
          bestDay: bestDay,
          worstDay: worstDay,
        ),
        const SizedBox(height: 20),
        _buildAppBreakdownCard(theme, sessions, totalSeconds),
      ],
    );
  }

  Widget _buildChartCard(
    ThemeData theme,
    List<DailyStatsRecord> records,
    int budgetMinutes,
  ) {
    if (records.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('No activity recorded for this period yet.')),
        ),
      );
    }

    final maxVal = records.fold<double>(
      budgetMinutes.toDouble() * 1.2,
      (max, r) => math.max(max, r.feedSeconds / 60.0 * 1.15),
    );

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final mins = r.feedSeconds / 60.0;
      final isExceeded = mins > budgetMinutes;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: mins,
              color: isExceeded ? theme.colorScheme.error : theme.colorScheme.primary,
              width: records.length > 14 ? 6 : 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Feed Time (Minutes)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Within Budget', style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Exceeded', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: math.max(10, maxVal),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final r = records[group.x];
                        return BarTooltipItem(
                          '${r.dateIso}\n${rod.toY.toStringAsFixed(1)} min',
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (val, meta) => Text(
                          '${val.toInt()}m',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < records.length) {
                            if (records.length > 7 && idx % 4 != 0) {
                              return const SizedBox.shrink();
                            }
                            final date = DateTime.tryParse(records[idx].dateIso);
                            final label = date != null
                                ? DateFormat.E().format(date)
                                : '$idx';
                            return Text(label, style: theme.textTheme.labelSmall);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTiles({
    required ThemeData theme,
    required int avgDailyMinutes,
    required int totalSwipes,
    required DailyStatsRecord? bestDay,
    required DailyStatsRecord? worstDay,
  }) {
    final bestMinutes = (bestDay?.feedSeconds ?? 0) ~/ 60;
    final worstMinutes = (worstDay?.feedSeconds ?? 0) ~/ 60;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            theme: theme,
            title: 'Daily Average',
            value: '$avgDailyMinutes min',
            icon: Icons.timelapse,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            theme: theme,
            title: 'Total Swipes',
            value: '$totalSwipes',
            icon: Icons.swipe_vertical,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            theme: theme,
            title: 'Best Day',
            value: '$bestMinutes min',
            subtitle: bestDay?.dateIso ?? '-',
            icon: Icons.thumb_up_outlined,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            theme: theme,
            title: 'Peak Day',
            value: '$worstMinutes min',
            subtitle: worstDay?.dateIso ?? '-',
            icon: Icons.trending_up,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBreakdownCard(
    ThemeData theme,
    List<SessionRecord> sessions,
    int totalPeriodSeconds,
  ) {
    if (sessions.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No app-level breakdown sessions recorded.')),
        ),
      );
    }

    final appTotals = <String, ({int seconds, int swipes, int count})>{};
    for (final s in sessions) {
      final current = appTotals[s.appId] ?? (seconds: 0, swipes: 0, count: 0);
      appTotals[s.appId] = (
        seconds: current.seconds + s.feedSeconds,
        swipes: current.swipes + s.swipeCount,
        count: current.count + 1,
      );
    }

    final entries = appTotals.entries.toList()
      ..sort((a, b) => b.value.seconds.compareTo(a.value.seconds));

    final totalSecs = math.max(1, totalPeriodSeconds);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Per-App Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...entries.map((entry) {
              final pkg = entry.key;
              final data = entry.value;
              final fraction = (data.seconds / totalSecs).clamp(0.0, 1.0);
              final mins = data.seconds ~/ 60;
              final avgDwellSecs = data.count > 0 ? data.seconds ~/ data.count : 0;
              final avgDwellMins = avgDwellSecs ~/ 60;
              final avgDwellRemSecs = avgDwellSecs % 60;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatAppDisplayName(pkg),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$mins min (${(fraction * 100).toInt()}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          _getAppColor(pkg, theme),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.count} sessions · Avg dwell: ${avgDwellMins}m ${avgDwellRemSecs}s · ${data.swipes} swipes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatAppDisplayName(String pkg) {
    if (pkg.contains('youtube')) return 'YouTube Shorts';
    if (pkg.contains('instagram')) return 'Instagram Reels';
    if (pkg.contains('musically') || pkg.contains('tiktok')) return 'TikTok';
    if (pkg.contains('katana')) return 'Facebook Reels';
    if (pkg.contains('snapchat')) return 'Snapchat Spotlight';
    return pkg;
  }

  Color _getAppColor(String pkg, ThemeData theme) {
    if (pkg.contains('youtube')) return Colors.red;
    if (pkg.contains('instagram')) return Colors.purple;
    if (pkg.contains('musically') || pkg.contains('tiktok')) return Colors.teal;
    return theme.colorScheme.primary;
  }
}
