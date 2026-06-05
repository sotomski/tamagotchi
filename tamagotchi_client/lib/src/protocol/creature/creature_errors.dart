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
import '../creature/creature_hatch_error_reason.dart' as _i2;

/// Typed, client-visible failure for the two rejected hatch paths. Thrown from
/// CreatureEndpoint.hatch; the Flutter client switches on [reason] to render an
/// inline message.
abstract class CreatureHatchError
    implements _i1.SerializableException, _i1.SerializableModel {
  CreatureHatchError._({required this.reason});

  factory CreatureHatchError({required _i2.CreatureHatchErrorReason reason}) =
      _CreatureHatchErrorImpl;

  factory CreatureHatchError.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreatureHatchError(
      reason: _i2.CreatureHatchErrorReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  _i2.CreatureHatchErrorReason reason;

  /// Returns a shallow copy of this [CreatureHatchError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreatureHatchError copyWith({_i2.CreatureHatchErrorReason? reason});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreatureHatchError',
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'CreatureHatchError(reason: $reason)';
  }
}

class _CreatureHatchErrorImpl extends CreatureHatchError {
  _CreatureHatchErrorImpl({required _i2.CreatureHatchErrorReason reason})
    : super._(reason: reason);

  /// Returns a shallow copy of this [CreatureHatchError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreatureHatchError copyWith({_i2.CreatureHatchErrorReason? reason}) {
    return CreatureHatchError(reason: reason ?? this.reason);
  }
}
