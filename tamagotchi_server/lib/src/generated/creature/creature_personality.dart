/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

/// Per-stat decay/regen modifiers, randomized at hatch and inert until S-07.
/// Stored 1:1 with the creature. Multipliers around a 1.0 baseline; the
/// randomization range (0.5-1.5) is applied in creature_service.dart, not here.
/// Love is a single-dial axis: `loveRegenMod` alone encodes the
/// introvert↔extravert sociability axis (S-04 Play derives love gain + energy
/// cost from it), so there is no `loveDecayMod`. The other three stats keep both
/// decay and regen mods for S-07.
abstract class CreaturePersonality
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  CreaturePersonality._({
    this.id,
    required this.creatureId,
    required this.hungerDecayMod,
    required this.hungerRegenMod,
    required this.energyDecayMod,
    required this.energyRegenMod,
    required this.loveRegenMod,
    required this.illnessDecayMod,
    required this.illnessRegenMod,
  });

  factory CreaturePersonality({
    _i1.UuidValue? id,
    required _i1.UuidValue creatureId,
    required double hungerDecayMod,
    required double hungerRegenMod,
    required double energyDecayMod,
    required double energyRegenMod,
    required double loveRegenMod,
    required double illnessDecayMod,
    required double illnessRegenMod,
  }) = _CreaturePersonalityImpl;

  factory CreaturePersonality.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreaturePersonality(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      creatureId: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['creatureId'],
      ),
      hungerDecayMod: (jsonSerialization['hungerDecayMod'] as num).toDouble(),
      hungerRegenMod: (jsonSerialization['hungerRegenMod'] as num).toDouble(),
      energyDecayMod: (jsonSerialization['energyDecayMod'] as num).toDouble(),
      energyRegenMod: (jsonSerialization['energyRegenMod'] as num).toDouble(),
      loveRegenMod: (jsonSerialization['loveRegenMod'] as num).toDouble(),
      illnessDecayMod: (jsonSerialization['illnessDecayMod'] as num).toDouble(),
      illnessRegenMod: (jsonSerialization['illnessRegenMod'] as num).toDouble(),
    );
  }

  static final t = CreaturePersonalityTable();

  static const db = CreaturePersonalityRepository._();

  @override
  _i1.UuidValue? id;

  /// 1:1 FK to the owning creature (unique index below enforces 1:1).
  /// Cascading FK so deleting the creature removes its personality (FR-010 reset).
  _i1.UuidValue creatureId;

  double hungerDecayMod;

  double hungerRegenMod;

  double energyDecayMod;

  double energyRegenMod;

  double loveRegenMod;

  double illnessDecayMod;

  double illnessRegenMod;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [CreaturePersonality]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreaturePersonality copyWith({
    _i1.UuidValue? id,
    _i1.UuidValue? creatureId,
    double? hungerDecayMod,
    double? hungerRegenMod,
    double? energyDecayMod,
    double? energyRegenMod,
    double? loveRegenMod,
    double? illnessDecayMod,
    double? illnessRegenMod,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreaturePersonality',
      if (id != null) 'id': id?.toJson(),
      'creatureId': creatureId.toJson(),
      'hungerDecayMod': hungerDecayMod,
      'hungerRegenMod': hungerRegenMod,
      'energyDecayMod': energyDecayMod,
      'energyRegenMod': energyRegenMod,
      'loveRegenMod': loveRegenMod,
      'illnessDecayMod': illnessDecayMod,
      'illnessRegenMod': illnessRegenMod,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CreaturePersonality',
      if (id != null) 'id': id?.toJson(),
      'creatureId': creatureId.toJson(),
      'hungerDecayMod': hungerDecayMod,
      'hungerRegenMod': hungerRegenMod,
      'energyDecayMod': energyDecayMod,
      'energyRegenMod': energyRegenMod,
      'loveRegenMod': loveRegenMod,
      'illnessDecayMod': illnessDecayMod,
      'illnessRegenMod': illnessRegenMod,
    };
  }

  static CreaturePersonalityInclude include() {
    return CreaturePersonalityInclude._();
  }

  static CreaturePersonalityIncludeList includeList({
    _i1.WhereExpressionBuilder<CreaturePersonalityTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CreaturePersonalityTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<CreaturePersonalityTable>? orderByList,
    CreaturePersonalityInclude? include,
  }) {
    return CreaturePersonalityIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CreaturePersonality.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(CreaturePersonality.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CreaturePersonalityImpl extends CreaturePersonality {
  _CreaturePersonalityImpl({
    _i1.UuidValue? id,
    required _i1.UuidValue creatureId,
    required double hungerDecayMod,
    required double hungerRegenMod,
    required double energyDecayMod,
    required double energyRegenMod,
    required double loveRegenMod,
    required double illnessDecayMod,
    required double illnessRegenMod,
  }) : super._(
         id: id,
         creatureId: creatureId,
         hungerDecayMod: hungerDecayMod,
         hungerRegenMod: hungerRegenMod,
         energyDecayMod: energyDecayMod,
         energyRegenMod: energyRegenMod,
         loveRegenMod: loveRegenMod,
         illnessDecayMod: illnessDecayMod,
         illnessRegenMod: illnessRegenMod,
       );

  /// Returns a shallow copy of this [CreaturePersonality]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreaturePersonality copyWith({
    Object? id = _Undefined,
    _i1.UuidValue? creatureId,
    double? hungerDecayMod,
    double? hungerRegenMod,
    double? energyDecayMod,
    double? energyRegenMod,
    double? loveRegenMod,
    double? illnessDecayMod,
    double? illnessRegenMod,
  }) {
    return CreaturePersonality(
      id: id is _i1.UuidValue? ? id : this.id,
      creatureId: creatureId ?? this.creatureId,
      hungerDecayMod: hungerDecayMod ?? this.hungerDecayMod,
      hungerRegenMod: hungerRegenMod ?? this.hungerRegenMod,
      energyDecayMod: energyDecayMod ?? this.energyDecayMod,
      energyRegenMod: energyRegenMod ?? this.energyRegenMod,
      loveRegenMod: loveRegenMod ?? this.loveRegenMod,
      illnessDecayMod: illnessDecayMod ?? this.illnessDecayMod,
      illnessRegenMod: illnessRegenMod ?? this.illnessRegenMod,
    );
  }
}

class CreaturePersonalityUpdateTable
    extends _i1.UpdateTable<CreaturePersonalityTable> {
  CreaturePersonalityUpdateTable(super.table);

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> creatureId(
    _i1.UuidValue value,
  ) => _i1.ColumnValue(
    table.creatureId,
    value,
  );

  _i1.ColumnValue<double, double> hungerDecayMod(double value) =>
      _i1.ColumnValue(
        table.hungerDecayMod,
        value,
      );

  _i1.ColumnValue<double, double> hungerRegenMod(double value) =>
      _i1.ColumnValue(
        table.hungerRegenMod,
        value,
      );

  _i1.ColumnValue<double, double> energyDecayMod(double value) =>
      _i1.ColumnValue(
        table.energyDecayMod,
        value,
      );

  _i1.ColumnValue<double, double> energyRegenMod(double value) =>
      _i1.ColumnValue(
        table.energyRegenMod,
        value,
      );

  _i1.ColumnValue<double, double> loveRegenMod(double value) => _i1.ColumnValue(
    table.loveRegenMod,
    value,
  );

  _i1.ColumnValue<double, double> illnessDecayMod(double value) =>
      _i1.ColumnValue(
        table.illnessDecayMod,
        value,
      );

  _i1.ColumnValue<double, double> illnessRegenMod(double value) =>
      _i1.ColumnValue(
        table.illnessRegenMod,
        value,
      );
}

class CreaturePersonalityTable extends _i1.Table<_i1.UuidValue?> {
  CreaturePersonalityTable({super.tableRelation})
    : super(tableName: 'creature_personality') {
    updateTable = CreaturePersonalityUpdateTable(this);
    creatureId = _i1.ColumnUuid(
      'creatureId',
      this,
    );
    hungerDecayMod = _i1.ColumnDouble(
      'hungerDecayMod',
      this,
    );
    hungerRegenMod = _i1.ColumnDouble(
      'hungerRegenMod',
      this,
    );
    energyDecayMod = _i1.ColumnDouble(
      'energyDecayMod',
      this,
    );
    energyRegenMod = _i1.ColumnDouble(
      'energyRegenMod',
      this,
    );
    loveRegenMod = _i1.ColumnDouble(
      'loveRegenMod',
      this,
    );
    illnessDecayMod = _i1.ColumnDouble(
      'illnessDecayMod',
      this,
    );
    illnessRegenMod = _i1.ColumnDouble(
      'illnessRegenMod',
      this,
    );
  }

  late final CreaturePersonalityUpdateTable updateTable;

  /// 1:1 FK to the owning creature (unique index below enforces 1:1).
  /// Cascading FK so deleting the creature removes its personality (FR-010 reset).
  late final _i1.ColumnUuid creatureId;

  late final _i1.ColumnDouble hungerDecayMod;

  late final _i1.ColumnDouble hungerRegenMod;

  late final _i1.ColumnDouble energyDecayMod;

  late final _i1.ColumnDouble energyRegenMod;

  late final _i1.ColumnDouble loveRegenMod;

  late final _i1.ColumnDouble illnessDecayMod;

  late final _i1.ColumnDouble illnessRegenMod;

  @override
  List<_i1.Column> get columns => [
    id,
    creatureId,
    hungerDecayMod,
    hungerRegenMod,
    energyDecayMod,
    energyRegenMod,
    loveRegenMod,
    illnessDecayMod,
    illnessRegenMod,
  ];
}

class CreaturePersonalityInclude extends _i1.IncludeObject {
  CreaturePersonalityInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<_i1.UuidValue?> get table => CreaturePersonality.t;
}

class CreaturePersonalityIncludeList extends _i1.IncludeList {
  CreaturePersonalityIncludeList._({
    _i1.WhereExpressionBuilder<CreaturePersonalityTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CreaturePersonality.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => CreaturePersonality.t;
}

class CreaturePersonalityRepository {
  const CreaturePersonalityRepository._();

  /// Returns a list of [CreaturePersonality]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<CreaturePersonality>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CreaturePersonalityTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CreaturePersonalityTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<CreaturePersonalityTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CreaturePersonality>(
      where: where?.call(CreaturePersonality.t),
      orderBy: orderBy?.call(CreaturePersonality.t),
      orderByList: orderByList?.call(CreaturePersonality.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CreaturePersonality] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<CreaturePersonality?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CreaturePersonalityTable>? where,
    int? offset,
    _i1.OrderByBuilder<CreaturePersonalityTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<CreaturePersonalityTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CreaturePersonality>(
      where: where?.call(CreaturePersonality.t),
      orderBy: orderBy?.call(CreaturePersonality.t),
      orderByList: orderByList?.call(CreaturePersonality.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CreaturePersonality] by its [id] or null if no such row exists.
  Future<CreaturePersonality?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CreaturePersonality>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CreaturePersonality]s in the list and returns the inserted rows.
  ///
  /// The returned [CreaturePersonality]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<CreaturePersonality>> insert(
    _i1.DatabaseSession session,
    List<CreaturePersonality> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<CreaturePersonality>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [CreaturePersonality] and returns the inserted row.
  ///
  /// The returned [CreaturePersonality] will have its `id` field set.
  Future<CreaturePersonality> insertRow(
    _i1.DatabaseSession session,
    CreaturePersonality row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<CreaturePersonality>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [CreaturePersonality]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<CreaturePersonality>> update(
    _i1.DatabaseSession session,
    List<CreaturePersonality> rows, {
    _i1.ColumnSelections<CreaturePersonalityTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<CreaturePersonality>(
      rows,
      columns: columns?.call(CreaturePersonality.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CreaturePersonality]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CreaturePersonality> updateRow(
    _i1.DatabaseSession session,
    CreaturePersonality row, {
    _i1.ColumnSelections<CreaturePersonalityTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<CreaturePersonality>(
      row,
      columns: columns?.call(CreaturePersonality.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CreaturePersonality] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CreaturePersonality?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<CreaturePersonalityUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<CreaturePersonality>(
      id,
      columnValues: columnValues(CreaturePersonality.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CreaturePersonality]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<CreaturePersonality>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CreaturePersonalityUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<CreaturePersonalityTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CreaturePersonalityTable>? orderBy,
    _i1.OrderByListBuilder<CreaturePersonalityTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<CreaturePersonality>(
      columnValues: columnValues(CreaturePersonality.t.updateTable),
      where: where(CreaturePersonality.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CreaturePersonality.t),
      orderByList: orderByList?.call(CreaturePersonality.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [CreaturePersonality]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<CreaturePersonality>> delete(
    _i1.DatabaseSession session,
    List<CreaturePersonality> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<CreaturePersonality>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [CreaturePersonality].
  Future<CreaturePersonality> deleteRow(
    _i1.DatabaseSession session,
    CreaturePersonality row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CreaturePersonality>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<CreaturePersonality>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CreaturePersonalityTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<CreaturePersonality>(
      where: where(CreaturePersonality.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CreaturePersonalityTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CreaturePersonality>(
      where: where?.call(CreaturePersonality.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CreaturePersonality] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CreaturePersonalityTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CreaturePersonality>(
      where: where(CreaturePersonality.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
