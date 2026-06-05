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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'creature/creature.dart' as _i2;
import 'creature/creature_errors.dart' as _i3;
import 'creature/creature_hatch_error_reason.dart' as _i4;
import 'creature/creature_mood.dart' as _i5;
import 'creature/creature_personality.dart' as _i6;
import 'creature/creature_status.dart' as _i7;
import 'creature/journal_entry.dart' as _i8;
import 'creature/journal_event.dart' as _i9;
import 'creature/stat_delta.dart' as _i10;
import 'greetings/greeting.dart' as _i11;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i12;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i13;
export 'creature/creature.dart';
export 'creature/creature_errors.dart';
export 'creature/creature_hatch_error_reason.dart';
export 'creature/creature_mood.dart';
export 'creature/creature_personality.dart';
export 'creature/creature_status.dart';
export 'creature/journal_entry.dart';
export 'creature/journal_event.dart';
export 'creature/stat_delta.dart';
export 'greetings/greeting.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

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

    if (t == _i2.Creature) {
      return _i2.Creature.fromJson(data) as T;
    }
    if (t == _i3.CreatureHatchError) {
      return _i3.CreatureHatchError.fromJson(data) as T;
    }
    if (t == _i4.CreatureHatchErrorReason) {
      return _i4.CreatureHatchErrorReason.fromJson(data) as T;
    }
    if (t == _i5.CreatureMood) {
      return _i5.CreatureMood.fromJson(data) as T;
    }
    if (t == _i6.CreaturePersonality) {
      return _i6.CreaturePersonality.fromJson(data) as T;
    }
    if (t == _i7.CreatureStatus) {
      return _i7.CreatureStatus.fromJson(data) as T;
    }
    if (t == _i8.JournalEntry) {
      return _i8.JournalEntry.fromJson(data) as T;
    }
    if (t == _i9.JournalEvent) {
      return _i9.JournalEvent.fromJson(data) as T;
    }
    if (t == _i10.StatDelta) {
      return _i10.StatDelta.fromJson(data) as T;
    }
    if (t == _i11.Greeting) {
      return _i11.Greeting.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.Creature?>()) {
      return (data != null ? _i2.Creature.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.CreatureHatchError?>()) {
      return (data != null ? _i3.CreatureHatchError.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.CreatureHatchErrorReason?>()) {
      return (data != null ? _i4.CreatureHatchErrorReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i5.CreatureMood?>()) {
      return (data != null ? _i5.CreatureMood.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.CreaturePersonality?>()) {
      return (data != null ? _i6.CreaturePersonality.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i7.CreatureStatus?>()) {
      return (data != null ? _i7.CreatureStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.JournalEntry?>()) {
      return (data != null ? _i8.JournalEntry.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.JournalEvent?>()) {
      return (data != null ? _i9.JournalEvent.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.StatDelta?>()) {
      return (data != null ? _i10.StatDelta.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.Greeting?>()) {
      return (data != null ? _i11.Greeting.fromJson(data) : null) as T;
    }
    try {
      return _i12.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i13.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.Creature => 'Creature',
      _i3.CreatureHatchError => 'CreatureHatchError',
      _i4.CreatureHatchErrorReason => 'CreatureHatchErrorReason',
      _i5.CreatureMood => 'CreatureMood',
      _i6.CreaturePersonality => 'CreaturePersonality',
      _i7.CreatureStatus => 'CreatureStatus',
      _i8.JournalEntry => 'JournalEntry',
      _i9.JournalEvent => 'JournalEvent',
      _i10.StatDelta => 'StatDelta',
      _i11.Greeting => 'Greeting',
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
      case _i2.Creature():
        return 'Creature';
      case _i3.CreatureHatchError():
        return 'CreatureHatchError';
      case _i4.CreatureHatchErrorReason():
        return 'CreatureHatchErrorReason';
      case _i5.CreatureMood():
        return 'CreatureMood';
      case _i6.CreaturePersonality():
        return 'CreaturePersonality';
      case _i7.CreatureStatus():
        return 'CreatureStatus';
      case _i8.JournalEntry():
        return 'JournalEntry';
      case _i9.JournalEvent():
        return 'JournalEvent';
      case _i10.StatDelta():
        return 'StatDelta';
      case _i11.Greeting():
        return 'Greeting';
    }
    className = _i12.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i13.Protocol().getClassNameForObject(data);
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
      return deserialize<_i2.Creature>(data['data']);
    }
    if (dataClassName == 'CreatureHatchError') {
      return deserialize<_i3.CreatureHatchError>(data['data']);
    }
    if (dataClassName == 'CreatureHatchErrorReason') {
      return deserialize<_i4.CreatureHatchErrorReason>(data['data']);
    }
    if (dataClassName == 'CreatureMood') {
      return deserialize<_i5.CreatureMood>(data['data']);
    }
    if (dataClassName == 'CreaturePersonality') {
      return deserialize<_i6.CreaturePersonality>(data['data']);
    }
    if (dataClassName == 'CreatureStatus') {
      return deserialize<_i7.CreatureStatus>(data['data']);
    }
    if (dataClassName == 'JournalEntry') {
      return deserialize<_i8.JournalEntry>(data['data']);
    }
    if (dataClassName == 'JournalEvent') {
      return deserialize<_i9.JournalEvent>(data['data']);
    }
    if (dataClassName == 'StatDelta') {
      return deserialize<_i10.StatDelta>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i11.Greeting>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i12.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i13.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

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
      return _i12.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i13.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
