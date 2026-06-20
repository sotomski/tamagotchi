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
import 'creature/creature_feed_error.dart' as _i4;
import 'creature/creature_feed_error_reason.dart' as _i5;
import 'creature/creature_hatch_error_reason.dart' as _i6;
import 'creature/creature_mood.dart' as _i7;
import 'creature/creature_personality.dart' as _i8;
import 'creature/creature_play_error.dart' as _i9;
import 'creature/creature_play_error_reason.dart' as _i10;
import 'creature/creature_status.dart' as _i11;
import 'creature/feed_result.dart' as _i12;
import 'creature/journal_entry.dart' as _i13;
import 'creature/journal_event.dart' as _i14;
import 'creature/play_result.dart' as _i15;
import 'creature/stat_delta.dart' as _i16;
import 'greetings/greeting.dart' as _i17;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i18;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i19;
export 'creature/creature.dart';
export 'creature/creature_errors.dart';
export 'creature/creature_feed_error.dart';
export 'creature/creature_feed_error_reason.dart';
export 'creature/creature_hatch_error_reason.dart';
export 'creature/creature_mood.dart';
export 'creature/creature_personality.dart';
export 'creature/creature_play_error.dart';
export 'creature/creature_play_error_reason.dart';
export 'creature/creature_status.dart';
export 'creature/feed_result.dart';
export 'creature/journal_entry.dart';
export 'creature/journal_event.dart';
export 'creature/play_result.dart';
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
    if (t == _i4.CreatureFeedError) {
      return _i4.CreatureFeedError.fromJson(data) as T;
    }
    if (t == _i5.CreatureFeedErrorReason) {
      return _i5.CreatureFeedErrorReason.fromJson(data) as T;
    }
    if (t == _i6.CreatureHatchErrorReason) {
      return _i6.CreatureHatchErrorReason.fromJson(data) as T;
    }
    if (t == _i7.CreatureMood) {
      return _i7.CreatureMood.fromJson(data) as T;
    }
    if (t == _i8.CreaturePersonality) {
      return _i8.CreaturePersonality.fromJson(data) as T;
    }
    if (t == _i9.CreaturePlayError) {
      return _i9.CreaturePlayError.fromJson(data) as T;
    }
    if (t == _i10.CreaturePlayErrorReason) {
      return _i10.CreaturePlayErrorReason.fromJson(data) as T;
    }
    if (t == _i11.CreatureStatus) {
      return _i11.CreatureStatus.fromJson(data) as T;
    }
    if (t == _i12.FeedResult) {
      return _i12.FeedResult.fromJson(data) as T;
    }
    if (t == _i13.JournalEntry) {
      return _i13.JournalEntry.fromJson(data) as T;
    }
    if (t == _i14.JournalEvent) {
      return _i14.JournalEvent.fromJson(data) as T;
    }
    if (t == _i15.PlayResult) {
      return _i15.PlayResult.fromJson(data) as T;
    }
    if (t == _i16.StatDelta) {
      return _i16.StatDelta.fromJson(data) as T;
    }
    if (t == _i17.Greeting) {
      return _i17.Greeting.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.Creature?>()) {
      return (data != null ? _i2.Creature.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.CreatureHatchError?>()) {
      return (data != null ? _i3.CreatureHatchError.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.CreatureFeedError?>()) {
      return (data != null ? _i4.CreatureFeedError.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.CreatureFeedErrorReason?>()) {
      return (data != null ? _i5.CreatureFeedErrorReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.CreatureHatchErrorReason?>()) {
      return (data != null ? _i6.CreatureHatchErrorReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i7.CreatureMood?>()) {
      return (data != null ? _i7.CreatureMood.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.CreaturePersonality?>()) {
      return (data != null ? _i8.CreaturePersonality.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.CreaturePlayError?>()) {
      return (data != null ? _i9.CreaturePlayError.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.CreaturePlayErrorReason?>()) {
      return (data != null ? _i10.CreaturePlayErrorReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i11.CreatureStatus?>()) {
      return (data != null ? _i11.CreatureStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.FeedResult?>()) {
      return (data != null ? _i12.FeedResult.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.JournalEntry?>()) {
      return (data != null ? _i13.JournalEntry.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.JournalEvent?>()) {
      return (data != null ? _i14.JournalEvent.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.PlayResult?>()) {
      return (data != null ? _i15.PlayResult.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.StatDelta?>()) {
      return (data != null ? _i16.StatDelta.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i17.Greeting?>()) {
      return (data != null ? _i17.Greeting.fromJson(data) : null) as T;
    }
    try {
      return _i18.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i19.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.Creature => 'Creature',
      _i3.CreatureHatchError => 'CreatureHatchError',
      _i4.CreatureFeedError => 'CreatureFeedError',
      _i5.CreatureFeedErrorReason => 'CreatureFeedErrorReason',
      _i6.CreatureHatchErrorReason => 'CreatureHatchErrorReason',
      _i7.CreatureMood => 'CreatureMood',
      _i8.CreaturePersonality => 'CreaturePersonality',
      _i9.CreaturePlayError => 'CreaturePlayError',
      _i10.CreaturePlayErrorReason => 'CreaturePlayErrorReason',
      _i11.CreatureStatus => 'CreatureStatus',
      _i12.FeedResult => 'FeedResult',
      _i13.JournalEntry => 'JournalEntry',
      _i14.JournalEvent => 'JournalEvent',
      _i15.PlayResult => 'PlayResult',
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
      case _i2.Creature():
        return 'Creature';
      case _i3.CreatureHatchError():
        return 'CreatureHatchError';
      case _i4.CreatureFeedError():
        return 'CreatureFeedError';
      case _i5.CreatureFeedErrorReason():
        return 'CreatureFeedErrorReason';
      case _i6.CreatureHatchErrorReason():
        return 'CreatureHatchErrorReason';
      case _i7.CreatureMood():
        return 'CreatureMood';
      case _i8.CreaturePersonality():
        return 'CreaturePersonality';
      case _i9.CreaturePlayError():
        return 'CreaturePlayError';
      case _i10.CreaturePlayErrorReason():
        return 'CreaturePlayErrorReason';
      case _i11.CreatureStatus():
        return 'CreatureStatus';
      case _i12.FeedResult():
        return 'FeedResult';
      case _i13.JournalEntry():
        return 'JournalEntry';
      case _i14.JournalEvent():
        return 'JournalEvent';
      case _i15.PlayResult():
        return 'PlayResult';
      case _i16.StatDelta():
        return 'StatDelta';
      case _i17.Greeting():
        return 'Greeting';
    }
    className = _i18.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i19.Protocol().getClassNameForObject(data);
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
    if (dataClassName == 'CreatureFeedError') {
      return deserialize<_i4.CreatureFeedError>(data['data']);
    }
    if (dataClassName == 'CreatureFeedErrorReason') {
      return deserialize<_i5.CreatureFeedErrorReason>(data['data']);
    }
    if (dataClassName == 'CreatureHatchErrorReason') {
      return deserialize<_i6.CreatureHatchErrorReason>(data['data']);
    }
    if (dataClassName == 'CreatureMood') {
      return deserialize<_i7.CreatureMood>(data['data']);
    }
    if (dataClassName == 'CreaturePersonality') {
      return deserialize<_i8.CreaturePersonality>(data['data']);
    }
    if (dataClassName == 'CreaturePlayError') {
      return deserialize<_i9.CreaturePlayError>(data['data']);
    }
    if (dataClassName == 'CreaturePlayErrorReason') {
      return deserialize<_i10.CreaturePlayErrorReason>(data['data']);
    }
    if (dataClassName == 'CreatureStatus') {
      return deserialize<_i11.CreatureStatus>(data['data']);
    }
    if (dataClassName == 'FeedResult') {
      return deserialize<_i12.FeedResult>(data['data']);
    }
    if (dataClassName == 'JournalEntry') {
      return deserialize<_i13.JournalEntry>(data['data']);
    }
    if (dataClassName == 'JournalEvent') {
      return deserialize<_i14.JournalEvent>(data['data']);
    }
    if (dataClassName == 'PlayResult') {
      return deserialize<_i15.PlayResult>(data['data']);
    }
    if (dataClassName == 'StatDelta') {
      return deserialize<_i16.StatDelta>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i17.Greeting>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i18.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i19.Protocol().deserializeByClassName(data);
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
      return _i18.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i19.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
