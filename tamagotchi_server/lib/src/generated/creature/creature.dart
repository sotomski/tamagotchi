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

/// The core persisted creature, owned by the auth user. Stats are fixed at the
/// baseline at hatch (S-02 has no decay/regen); personality lives in a 1:1 table.
abstract class Creature
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  Creature._({
    this.id,
    required this.ownerUuid,
    required this.name,
    required this.hunger,
    required this.energy,
    required this.love,
    required this.illness,
    DateTime? hatchedAt,
    DateTime? lastDecayedAt,
  }) : hatchedAt = hatchedAt ?? DateTime.now(),
       lastDecayedAt = lastDecayedAt ?? DateTime.now();

  factory Creature({
    _i1.UuidValue? id,
    required _i1.UuidValue ownerUuid,
    required String name,
    required int hunger,
    required int energy,
    required int love,
    required int illness,
    DateTime? hatchedAt,
    DateTime? lastDecayedAt,
  }) = _CreatureImpl;

  factory Creature.fromJson(Map<String, dynamic> jsonSerialization) {
    return Creature(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      ownerUuid: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerUuid'],
      ),
      name: jsonSerialization['name'] as String,
      hunger: jsonSerialization['hunger'] as int,
      energy: jsonSerialization['energy'] as int,
      love: jsonSerialization['love'] as int,
      illness: jsonSerialization['illness'] as int,
      hatchedAt: jsonSerialization['hatchedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['hatchedAt']),
      lastDecayedAt: jsonSerialization['lastDecayedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastDecayedAt'],
            ),
    );
  }

  static final t = CreatureTable();

  static const db = CreatureRepository._();

  @override
  _i1.UuidValue? id;

  /// The owning auth user, stored as a bare scalar (no cross-module FK).
  _i1.UuidValue ownerUuid;

  /// The creature's display name, chosen at hatch.
  String name;

  /// Hunger on a 0-100 scale (higher = hungrier).
  int hunger;

  /// Energy on a 0-100 scale (higher = more rested).
  int energy;

  /// Love on a 0-100 scale (higher = more bonded).
  int love;

  /// Illness on a 0-100 scale (higher = sicker).
  int illness;

  /// When the creature was hatched.
  DateTime hatchedAt;

  /// Anchor timestamp that lazy stat decay measures elapsed time from; advanced
  /// by the real duration of whole decay ticks applied on each read/interaction.
  DateTime lastDecayedAt;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Creature]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Creature copyWith({
    _i1.UuidValue? id,
    _i1.UuidValue? ownerUuid,
    String? name,
    int? hunger,
    int? energy,
    int? love,
    int? illness,
    DateTime? hatchedAt,
    DateTime? lastDecayedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Creature',
      if (id != null) 'id': id?.toJson(),
      'ownerUuid': ownerUuid.toJson(),
      'name': name,
      'hunger': hunger,
      'energy': energy,
      'love': love,
      'illness': illness,
      'hatchedAt': hatchedAt.toJson(),
      'lastDecayedAt': lastDecayedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Creature',
      if (id != null) 'id': id?.toJson(),
      'ownerUuid': ownerUuid.toJson(),
      'name': name,
      'hunger': hunger,
      'energy': energy,
      'love': love,
      'illness': illness,
      'hatchedAt': hatchedAt.toJson(),
      'lastDecayedAt': lastDecayedAt.toJson(),
    };
  }

  static CreatureInclude include() {
    return CreatureInclude._();
  }

  static CreatureIncludeList includeList({
    _i1.WhereExpressionBuilder<CreatureTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CreatureTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<CreatureTable>? orderByList,
    CreatureInclude? include,
  }) {
    return CreatureIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Creature.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Creature.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CreatureImpl extends Creature {
  _CreatureImpl({
    _i1.UuidValue? id,
    required _i1.UuidValue ownerUuid,
    required String name,
    required int hunger,
    required int energy,
    required int love,
    required int illness,
    DateTime? hatchedAt,
    DateTime? lastDecayedAt,
  }) : super._(
         id: id,
         ownerUuid: ownerUuid,
         name: name,
         hunger: hunger,
         energy: energy,
         love: love,
         illness: illness,
         hatchedAt: hatchedAt,
         lastDecayedAt: lastDecayedAt,
       );

  /// Returns a shallow copy of this [Creature]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Creature copyWith({
    Object? id = _Undefined,
    _i1.UuidValue? ownerUuid,
    String? name,
    int? hunger,
    int? energy,
    int? love,
    int? illness,
    DateTime? hatchedAt,
    DateTime? lastDecayedAt,
  }) {
    return Creature(
      id: id is _i1.UuidValue? ? id : this.id,
      ownerUuid: ownerUuid ?? this.ownerUuid,
      name: name ?? this.name,
      hunger: hunger ?? this.hunger,
      energy: energy ?? this.energy,
      love: love ?? this.love,
      illness: illness ?? this.illness,
      hatchedAt: hatchedAt ?? this.hatchedAt,
      lastDecayedAt: lastDecayedAt ?? this.lastDecayedAt,
    );
  }
}

class CreatureUpdateTable extends _i1.UpdateTable<CreatureTable> {
  CreatureUpdateTable(super.table);

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> ownerUuid(
    _i1.UuidValue value,
  ) => _i1.ColumnValue(
    table.ownerUuid,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<int, int> hunger(int value) => _i1.ColumnValue(
    table.hunger,
    value,
  );

  _i1.ColumnValue<int, int> energy(int value) => _i1.ColumnValue(
    table.energy,
    value,
  );

  _i1.ColumnValue<int, int> love(int value) => _i1.ColumnValue(
    table.love,
    value,
  );

  _i1.ColumnValue<int, int> illness(int value) => _i1.ColumnValue(
    table.illness,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> hatchedAt(DateTime value) =>
      _i1.ColumnValue(
        table.hatchedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastDecayedAt(DateTime value) =>
      _i1.ColumnValue(
        table.lastDecayedAt,
        value,
      );
}

class CreatureTable extends _i1.Table<_i1.UuidValue?> {
  CreatureTable({super.tableRelation}) : super(tableName: 'creature') {
    updateTable = CreatureUpdateTable(this);
    ownerUuid = _i1.ColumnUuid(
      'ownerUuid',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    hunger = _i1.ColumnInt(
      'hunger',
      this,
    );
    energy = _i1.ColumnInt(
      'energy',
      this,
    );
    love = _i1.ColumnInt(
      'love',
      this,
    );
    illness = _i1.ColumnInt(
      'illness',
      this,
    );
    hatchedAt = _i1.ColumnDateTime(
      'hatchedAt',
      this,
      hasDefault: true,
    );
    lastDecayedAt = _i1.ColumnDateTime(
      'lastDecayedAt',
      this,
      hasDefault: true,
    );
  }

  late final CreatureUpdateTable updateTable;

  /// The owning auth user, stored as a bare scalar (no cross-module FK).
  late final _i1.ColumnUuid ownerUuid;

  /// The creature's display name, chosen at hatch.
  late final _i1.ColumnString name;

  /// Hunger on a 0-100 scale (higher = hungrier).
  late final _i1.ColumnInt hunger;

  /// Energy on a 0-100 scale (higher = more rested).
  late final _i1.ColumnInt energy;

  /// Love on a 0-100 scale (higher = more bonded).
  late final _i1.ColumnInt love;

  /// Illness on a 0-100 scale (higher = sicker).
  late final _i1.ColumnInt illness;

  /// When the creature was hatched.
  late final _i1.ColumnDateTime hatchedAt;

  /// Anchor timestamp that lazy stat decay measures elapsed time from; advanced
  /// by the real duration of whole decay ticks applied on each read/interaction.
  late final _i1.ColumnDateTime lastDecayedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    ownerUuid,
    name,
    hunger,
    energy,
    love,
    illness,
    hatchedAt,
    lastDecayedAt,
  ];
}

class CreatureInclude extends _i1.IncludeObject {
  CreatureInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<_i1.UuidValue?> get table => Creature.t;
}

class CreatureIncludeList extends _i1.IncludeList {
  CreatureIncludeList._({
    _i1.WhereExpressionBuilder<CreatureTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Creature.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => Creature.t;
}

class CreatureRepository {
  const CreatureRepository._();

  /// Returns a list of [Creature]s matching the given query parameters.
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
  Future<List<Creature>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CreatureTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CreatureTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<CreatureTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Creature>(
      where: where?.call(Creature.t),
      orderBy: orderBy?.call(Creature.t),
      orderByList: orderByList?.call(Creature.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Creature] matching the given query parameters.
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
  Future<Creature?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CreatureTable>? where,
    int? offset,
    _i1.OrderByBuilder<CreatureTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<CreatureTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Creature>(
      where: where?.call(Creature.t),
      orderBy: orderBy?.call(Creature.t),
      orderByList: orderByList?.call(Creature.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Creature] by its [id] or null if no such row exists.
  Future<Creature?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Creature>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Creature]s in the list and returns the inserted rows.
  ///
  /// The returned [Creature]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<Creature>> insert(
    _i1.DatabaseSession session,
    List<Creature> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<Creature>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [Creature] and returns the inserted row.
  ///
  /// The returned [Creature] will have its `id` field set.
  Future<Creature> insertRow(
    _i1.DatabaseSession session,
    Creature row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Creature>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Creature]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Creature>> update(
    _i1.DatabaseSession session,
    List<Creature> rows, {
    _i1.ColumnSelections<CreatureTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Creature>(
      rows,
      columns: columns?.call(Creature.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Creature]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Creature> updateRow(
    _i1.DatabaseSession session,
    Creature row, {
    _i1.ColumnSelections<CreatureTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Creature>(
      row,
      columns: columns?.call(Creature.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Creature] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Creature?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<CreatureUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Creature>(
      id,
      columnValues: columnValues(Creature.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Creature]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Creature>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CreatureUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<CreatureTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CreatureTable>? orderBy,
    _i1.OrderByListBuilder<CreatureTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Creature>(
      columnValues: columnValues(Creature.t.updateTable),
      where: where(Creature.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Creature.t),
      orderByList: orderByList?.call(Creature.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Creature]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Creature>> delete(
    _i1.DatabaseSession session,
    List<Creature> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Creature>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Creature].
  Future<Creature> deleteRow(
    _i1.DatabaseSession session,
    Creature row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Creature>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Creature>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CreatureTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Creature>(
      where: where(Creature.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CreatureTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Creature>(
      where: where?.call(Creature.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Creature] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CreatureTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Creature>(
      where: where(Creature.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
