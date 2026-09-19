// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DailyStatsEntriesTable extends DailyStatsEntries
    with TableInfo<$DailyStatsEntriesTable, DailyStatsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStatsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateIsoMeta = const VerificationMeta(
    'dateIso',
  );
  @override
  late final GeneratedColumn<String> dateIso = GeneratedColumn<String>(
    'date_iso',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feedSecondsMeta = const VerificationMeta(
    'feedSeconds',
  );
  @override
  late final GeneratedColumn<int> feedSeconds = GeneratedColumn<int>(
    'feed_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _swipeCountMeta = const VerificationMeta(
    'swipeCount',
  );
  @override
  late final GeneratedColumn<int> swipeCount = GeneratedColumn<int>(
    'swipe_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lockCountMeta = const VerificationMeta(
    'lockCount',
  );
  @override
  late final GeneratedColumn<int> lockCount = GeneratedColumn<int>(
    'lock_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strikeCountMeta = const VerificationMeta(
    'strikeCount',
  );
  @override
  late final GeneratedColumn<int> strikeCount = GeneratedColumn<int>(
    'strike_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    dateIso,
    feedSeconds,
    swipeCount,
    lockCount,
    strikeCount,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_stats_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStatsEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date_iso')) {
      context.handle(
        _dateIsoMeta,
        dateIso.isAcceptableOrUnknown(data['date_iso']!, _dateIsoMeta),
      );
    } else if (isInserting) {
      context.missing(_dateIsoMeta);
    }
    if (data.containsKey('feed_seconds')) {
      context.handle(
        _feedSecondsMeta,
        feedSeconds.isAcceptableOrUnknown(
          data['feed_seconds']!,
          _feedSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_feedSecondsMeta);
    }
    if (data.containsKey('swipe_count')) {
      context.handle(
        _swipeCountMeta,
        swipeCount.isAcceptableOrUnknown(data['swipe_count']!, _swipeCountMeta),
      );
    } else if (isInserting) {
      context.missing(_swipeCountMeta);
    }
    if (data.containsKey('lock_count')) {
      context.handle(
        _lockCountMeta,
        lockCount.isAcceptableOrUnknown(data['lock_count']!, _lockCountMeta),
      );
    } else if (isInserting) {
      context.missing(_lockCountMeta);
    }
    if (data.containsKey('strike_count')) {
      context.handle(
        _strikeCountMeta,
        strikeCount.isAcceptableOrUnknown(
          data['strike_count']!,
          _strikeCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_strikeCountMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dateIso};
  @override
  DailyStatsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStatsEntry(
      dateIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_iso'],
      )!,
      feedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}feed_seconds'],
      )!,
      swipeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}swipe_count'],
      )!,
      lockCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lock_count'],
      )!,
      strikeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}strike_count'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $DailyStatsEntriesTable createAlias(String alias) {
    return $DailyStatsEntriesTable(attachedDatabase, alias);
  }
}

class DailyStatsEntry extends DataClass implements Insertable<DailyStatsEntry> {
  final String dateIso;
  final int feedSeconds;
  final int swipeCount;
  final int lockCount;
  final int strikeCount;
  final bool synced;
  const DailyStatsEntry({
    required this.dateIso,
    required this.feedSeconds,
    required this.swipeCount,
    required this.lockCount,
    required this.strikeCount,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_iso'] = Variable<String>(dateIso);
    map['feed_seconds'] = Variable<int>(feedSeconds);
    map['swipe_count'] = Variable<int>(swipeCount);
    map['lock_count'] = Variable<int>(lockCount);
    map['strike_count'] = Variable<int>(strikeCount);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  DailyStatsEntriesCompanion toCompanion(bool nullToAbsent) {
    return DailyStatsEntriesCompanion(
      dateIso: Value(dateIso),
      feedSeconds: Value(feedSeconds),
      swipeCount: Value(swipeCount),
      lockCount: Value(lockCount),
      strikeCount: Value(strikeCount),
      synced: Value(synced),
    );
  }

  factory DailyStatsEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStatsEntry(
      dateIso: serializer.fromJson<String>(json['dateIso']),
      feedSeconds: serializer.fromJson<int>(json['feedSeconds']),
      swipeCount: serializer.fromJson<int>(json['swipeCount']),
      lockCount: serializer.fromJson<int>(json['lockCount']),
      strikeCount: serializer.fromJson<int>(json['strikeCount']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dateIso': serializer.toJson<String>(dateIso),
      'feedSeconds': serializer.toJson<int>(feedSeconds),
      'swipeCount': serializer.toJson<int>(swipeCount),
      'lockCount': serializer.toJson<int>(lockCount),
      'strikeCount': serializer.toJson<int>(strikeCount),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  DailyStatsEntry copyWith({
    String? dateIso,
    int? feedSeconds,
    int? swipeCount,
    int? lockCount,
    int? strikeCount,
    bool? synced,
  }) => DailyStatsEntry(
    dateIso: dateIso ?? this.dateIso,
    feedSeconds: feedSeconds ?? this.feedSeconds,
    swipeCount: swipeCount ?? this.swipeCount,
    lockCount: lockCount ?? this.lockCount,
    strikeCount: strikeCount ?? this.strikeCount,
    synced: synced ?? this.synced,
  );
  DailyStatsEntry copyWithCompanion(DailyStatsEntriesCompanion data) {
    return DailyStatsEntry(
      dateIso: data.dateIso.present ? data.dateIso.value : this.dateIso,
      feedSeconds: data.feedSeconds.present
          ? data.feedSeconds.value
          : this.feedSeconds,
      swipeCount: data.swipeCount.present
          ? data.swipeCount.value
          : this.swipeCount,
      lockCount: data.lockCount.present ? data.lockCount.value : this.lockCount,
      strikeCount: data.strikeCount.present
          ? data.strikeCount.value
          : this.strikeCount,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatsEntry(')
          ..write('dateIso: $dateIso, ')
          ..write('feedSeconds: $feedSeconds, ')
          ..write('swipeCount: $swipeCount, ')
          ..write('lockCount: $lockCount, ')
          ..write('strikeCount: $strikeCount, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dateIso,
    feedSeconds,
    swipeCount,
    lockCount,
    strikeCount,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStatsEntry &&
          other.dateIso == this.dateIso &&
          other.feedSeconds == this.feedSeconds &&
          other.swipeCount == this.swipeCount &&
          other.lockCount == this.lockCount &&
          other.strikeCount == this.strikeCount &&
          other.synced == this.synced);
}

class DailyStatsEntriesCompanion extends UpdateCompanion<DailyStatsEntry> {
  final Value<String> dateIso;
  final Value<int> feedSeconds;
  final Value<int> swipeCount;
  final Value<int> lockCount;
  final Value<int> strikeCount;
  final Value<bool> synced;
  final Value<int> rowid;
  const DailyStatsEntriesCompanion({
    this.dateIso = const Value.absent(),
    this.feedSeconds = const Value.absent(),
    this.swipeCount = const Value.absent(),
    this.lockCount = const Value.absent(),
    this.strikeCount = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyStatsEntriesCompanion.insert({
    required String dateIso,
    required int feedSeconds,
    required int swipeCount,
    required int lockCount,
    required int strikeCount,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dateIso = Value(dateIso),
       feedSeconds = Value(feedSeconds),
       swipeCount = Value(swipeCount),
       lockCount = Value(lockCount),
       strikeCount = Value(strikeCount);
  static Insertable<DailyStatsEntry> custom({
    Expression<String>? dateIso,
    Expression<int>? feedSeconds,
    Expression<int>? swipeCount,
    Expression<int>? lockCount,
    Expression<int>? strikeCount,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateIso != null) 'date_iso': dateIso,
      if (feedSeconds != null) 'feed_seconds': feedSeconds,
      if (swipeCount != null) 'swipe_count': swipeCount,
      if (lockCount != null) 'lock_count': lockCount,
      if (strikeCount != null) 'strike_count': strikeCount,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyStatsEntriesCompanion copyWith({
    Value<String>? dateIso,
    Value<int>? feedSeconds,
    Value<int>? swipeCount,
    Value<int>? lockCount,
    Value<int>? strikeCount,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return DailyStatsEntriesCompanion(
      dateIso: dateIso ?? this.dateIso,
      feedSeconds: feedSeconds ?? this.feedSeconds,
      swipeCount: swipeCount ?? this.swipeCount,
      lockCount: lockCount ?? this.lockCount,
      strikeCount: strikeCount ?? this.strikeCount,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dateIso.present) {
      map['date_iso'] = Variable<String>(dateIso.value);
    }
    if (feedSeconds.present) {
      map['feed_seconds'] = Variable<int>(feedSeconds.value);
    }
    if (swipeCount.present) {
      map['swipe_count'] = Variable<int>(swipeCount.value);
    }
    if (lockCount.present) {
      map['lock_count'] = Variable<int>(lockCount.value);
    }
    if (strikeCount.present) {
      map['strike_count'] = Variable<int>(strikeCount.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatsEntriesCompanion(')
          ..write('dateIso: $dateIso, ')
          ..write('feedSeconds: $feedSeconds, ')
          ..write('swipeCount: $swipeCount, ')
          ..write('lockCount: $lockCount, ')
          ..write('strikeCount: $strikeCount, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PenaltyEventEntriesTable extends PenaltyEventEntries
    with TableInfo<$PenaltyEventEntriesTable, PenaltyEventEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PenaltyEventEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<String> appId = GeneratedColumn<String>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetFractionMeta = const VerificationMeta(
    'budgetFraction',
  );
  @override
  late final GeneratedColumn<double> budgetFraction = GeneratedColumn<double>(
    'budget_fraction',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ts,
    appId,
    level,
    reason,
    budgetFraction,
    metaJson,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'penalty_event_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PenaltyEventEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('budget_fraction')) {
      context.handle(
        _budgetFractionMeta,
        budgetFraction.isAcceptableOrUnknown(
          data['budget_fraction']!,
          _budgetFractionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_budgetFractionMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_metaJsonMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PenaltyEventEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PenaltyEventEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      budgetFraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}budget_fraction'],
      )!,
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $PenaltyEventEntriesTable createAlias(String alias) {
    return $PenaltyEventEntriesTable(attachedDatabase, alias);
  }
}

class PenaltyEventEntry extends DataClass
    implements Insertable<PenaltyEventEntry> {
  final String id;
  final int ts;
  final String appId;
  final int level;
  final String reason;
  final double budgetFraction;
  final String metaJson;
  final bool synced;
  const PenaltyEventEntry({
    required this.id,
    required this.ts,
    required this.appId,
    required this.level,
    required this.reason,
    required this.budgetFraction,
    required this.metaJson,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ts'] = Variable<int>(ts);
    map['app_id'] = Variable<String>(appId);
    map['level'] = Variable<int>(level);
    map['reason'] = Variable<String>(reason);
    map['budget_fraction'] = Variable<double>(budgetFraction);
    map['meta_json'] = Variable<String>(metaJson);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  PenaltyEventEntriesCompanion toCompanion(bool nullToAbsent) {
    return PenaltyEventEntriesCompanion(
      id: Value(id),
      ts: Value(ts),
      appId: Value(appId),
      level: Value(level),
      reason: Value(reason),
      budgetFraction: Value(budgetFraction),
      metaJson: Value(metaJson),
      synced: Value(synced),
    );
  }

  factory PenaltyEventEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PenaltyEventEntry(
      id: serializer.fromJson<String>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      appId: serializer.fromJson<String>(json['appId']),
      level: serializer.fromJson<int>(json['level']),
      reason: serializer.fromJson<String>(json['reason']),
      budgetFraction: serializer.fromJson<double>(json['budgetFraction']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ts': serializer.toJson<int>(ts),
      'appId': serializer.toJson<String>(appId),
      'level': serializer.toJson<int>(level),
      'reason': serializer.toJson<String>(reason),
      'budgetFraction': serializer.toJson<double>(budgetFraction),
      'metaJson': serializer.toJson<String>(metaJson),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  PenaltyEventEntry copyWith({
    String? id,
    int? ts,
    String? appId,
    int? level,
    String? reason,
    double? budgetFraction,
    String? metaJson,
    bool? synced,
  }) => PenaltyEventEntry(
    id: id ?? this.id,
    ts: ts ?? this.ts,
    appId: appId ?? this.appId,
    level: level ?? this.level,
    reason: reason ?? this.reason,
    budgetFraction: budgetFraction ?? this.budgetFraction,
    metaJson: metaJson ?? this.metaJson,
    synced: synced ?? this.synced,
  );
  PenaltyEventEntry copyWithCompanion(PenaltyEventEntriesCompanion data) {
    return PenaltyEventEntry(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      appId: data.appId.present ? data.appId.value : this.appId,
      level: data.level.present ? data.level.value : this.level,
      reason: data.reason.present ? data.reason.value : this.reason,
      budgetFraction: data.budgetFraction.present
          ? data.budgetFraction.value
          : this.budgetFraction,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PenaltyEventEntry(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('appId: $appId, ')
          ..write('level: $level, ')
          ..write('reason: $reason, ')
          ..write('budgetFraction: $budgetFraction, ')
          ..write('metaJson: $metaJson, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ts,
    appId,
    level,
    reason,
    budgetFraction,
    metaJson,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PenaltyEventEntry &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.appId == this.appId &&
          other.level == this.level &&
          other.reason == this.reason &&
          other.budgetFraction == this.budgetFraction &&
          other.metaJson == this.metaJson &&
          other.synced == this.synced);
}

class PenaltyEventEntriesCompanion extends UpdateCompanion<PenaltyEventEntry> {
  final Value<String> id;
  final Value<int> ts;
  final Value<String> appId;
  final Value<int> level;
  final Value<String> reason;
  final Value<double> budgetFraction;
  final Value<String> metaJson;
  final Value<bool> synced;
  final Value<int> rowid;
  const PenaltyEventEntriesCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.appId = const Value.absent(),
    this.level = const Value.absent(),
    this.reason = const Value.absent(),
    this.budgetFraction = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PenaltyEventEntriesCompanion.insert({
    required String id,
    required int ts,
    required String appId,
    required int level,
    required String reason,
    required double budgetFraction,
    required String metaJson,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ts = Value(ts),
       appId = Value(appId),
       level = Value(level),
       reason = Value(reason),
       budgetFraction = Value(budgetFraction),
       metaJson = Value(metaJson);
  static Insertable<PenaltyEventEntry> custom({
    Expression<String>? id,
    Expression<int>? ts,
    Expression<String>? appId,
    Expression<int>? level,
    Expression<String>? reason,
    Expression<double>? budgetFraction,
    Expression<String>? metaJson,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (appId != null) 'app_id': appId,
      if (level != null) 'level': level,
      if (reason != null) 'reason': reason,
      if (budgetFraction != null) 'budget_fraction': budgetFraction,
      if (metaJson != null) 'meta_json': metaJson,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PenaltyEventEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? ts,
    Value<String>? appId,
    Value<int>? level,
    Value<String>? reason,
    Value<double>? budgetFraction,
    Value<String>? metaJson,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return PenaltyEventEntriesCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      appId: appId ?? this.appId,
      level: level ?? this.level,
      reason: reason ?? this.reason,
      budgetFraction: budgetFraction ?? this.budgetFraction,
      metaJson: metaJson ?? this.metaJson,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (appId.present) {
      map['app_id'] = Variable<String>(appId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (budgetFraction.present) {
      map['budget_fraction'] = Variable<double>(budgetFraction.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PenaltyEventEntriesCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('appId: $appId, ')
          ..write('level: $level, ')
          ..write('reason: $reason, ')
          ..write('budgetFraction: $budgetFraction, ')
          ..write('metaJson: $metaJson, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueEntriesTable extends SyncQueueEntries
    with TableInfo<$SyncQueueEntriesTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncQueueEntriesTable createAlias(String alias) {
    return $SyncQueueEntriesTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  final String id;
  final String entityType;
  final String payloadJson;
  final int createdAt;
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SyncQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueEntriesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SyncQueueEntry copyWith({
    String? id,
    String? entityType,
    String? payloadJson,
    int? createdAt,
  }) => SyncQueueEntry(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncQueueEntry copyWithCompanion(SyncQueueEntriesCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, payloadJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class SyncQueueEntriesCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> payloadJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SyncQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueEntriesCompanion.insert({
    required String id,
    required String entityType,
    required String payloadJson,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueEntry> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? payloadJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? payloadJson,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncQueueEntriesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DailyStatsEntriesTable dailyStatsEntries =
      $DailyStatsEntriesTable(this);
  late final $PenaltyEventEntriesTable penaltyEventEntries =
      $PenaltyEventEntriesTable(this);
  late final $SyncQueueEntriesTable syncQueueEntries = $SyncQueueEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dailyStatsEntries,
    penaltyEventEntries,
    syncQueueEntries,
  ];
}

typedef $$DailyStatsEntriesTableCreateCompanionBuilder =
    DailyStatsEntriesCompanion Function({
      required String dateIso,
      required int feedSeconds,
      required int swipeCount,
      required int lockCount,
      required int strikeCount,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$DailyStatsEntriesTableUpdateCompanionBuilder =
    DailyStatsEntriesCompanion Function({
      Value<String> dateIso,
      Value<int> feedSeconds,
      Value<int> swipeCount,
      Value<int> lockCount,
      Value<int> strikeCount,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$DailyStatsEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStatsEntriesTable> {
  $$DailyStatsEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dateIso => $composableBuilder(
    column: $table.dateIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get feedSeconds => $composableBuilder(
    column: $table.feedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get swipeCount => $composableBuilder(
    column: $table.swipeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lockCount => $composableBuilder(
    column: $table.lockCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get strikeCount => $composableBuilder(
    column: $table.strikeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStatsEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStatsEntriesTable> {
  $$DailyStatsEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dateIso => $composableBuilder(
    column: $table.dateIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get feedSeconds => $composableBuilder(
    column: $table.feedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get swipeCount => $composableBuilder(
    column: $table.swipeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lockCount => $composableBuilder(
    column: $table.lockCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get strikeCount => $composableBuilder(
    column: $table.strikeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStatsEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStatsEntriesTable> {
  $$DailyStatsEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dateIso =>
      $composableBuilder(column: $table.dateIso, builder: (column) => column);

  GeneratedColumn<int> get feedSeconds => $composableBuilder(
    column: $table.feedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get swipeCount => $composableBuilder(
    column: $table.swipeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lockCount =>
      $composableBuilder(column: $table.lockCount, builder: (column) => column);

  GeneratedColumn<int> get strikeCount => $composableBuilder(
    column: $table.strikeCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$DailyStatsEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStatsEntriesTable,
          DailyStatsEntry,
          $$DailyStatsEntriesTableFilterComposer,
          $$DailyStatsEntriesTableOrderingComposer,
          $$DailyStatsEntriesTableAnnotationComposer,
          $$DailyStatsEntriesTableCreateCompanionBuilder,
          $$DailyStatsEntriesTableUpdateCompanionBuilder,
          (
            DailyStatsEntry,
            BaseReferences<
              _$AppDatabase,
              $DailyStatsEntriesTable,
              DailyStatsEntry
            >,
          ),
          DailyStatsEntry,
          PrefetchHooks Function()
        > {
  $$DailyStatsEntriesTableTableManager(
    _$AppDatabase db,
    $DailyStatsEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStatsEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStatsEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStatsEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> dateIso = const Value.absent(),
                Value<int> feedSeconds = const Value.absent(),
                Value<int> swipeCount = const Value.absent(),
                Value<int> lockCount = const Value.absent(),
                Value<int> strikeCount = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsEntriesCompanion(
                dateIso: dateIso,
                feedSeconds: feedSeconds,
                swipeCount: swipeCount,
                lockCount: lockCount,
                strikeCount: strikeCount,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dateIso,
                required int feedSeconds,
                required int swipeCount,
                required int lockCount,
                required int strikeCount,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsEntriesCompanion.insert(
                dateIso: dateIso,
                feedSeconds: feedSeconds,
                swipeCount: swipeCount,
                lockCount: lockCount,
                strikeCount: strikeCount,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStatsEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStatsEntriesTable,
      DailyStatsEntry,
      $$DailyStatsEntriesTableFilterComposer,
      $$DailyStatsEntriesTableOrderingComposer,
      $$DailyStatsEntriesTableAnnotationComposer,
      $$DailyStatsEntriesTableCreateCompanionBuilder,
      $$DailyStatsEntriesTableUpdateCompanionBuilder,
      (
        DailyStatsEntry,
        BaseReferences<_$AppDatabase, $DailyStatsEntriesTable, DailyStatsEntry>,
      ),
      DailyStatsEntry,
      PrefetchHooks Function()
    >;
typedef $$PenaltyEventEntriesTableCreateCompanionBuilder =
    PenaltyEventEntriesCompanion Function({
      required String id,
      required int ts,
      required String appId,
      required int level,
      required String reason,
      required double budgetFraction,
      required String metaJson,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$PenaltyEventEntriesTableUpdateCompanionBuilder =
    PenaltyEventEntriesCompanion Function({
      Value<String> id,
      Value<int> ts,
      Value<String> appId,
      Value<int> level,
      Value<String> reason,
      Value<double> budgetFraction,
      Value<String> metaJson,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$PenaltyEventEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PenaltyEventEntriesTable> {
  $$PenaltyEventEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get budgetFraction => $composableBuilder(
    column: $table.budgetFraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PenaltyEventEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PenaltyEventEntriesTable> {
  $$PenaltyEventEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get budgetFraction => $composableBuilder(
    column: $table.budgetFraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PenaltyEventEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PenaltyEventEntriesTable> {
  $$PenaltyEventEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get appId =>
      $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<double> get budgetFraction => $composableBuilder(
    column: $table.budgetFraction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$PenaltyEventEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PenaltyEventEntriesTable,
          PenaltyEventEntry,
          $$PenaltyEventEntriesTableFilterComposer,
          $$PenaltyEventEntriesTableOrderingComposer,
          $$PenaltyEventEntriesTableAnnotationComposer,
          $$PenaltyEventEntriesTableCreateCompanionBuilder,
          $$PenaltyEventEntriesTableUpdateCompanionBuilder,
          (
            PenaltyEventEntry,
            BaseReferences<
              _$AppDatabase,
              $PenaltyEventEntriesTable,
              PenaltyEventEntry
            >,
          ),
          PenaltyEventEntry,
          PrefetchHooks Function()
        > {
  $$PenaltyEventEntriesTableTableManager(
    _$AppDatabase db,
    $PenaltyEventEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PenaltyEventEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PenaltyEventEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PenaltyEventEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<String> appId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<double> budgetFraction = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PenaltyEventEntriesCompanion(
                id: id,
                ts: ts,
                appId: appId,
                level: level,
                reason: reason,
                budgetFraction: budgetFraction,
                metaJson: metaJson,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int ts,
                required String appId,
                required int level,
                required String reason,
                required double budgetFraction,
                required String metaJson,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PenaltyEventEntriesCompanion.insert(
                id: id,
                ts: ts,
                appId: appId,
                level: level,
                reason: reason,
                budgetFraction: budgetFraction,
                metaJson: metaJson,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PenaltyEventEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PenaltyEventEntriesTable,
      PenaltyEventEntry,
      $$PenaltyEventEntriesTableFilterComposer,
      $$PenaltyEventEntriesTableOrderingComposer,
      $$PenaltyEventEntriesTableAnnotationComposer,
      $$PenaltyEventEntriesTableCreateCompanionBuilder,
      $$PenaltyEventEntriesTableUpdateCompanionBuilder,
      (
        PenaltyEventEntry,
        BaseReferences<
          _$AppDatabase,
          $PenaltyEventEntriesTable,
          PenaltyEventEntry
        >,
      ),
      PenaltyEventEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueEntriesTableCreateCompanionBuilder =
    SyncQueueEntriesCompanion Function({
      required String id,
      required String entityType,
      required String payloadJson,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SyncQueueEntriesTableUpdateCompanionBuilder =
    SyncQueueEntriesCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> payloadJson,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$SyncQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueEntriesTable,
          SyncQueueEntry,
          $$SyncQueueEntriesTableFilterComposer,
          $$SyncQueueEntriesTableOrderingComposer,
          $$SyncQueueEntriesTableAnnotationComposer,
          $$SyncQueueEntriesTableCreateCompanionBuilder,
          $$SyncQueueEntriesTableUpdateCompanionBuilder,
          (
            SyncQueueEntry,
            BaseReferences<
              _$AppDatabase,
              $SyncQueueEntriesTable,
              SyncQueueEntry
            >,
          ),
          SyncQueueEntry,
          PrefetchHooks Function()
        > {
  $$SyncQueueEntriesTableTableManager(
    _$AppDatabase db,
    $SyncQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueEntriesCompanion(
                id: id,
                entityType: entityType,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String payloadJson,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueEntriesCompanion.insert(
                id: id,
                entityType: entityType,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueEntriesTable,
      SyncQueueEntry,
      $$SyncQueueEntriesTableFilterComposer,
      $$SyncQueueEntriesTableOrderingComposer,
      $$SyncQueueEntriesTableAnnotationComposer,
      $$SyncQueueEntriesTableCreateCompanionBuilder,
      $$SyncQueueEntriesTableUpdateCompanionBuilder,
      (
        SyncQueueEntry,
        BaseReferences<_$AppDatabase, $SyncQueueEntriesTable, SyncQueueEntry>,
      ),
      SyncQueueEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DailyStatsEntriesTableTableManager get dailyStatsEntries =>
      $$DailyStatsEntriesTableTableManager(_db, _db.dailyStatsEntries);
  $$PenaltyEventEntriesTableTableManager get penaltyEventEntries =>
      $$PenaltyEventEntriesTableTableManager(_db, _db.penaltyEventEntries);
  $$SyncQueueEntriesTableTableManager get syncQueueEntries =>
      $$SyncQueueEntriesTableTableManager(_db, _db.syncQueueEntries);
}
