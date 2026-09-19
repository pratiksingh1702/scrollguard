import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/database/app_database.dart';
import 'package:scrollguard/core/database/database_provider.dart';
import 'package:scrollguard/core/models/guard_models.dart';

abstract class StatsRepository {
  Future<DailyStatsRecord?> getDailyStats(String dateIso);
  Future<List<DailyStatsRecord>> getHistoricalStats({int limitDays = 30});
  Future<void> cacheDailyStats(DailyStatsRecord stats);
}

class DriftStatsRepository implements StatsRepository {
  DriftStatsRepository({
    required NativeBridge bridge,
    required AppDatabase database,
  })  : _bridge = bridge,
        _db = database;

  final NativeBridge _bridge;
  final AppDatabase _db;

  @override
  Future<DailyStatsRecord?> getDailyStats(String dateIso) async {
    final nativeStats = await _bridge.getDailyStats(dateIso);
    if (nativeStats != null) {
      await cacheDailyStats(nativeStats);
      return nativeStats;
    }

    final row = await (_db.select(_db.dailyStatsEntries)
          ..where((tbl) => tbl.dateIso.equals(dateIso)))
        .getSingleOrNull();

    if (row != null) {
      return DailyStatsRecord(
        dateIso: row.dateIso,
        feedSeconds: row.feedSeconds,
        swipeCount: row.swipeCount,
        lockCount: row.lockCount,
        strikeCount: row.strikeCount,
        synced: row.synced,
      );
    }
    return null;
  }

  @override
  Future<List<DailyStatsRecord>> getHistoricalStats({
    int limitDays = 30,
  }) async {
    final rows = await (_db.select(_db.dailyStatsEntries)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.dateIso)])
          ..limit(limitDays))
        .get();

    return rows
        .map(
          (r) => DailyStatsRecord(
            dateIso: r.dateIso,
            feedSeconds: r.feedSeconds,
            swipeCount: r.swipeCount,
            lockCount: r.lockCount,
            strikeCount: r.strikeCount,
            synced: r.synced,
          ),
        )
        .toList();
  }

  @override
  Future<void> cacheDailyStats(DailyStatsRecord stats) async {
    await _db.into(_db.dailyStatsEntries).insertOnConflictUpdate(
          DailyStatsEntriesCompanion(
            dateIso: Value(stats.dateIso),
            feedSeconds: Value(stats.feedSeconds),
            swipeCount: Value(stats.swipeCount),
            lockCount: Value(stats.lockCount),
            strikeCount: Value(stats.strikeCount),
            synced: Value(stats.synced),
          ),
        );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  final db = ref.watch(appDatabaseProvider);
  return DriftStatsRepository(bridge: bridge, database: db);
});
