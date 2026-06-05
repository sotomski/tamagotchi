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
import 'package:serverpod/protocol.dart' as _i2;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i3;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i4;
import 'creature/creature.dart' as _i5;
import 'creature/creature_errors.dart' as _i6;
import 'creature/creature_feed_error.dart' as _i7;
import 'creature/creature_feed_error_reason.dart' as _i8;
import 'creature/creature_hatch_error_reason.dart' as _i9;
import 'creature/creature_mood.dart' as _i10;
import 'creature/creature_personality.dart' as _i11;
import 'creature/creature_status.dart' as _i12;
import 'creature/feed_result.dart' as _i13;
import 'creature/journal_entry.dart' as _i14;
import 'creature/journal_event.dart' as _i15;
import 'creature/stat_delta.dart' as _i16;
import 'greetings/greeting.dart' as _i17;
export 'creature/creature.dart';
export 'creature/creature_errors.dart';
export 'creature/creature_feed_error.dart';
export 'creature/creature_feed_error_reason.dart';
export 'creature/creature_hatch_error_reason.dart';
export 'creature/creature_mood.dart';
export 'creature/creature_personality.dart';
export 'creature/creature_status.dart';
export 'creature/feed_result.dart';
export 'creature/journal_entry.dart';
export 'creature/journal_event.dart';
export 'creature/stat_delta.dart';
export 'greetings/greeting.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'creature',
      dartName: 'Creature',
      schema: 'public',
      module: 'tamagotchi',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'gen_random_uuid_v7()',
        ),
        _i2.ColumnDefinition(
          name: 'ownerUuid',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'hunger',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'energy',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'love',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'illness',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'hatchedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'creature_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'creature_owner_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'ownerUuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'creature_personality',
      dartName: 'CreaturePersonality',
      schema: 'public',
      module: 'tamagotchi',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'gen_random_uuid_v7()',
        ),
        _i2.ColumnDefinition(
          name: 'creatureId',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'hungerDecayMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'hungerRegenMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'energyDecayMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'energyRegenMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'loveDecayMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'loveRegenMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'illnessDecayMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'illnessRegenMod',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'creature_personality_fk_0',
          columns: ['creatureId'],
          referenceTable: 'creature',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'creature_personality_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'creature_personality_creature_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'creatureId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'journal_entry',
      dartName: 'JournalEntry',
      schema: 'public',
      module: 'tamagotchi',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'gen_random_uuid_v7()',
        ),
        _i2.ColumnDefinition(
          name: 'creatureId',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'ownerUuid',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'timestamp',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
        _i2.ColumnDefinition(
          name: 'event',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:JournalEvent',
        ),
        _i2.ColumnDefinition(
          name: 'prose',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'\'::text',
        ),
        _i2.ColumnDefinition(
          name: 'statDelta',
          columnType: _i2.ColumnType.json,
          isNullable: true,
          dartType: 'protocol:StatDelta?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'journal_entry_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'journal_entry_creature_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'creatureId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._i3.Protocol.targetTableDefinitions,
    ..._i4.Protocol.targetTableDefinitions,
    ..._i2.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i5.Creature) {
      return _i5.Creature.fromJson(data) as T;
    }
    if (t == _i6.CreatureHatchError) {
      return _i6.CreatureHatchError.fromJson(data) as T;
    }
    if (t == _i7.CreatureFeedError) {
      return _i7.CreatureFeedError.fromJson(data) as T;
    }
    if (t == _i8.CreatureFeedErrorReason) {
      return _i8.CreatureFeedErrorReason.fromJson(data) as T;
    }
    if (t == _i9.CreatureHatchErrorReason) {
      return _i9.CreatureHatchErrorReason.fromJson(data) as T;
    }
    if (t == _i10.CreatureMood) {
      return _i10.CreatureMood.fromJson(data) as T;
    }
    if (t == _i11.CreaturePersonality) {
      return _i11.CreaturePersonality.fromJson(data) as T;
    }
    if (t == _i12.CreatureStatus) {
      return _i12.CreatureStatus.fromJson(data) as T;
    }
    if (t == _i13.FeedResult) {
      return _i13.FeedResult.fromJson(data) as T;
    }
    if (t == _i14.JournalEntry) {
      return _i14.JournalEntry.fromJson(data) as T;
    }
    if (t == _i15.JournalEvent) {
      return _i15.JournalEvent.fromJson(data) as T;
    }
    if (t == _i16.StatDelta) {
      return _i16.StatDelta.fromJson(data) as T;
    }
    if (t == _i17.Greeting) {
      return _i17.Greeting.fromJson(data) as T;
    }
    if (t == _i1.getType<_i5.Creature?>()) {
      return (data != null ? _i5.Creature.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.CreatureHatchError?>()) {
      return (data != null ? _i6.CreatureHatchError.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.CreatureFeedError?>()) {
      return (data != null ? _i7.CreatureFeedError.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.CreatureFeedErrorReason?>()) {
      return (data != null ? _i8.CreatureFeedErrorReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.CreatureHatchErrorReason?>()) {
      return (data != null ? _i9.CreatureHatchErrorReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i10.CreatureMood?>()) {
      return (data != null ? _i10.CreatureMood.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.CreaturePersonality?>()) {
      return (data != null ? _i11.CreaturePersonality.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i12.CreatureStatus?>()) {
      return (data != null ? _i12.CreatureStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.FeedResult?>()) {
      return (data != null ? _i13.FeedResult.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.JournalEntry?>()) {
      return (data != null ? _i14.JournalEntry.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.JournalEvent?>()) {
      return (data != null ? _i15.JournalEvent.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.StatDelta?>()) {
      return (data != null ? _i16.StatDelta.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i17.Greeting?>()) {
      return (data != null ? _i17.Greeting.fromJson(data) : null) as T;
    }
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i4.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i5.Creature => 'Creature',
      _i6.CreatureHatchError => 'CreatureHatchError',
      _i7.CreatureFeedError => 'CreatureFeedError',
      _i8.CreatureFeedErrorReason => 'CreatureFeedErrorReason',
      _i9.CreatureHatchErrorReason => 'CreatureHatchErrorReason',
      _i10.CreatureMood => 'CreatureMood',
      _i11.CreaturePersonality => 'CreaturePersonality',
      _i12.CreatureStatus => 'CreatureStatus',
      _i13.FeedResult => 'FeedResult',
      _i14.JournalEntry => 'JournalEntry',
      _i15.JournalEvent => 'JournalEvent',
      _i16.StatDelta => 'StatDelta',
      _i17.Greeting => 'Greeting',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('tamagotchi.', '');
    }

    switch (data) {
      case _i5.Creature():
        return 'Creature';
      case _i6.CreatureHatchError():
        return 'CreatureHatchError';
      case _i7.CreatureFeedError():
        return 'CreatureFeedError';
      case _i8.CreatureFeedErrorReason():
        return 'CreatureFeedErrorReason';
      case _i9.CreatureHatchErrorReason():
        return 'CreatureHatchErrorReason';
      case _i10.CreatureMood():
        return 'CreatureMood';
      case _i11.CreaturePersonality():
        return 'CreaturePersonality';
      case _i12.CreatureStatus():
        return 'CreatureStatus';
      case _i13.FeedResult():
        return 'FeedResult';
      case _i14.JournalEntry():
        return 'JournalEntry';
      case _i15.JournalEvent():
        return 'JournalEvent';
      case _i16.StatDelta():
        return 'StatDelta';
      case _i17.Greeting():
        return 'Greeting';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i4.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'Creature') {
      return deserialize<_i5.Creature>(data['data']);
    }
    if (dataClassName == 'CreatureHatchError') {
      return deserialize<_i6.CreatureHatchError>(data['data']);
    }
    if (dataClassName == 'CreatureFeedError') {
      return deserialize<_i7.CreatureFeedError>(data['data']);
    }
    if (dataClassName == 'CreatureFeedErrorReason') {
      return deserialize<_i8.CreatureFeedErrorReason>(data['data']);
    }
    if (dataClassName == 'CreatureHatchErrorReason') {
      return deserialize<_i9.CreatureHatchErrorReason>(data['data']);
    }
    if (dataClassName == 'CreatureMood') {
      return deserialize<_i10.CreatureMood>(data['data']);
    }
    if (dataClassName == 'CreaturePersonality') {
      return deserialize<_i11.CreaturePersonality>(data['data']);
    }
    if (dataClassName == 'CreatureStatus') {
      return deserialize<_i12.CreatureStatus>(data['data']);
    }
    if (dataClassName == 'FeedResult') {
      return deserialize<_i13.FeedResult>(data['data']);
    }
    if (dataClassName == 'JournalEntry') {
      return deserialize<_i14.JournalEntry>(data['data']);
    }
    if (dataClassName == 'JournalEvent') {
      return deserialize<_i15.JournalEvent>(data['data']);
    }
    if (dataClassName == 'StatDelta') {
      return deserialize<_i16.StatDelta>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i17.Greeting>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i3.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i4.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i3.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i4.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i5.Creature:
        return _i5.Creature.t;
      case _i11.CreaturePersonality:
        return _i11.CreaturePersonality.t;
      case _i14.JournalEntry:
        return _i14.JournalEntry.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'tamagotchi';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i3.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i4.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
