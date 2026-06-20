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

/// Per-stat decay/regen modifiers, randomized at hatch and inert until S-07.
/// Stored 1:1 with the creature. Multipliers around a 1.0 baseline; the
/// randomization range (0.5-1.5) is applied in creature_service.dart, not here.
/// Love is a single-dial axis: `loveRegenMod` alone encodes the
/// introvert↔extravert sociability axis (S-04 Play derives love gain + energy
/// cost from it), so there is no `loveDecayMod`. The other three stats keep both
/// decay and regen mods for S-07.
abstract class CreaturePersonality implements _i1.SerializableModel {
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

  /// UUID primary key.
  _i1.UuidValue? id;

  /// 1:1 FK to the owning creature (unique index below enforces 1:1).
  _i1.UuidValue creatureId;

  double hungerDecayMod;

  double hungerRegenMod;

  double energyDecayMod;

  double energyRegenMod;

  double loveRegenMod;

  double illnessDecayMod;

  double illnessRegenMod;

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
