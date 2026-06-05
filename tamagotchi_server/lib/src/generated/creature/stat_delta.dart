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

/// A non-persisted bundle of per-stat changes attached to a journal entry.
/// Defined now for forward use (S-03+ populates it); null on the hatched marker.
abstract class StatDelta
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  StatDelta._({
    required this.hungerDelta,
    required this.energyDelta,
    required this.loveDelta,
    required this.illnessDelta,
  });

  factory StatDelta({
    required int hungerDelta,
    required int energyDelta,
    required int loveDelta,
    required int illnessDelta,
  }) = _StatDeltaImpl;

  factory StatDelta.fromJson(Map<String, dynamic> jsonSerialization) {
    return StatDelta(
      hungerDelta: jsonSerialization['hungerDelta'] as int,
      energyDelta: jsonSerialization['energyDelta'] as int,
      loveDelta: jsonSerialization['loveDelta'] as int,
      illnessDelta: jsonSerialization['illnessDelta'] as int,
    );
  }

  int hungerDelta;

  int energyDelta;

  int loveDelta;

  int illnessDelta;

  /// Returns a shallow copy of this [StatDelta]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  StatDelta copyWith({
    int? hungerDelta,
    int? energyDelta,
    int? loveDelta,
    int? illnessDelta,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StatDelta',
      'hungerDelta': hungerDelta,
      'energyDelta': energyDelta,
      'loveDelta': loveDelta,
      'illnessDelta': illnessDelta,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StatDelta',
      'hungerDelta': hungerDelta,
      'energyDelta': energyDelta,
      'loveDelta': loveDelta,
      'illnessDelta': illnessDelta,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _StatDeltaImpl extends StatDelta {
  _StatDeltaImpl({
    required int hungerDelta,
    required int energyDelta,
    required int loveDelta,
    required int illnessDelta,
  }) : super._(
         hungerDelta: hungerDelta,
         energyDelta: energyDelta,
         loveDelta: loveDelta,
         illnessDelta: illnessDelta,
       );

  /// Returns a shallow copy of this [StatDelta]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  StatDelta copyWith({
    int? hungerDelta,
    int? energyDelta,
    int? loveDelta,
    int? illnessDelta,
  }) {
    return StatDelta(
      hungerDelta: hungerDelta ?? this.hungerDelta,
      energyDelta: energyDelta ?? this.energyDelta,
      loveDelta: loveDelta ?? this.loveDelta,
      illnessDelta: illnessDelta ?? this.illnessDelta,
    );
  }
}
