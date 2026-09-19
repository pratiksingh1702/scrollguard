import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/repositories/guard_config_repository.dart';
import 'package:scrollguard/core/repositories/penalty_repository.dart';
import 'package:scrollguard/core/repositories/session_repository.dart';
import 'package:scrollguard/core/repositories/stats_repository.dart';

/// 1. Guard Status stream from Native EventChannel
final guardStatusProvider = StreamProvider<GuardStatus>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  return bridge.watchGuardStatus();
});

/// 2. Live state stream from Native EventChannel
final liveStateProvider = StreamProvider<LiveState>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  return bridge.watchLiveState();
});

/// 3. Guard config AsyncNotifier
class GuardConfigNotifier extends AsyncNotifier<GuardConfig> {
  @override
  Future<GuardConfig> build() async {
    final repo = ref.watch(guardConfigRepositoryProvider);
    return repo.getConfig();
  }

  Future<void> updateConfig(GuardConfig newConfig) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(guardConfigRepositoryProvider);
      await repo.saveConfig(newConfig);
      return newConfig;
    });
  }
}

final guardConfigProvider =
    AsyncNotifierProvider<GuardConfigNotifier, GuardConfig>(
  GuardConfigNotifier.new,
);

/// 4. Today stats provider
final todayStatsProvider = FutureProvider.family<DailyStatsRecord?, String>((
  ref,
  dateIso,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.getDailyStats(dateIso);
});

final currentDayStatsProvider = FutureProvider<DailyStatsRecord?>((ref) async {
  final now = DateTime.now();
  final dateIso =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final repo = ref.watch(statsRepositoryProvider);
  return repo.getDailyStats(dateIso);
});

/// 5. Weekly and monthly stats providers
final weeklyStatsProvider =
    FutureProvider<List<DailyStatsRecord>>((ref) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.getHistoricalStats(limitDays: 7);
});

final monthlyStatsProvider =
    FutureProvider<List<DailyStatsRecord>>((ref) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.getHistoricalStats();
});

/// 6. Session query range and provider
@immutable
class SessionQueryRange {
  const SessionQueryRange({required this.fromEpochMs, required this.toEpochMs});

  final int fromEpochMs;
  final int toEpochMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionQueryRange &&
          fromEpochMs == other.fromEpochMs &&
          toEpochMs == other.toEpochMs;

  @override
  int get hashCode => Object.hash(fromEpochMs, toEpochMs);
}

final sessionsProvider =
    FutureProvider.family<List<SessionRecord>, SessionQueryRange>((
  ref,
  range,
) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getSessions(range.fromEpochMs, range.toEpochMs);
});

final recentSessionsProvider = FutureProvider<List<SessionRecord>>((ref) async {
  final now = DateTime.now();
  final fromMs = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  final toMs = now.millisecondsSinceEpoch;
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getSessions(fromMs, toMs);
});

/// 7. Penalties provider
final penaltiesProvider =
    FutureProvider.family<List<PenaltyEventRecord>, SessionQueryRange>((
  ref,
  range,
) async {
  final repo = ref.watch(penaltyRepositoryProvider);
  return repo.getPenaltyEvents(range.fromEpochMs, range.toEpochMs);
});

final recentPenaltiesProvider =
    FutureProvider<List<PenaltyEventRecord>>((ref) async {
  final now = DateTime.now();
  final fromMs = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  final toMs = now.millisecondsSinceEpoch;
  final repo = ref.watch(penaltyRepositoryProvider);
  return repo.getPenaltyEvents(fromMs, toMs);
});
