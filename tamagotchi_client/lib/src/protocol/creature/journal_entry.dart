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
import '../creature/journal_event.dart' as _i2;
import '../creature/stat_delta.dart' as _i3;
import 'package:tamagotchi_client/src/protocol/protocol.dart' as _i4;

/// The creature's journal. Load-bearing table defined now (S-02) even though only
/// a non-narrative `hatched` marker is written here; narrative prose and stat
/// deltas arrive with S-03+. No vector column (ORQ-1: last-10 narrative entries).
abstract class JournalEntry implements _i1.SerializableModel {
  JournalEntry._({
    this.id,
    required this.creatureId,
    required this.ownerUuid,
    DateTime? timestamp,
    required this.event,
    String? prose,
    this.statDelta,
  }) : timestamp = timestamp ?? DateTime.now(),
       prose = prose ?? '';

  factory JournalEntry({
    _i1.UuidValue? id,
    required _i1.UuidValue creatureId,
    required _i1.UuidValue ownerUuid,
    DateTime? timestamp,
    required _i2.JournalEvent event,
    String? prose,
    _i3.StatDelta? statDelta,
  }) = _JournalEntryImpl;

  factory JournalEntry.fromJson(Map<String, dynamic> jsonSerialization) {
    return JournalEntry(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      creatureId: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['creatureId'],
      ),
      ownerUuid: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerUuid'],
      ),
      timestamp: jsonSerialization['timestamp'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['timestamp']),
      event: _i2.JournalEvent.fromJson((jsonSerialization['event'] as String)),
      prose: jsonSerialization['prose'] as String?,
      statDelta: jsonSerialization['statDelta'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.StatDelta>(
              jsonSerialization['statDelta'],
            ),
    );
  }

  /// UUID primary key.
  _i1.UuidValue? id;

  /// The creature this entry belongs to (many entries per creature).
  _i1.UuidValue creatureId;

  /// The owning auth user, stored directly for scoping.
  _i1.UuidValue ownerUuid;

  /// When the event occurred.
  DateTime timestamp;

  /// What kind of event this entry records.
  _i2.JournalEvent event;

  /// Narrative prose; empty for the hatched marker, populated by S-03+.
  String prose;

  /// Stat changes for this event; null for the hatched marker.
  _i3.StatDelta? statDelta;

  /// Returns a shallow copy of this [JournalEntry]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JournalEntry copyWith({
    _i1.UuidValue? id,
    _i1.UuidValue? creatureId,
    _i1.UuidValue? ownerUuid,
    DateTime? timestamp,
    _i2.JournalEvent? event,
    String? prose,
    _i3.StatDelta? statDelta,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JournalEntry',
      if (id != null) 'id': id?.toJson(),
      'creatureId': creatureId.toJson(),
      'ownerUuid': ownerUuid.toJson(),
      'timestamp': timestamp.toJson(),
      'event': event.toJson(),
      'prose': prose,
      if (statDelta != null) 'statDelta': statDelta?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _JournalEntryImpl extends JournalEntry {
  _JournalEntryImpl({
    _i1.UuidValue? id,
    required _i1.UuidValue creatureId,
    required _i1.UuidValue ownerUuid,
    DateTime? timestamp,
    required _i2.JournalEvent event,
    String? prose,
    _i3.StatDelta? statDelta,
  }) : super._(
         id: id,
         creatureId: creatureId,
         ownerUuid: ownerUuid,
         timestamp: timestamp,
         event: event,
         prose: prose,
         statDelta: statDelta,
       );

  /// Returns a shallow copy of this [JournalEntry]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JournalEntry copyWith({
    Object? id = _Undefined,
    _i1.UuidValue? creatureId,
    _i1.UuidValue? ownerUuid,
    DateTime? timestamp,
    _i2.JournalEvent? event,
    String? prose,
    Object? statDelta = _Undefined,
  }) {
    return JournalEntry(
      id: id is _i1.UuidValue? ? id : this.id,
      creatureId: creatureId ?? this.creatureId,
      ownerUuid: ownerUuid ?? this.ownerUuid,
      timestamp: timestamp ?? this.timestamp,
      event: event ?? this.event,
      prose: prose ?? this.prose,
      statDelta: statDelta is _i3.StatDelta?
          ? statDelta
          : this.statDelta?.copyWith(),
    );
  }
}
