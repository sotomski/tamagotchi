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
import '../creature/creature_cure_error_reason.dart' as _i2;

/// Typed, client-visible failure for the only genuine Cure error path: curing
/// when the caller owns no creature. Curing never refuses (it is deterministic
/// and always available regardless of energy, FR-006), so this is the single
/// failure surface. Mirrors CreaturePlayError so the Flutter client switches on
/// [reason] instead of parsing a message string.
abstract class CreatureCureError
    implements
        _i1.SerializableException,
        _i1.SerializableModel,
        _i1.ProtocolSerialization {
  CreatureCureError._({required this.reason});

  factory CreatureCureError({required _i2.CreatureCureErrorReason reason}) =
      _CreatureCureErrorImpl;

  factory CreatureCureError.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreatureCureError(
      reason: _i2.CreatureCureErrorReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  _i2.CreatureCureErrorReason reason;

  /// Returns a shallow copy of this [CreatureCureError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreatureCureError copyWith({_i2.CreatureCureErrorReason? reason});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreatureCureError',
      'reason': reason.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CreatureCureError',
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'CreatureCureError(reason: $reason)';
  }
}

class _CreatureCureErrorImpl extends CreatureCureError {
  _CreatureCureErrorImpl({required _i2.CreatureCureErrorReason reason})
    : super._(reason: reason);

  /// Returns a shallow copy of this [CreatureCureError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreatureCureError copyWith({_i2.CreatureCureErrorReason? reason}) {
    return CreatureCureError(reason: reason ?? this.reason);
  }
}
