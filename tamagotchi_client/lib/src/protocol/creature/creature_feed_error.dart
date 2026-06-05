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
import '../creature/creature_feed_error_reason.dart' as _i2;

/// Typed, client-visible failure for the only genuine Feed error path: feeding
/// when the caller owns no creature. Refusals are NOT errors — they ride
/// FeedResult.accepted=false. Mirrors CreatureHatchError so the Flutter client
/// switches on [reason] instead of parsing a message string.
abstract class CreatureFeedError
    implements _i1.SerializableException, _i1.SerializableModel {
  CreatureFeedError._({required this.reason});

  factory CreatureFeedError({required _i2.CreatureFeedErrorReason reason}) =
      _CreatureFeedErrorImpl;

  factory CreatureFeedError.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreatureFeedError(
      reason: _i2.CreatureFeedErrorReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  _i2.CreatureFeedErrorReason reason;

  /// Returns a shallow copy of this [CreatureFeedError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreatureFeedError copyWith({_i2.CreatureFeedErrorReason? reason});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreatureFeedError',
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'CreatureFeedError(reason: $reason)';
  }
}

class _CreatureFeedErrorImpl extends CreatureFeedError {
  _CreatureFeedErrorImpl({required _i2.CreatureFeedErrorReason reason})
    : super._(reason: reason);

  /// Returns a shallow copy of this [CreatureFeedError]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreatureFeedError copyWith({_i2.CreatureFeedErrorReason? reason}) {
    return CreatureFeedError(reason: reason ?? this.reason);
  }
}
