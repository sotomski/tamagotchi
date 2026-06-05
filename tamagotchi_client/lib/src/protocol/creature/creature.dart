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

/// The core persisted creature, owned by the auth user. Stats are fixed at the
/// baseline at hatch (S-02 has no decay/regen); personality lives in a 1:1 table.
abstract class Creature implements _i1.SerializableModel {
  Creature._({
    this.id,
    required this.ownerUuid,
    required this.name,
    required this.hunger,
    required this.energy,
    required this.love,
    required this.illness,
    DateTime? hatchedAt,
  }) : hatchedAt = hatchedAt ?? DateTime.now();

  factory Creature({
    _i1.UuidValue? id,
    required _i1.UuidValue ownerUuid,
    required String name,
    required int hunger,
    required int energy,
    required int love,
    required int illness,
    DateTime? hatchedAt,
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
    );
  }

  /// UUID primary key (matches the auth-table id convention).
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
    };
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
  }) : super._(
         id: id,
         ownerUuid: ownerUuid,
         name: name,
         hunger: hunger,
         energy: energy,
         love: love,
         illness: illness,
         hatchedAt: hatchedAt,
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
    );
  }
}
