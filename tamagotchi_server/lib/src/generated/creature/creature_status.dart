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
import '../creature/creature.dart' as _i2;
import '../creature/creature_mood.dart' as _i3;
import 'package:tamagotchi_server/src/generated/protocol.dart' as _i4;

/// The hatch/myCreature return type: a creature bundled with its derived mood.
/// Non-table serializable — mood is computed on read, never persisted.
abstract class CreatureStatus
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  CreatureStatus._({
    required this.creature,
    required this.mood,
    required this.canFeed,
    required this.canPlay,
  });

  factory CreatureStatus({
    required _i2.Creature creature,
    required _i3.CreatureMood mood,
    required bool canFeed,
    required bool canPlay,
  }) = _CreatureStatusImpl;

  factory CreatureStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreatureStatus(
      creature: _i4.Protocol().deserialize<_i2.Creature>(
        jsonSerialization['creature'],
      ),
      mood: _i3.CreatureMood.fromJson((jsonSerialization['mood'] as String)),
      canFeed: _i1.BoolJsonExtension.fromJson(jsonSerialization['canFeed']),
      canPlay: _i1.BoolJsonExtension.fromJson(jsonSerialization['canPlay']),
    );
  }

  _i2.Creature creature;

  _i3.CreatureMood mood;

  /// Whether the creature can currently afford a Feed (energy >= feedEnergyCost).
  /// Lets the client disable an unaffordable Feed button without knowing the cost.
  bool canFeed;

  /// Whether the creature can currently afford a Play (energy >=
  /// playEnergyCost(loveRegenMod)). The Play cost is personality-derived, so the
  /// client cannot compute affordability itself — the server reports it.
  bool canPlay;

  /// Returns a shallow copy of this [CreatureStatus]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreatureStatus copyWith({
    _i2.Creature? creature,
    _i3.CreatureMood? mood,
    bool? canFeed,
    bool? canPlay,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreatureStatus',
      'creature': creature.toJson(),
      'mood': mood.toJson(),
      'canFeed': canFeed,
      'canPlay': canPlay,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CreatureStatus',
      'creature': creature.toJsonForProtocol(),
      'mood': mood.toJson(),
      'canFeed': canFeed,
      'canPlay': canPlay,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _CreatureStatusImpl extends CreatureStatus {
  _CreatureStatusImpl({
    required _i2.Creature creature,
    required _i3.CreatureMood mood,
    required bool canFeed,
    required bool canPlay,
  }) : super._(
         creature: creature,
         mood: mood,
         canFeed: canFeed,
         canPlay: canPlay,
       );

  /// Returns a shallow copy of this [CreatureStatus]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreatureStatus copyWith({
    _i2.Creature? creature,
    _i3.CreatureMood? mood,
    bool? canFeed,
    bool? canPlay,
  }) {
    return CreatureStatus(
      creature: creature ?? this.creature.copyWith(),
      mood: mood ?? this.mood,
      canFeed: canFeed ?? this.canFeed,
      canPlay: canPlay ?? this.canPlay,
    );
  }
}
