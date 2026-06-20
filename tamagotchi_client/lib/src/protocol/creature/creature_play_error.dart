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
import '../creature/creature_play_error_reason.dart' as _i2;

/// Typed, client-visible failure for the only genuine Play error path: playing
/// when the caller owns no creature. Playing never refuses (it is
/// deterministic), so this is the single failure surface. Mirrors
/// CreatureFeedError so the Flutter client switches on [reason] instead of
/// parsing a message string.
abstract class CreaturePlayError
    implements _i1.SerializableException, _i1.SerializableModel {
  CreaturePlayError._({required this.reason});

  factory CreaturePlayError({required _i2.CreaturePlayErrorReason reason}) =
      _CreaturePlayErrorImpl;

  factory CreaturePlayError.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreaturePlayError(
      reason: _i2.CreaturePlayErrorReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  _i2.CreaturePlayErrorReason reason;

  /// Returns a shallow copy of this [CreaturePlayError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreaturePlayError copyWith({_i2.CreaturePlayErrorReason? reason});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreaturePlayError',
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'CreaturePlayError(reason: $reason)';
  }
}

class _CreaturePlayErrorImpl extends CreaturePlayError {
  _CreaturePlayErrorImpl({required _i2.CreaturePlayErrorReason reason})
    : super._(reason: reason);

  /// Returns a shallow copy of this [CreaturePlayError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreaturePlayError copyWith({_i2.CreaturePlayErrorReason? reason}) {
    return CreaturePlayError(reason: reason ?? this.reason);
  }
}
