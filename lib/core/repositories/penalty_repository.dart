import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/database/app_database.dart';
import 'package:scrollguard/core/database/database_provider.dart';
import 'package:scrollguard/core/models/guard_models.dart';

abstract class PenaltyRepository {
  Future<List<PenaltyEventRecord>> getPenaltyEvents(
    int fromEpochMs,
    int toEpochMs,
  );
  Future<void> cachePenaltyEvents(List<PenaltyEventRecord> events);
}

class DriftPenaltyRepository implements PenaltyRepository {
  DriftPenaltyRepository({
    required NativeBridge bridge,
    required AppDatabase database,
  })  : _bridge = bridge,
        _db = database;

  final NativeBridge _bridge;
  final AppDatabase _db;

  @override
  Future<List<PenaltyEventRecord>> getPenaltyEvents(
    int fromEpochMs,
    int toEpochMs,
  ) async {
    final nativeEvents = await _bridge.getPenaltyEvents(
      fromEpochMs,
      toEpochMs,
    );
    if (nativeEvents.isNotEmpty) {
      await cachePenaltyEvents(nativeEvents);
    }
    return nativeEvents;
  }

  @override
  Future<void> cachePenaltyEvents(List<PenaltyEventRecord> events) async {
    for (final e in events) {
      await _db.into(_db.penaltyEventEntries).insertOnConflictUpdate(
            PenaltyEventEntriesCompanion(
              id: Value(e.id),
              ts: Value(e.ts),
              appId: Value(e.appId),
              level: Value(e.level),
              reason: Value(e.reason),
              budgetFraction: Value(e.budgetFraction),
              metaJson: Value(e.metaJson),
              synced: Value(e.synced),
            ),
          );
    }
  }
}

final penaltyRepositoryProvider = Provider<PenaltyRepository>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  final db = ref.watch(appDatabaseProvider);
  return DriftPenaltyRepository(bridge: bridge, database: db);
});
