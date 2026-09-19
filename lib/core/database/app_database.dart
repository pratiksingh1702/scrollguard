import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class DailyStatsEntries extends Table {
  TextColumn get dateIso => text()();
  IntColumn get feedSeconds => integer()();
  IntColumn get swipeCount => integer()();
  IntColumn get lockCount => integer()();
  IntColumn get strikeCount => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {dateIso};
}

class PenaltyEventEntries extends Table {
  TextColumn get id => text()();
  IntColumn get ts => integer()();
  TextColumn get appId => text()();
  IntColumn get level => integer()();
  TextColumn get reason => text()();
  RealColumn get budgetFraction => real()();
  TextColumn get metaJson => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get payloadJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [DailyStatsEntries, PenaltyEventEntries, SyncQueueEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'scrollguard_drift');
  }
}
