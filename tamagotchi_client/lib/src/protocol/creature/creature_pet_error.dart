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
import '../creature/creature_pet_error_reason.dart' as _i2;

/// Typed, client-visible failure for the only genuine Pet error path: petting
/// when the caller owns no creature. Pet never refuses (it is deterministic), so
/// this is the single failure surface. Mirrors CreatureFeedError so the Flutter
/// client switches on [reason] instead of parsing a message string.
abstract class CreaturePetError
    implements _i1.SerializableException, _i1.SerializableModel {
  CreaturePetError._({required this.reason});

  factory CreaturePetError({required _i2.CreaturePetErrorReason reason}) =
      _CreaturePetErrorImpl;

  factory CreaturePetError.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreaturePetError(
      reason: _i2.CreaturePetErrorReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  _i2.CreaturePetErrorReason reason;

  /// Returns a shallow copy of this [CreaturePetError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreaturePetError copyWith({_i2.CreaturePetErrorReason? reason});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreaturePetError',
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'CreaturePetError(reason: $reason)';
  }
}

class _CreaturePetErrorImpl extends CreaturePetError {
  _CreaturePetErrorImpl({required _i2.CreaturePetErrorReason reason})
    : super._(reason: reason);

  /// Returns a shallow copy of this [CreaturePetError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreaturePetError copyWith({_i2.CreaturePetErrorReason? reason}) {
    return CreaturePetError(reason: reason ?? this.reason);
  }
}
