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
import '../creature/creature_status.dart' as _i2;
import 'package:tamagotchi_client/src/protocol/protocol.dart' as _i3;

/// The Feed interaction outcome returned to the client: the in-character user
/// response, whether the food was accepted, and the post-feed creature+mood so
/// the client renders without a second fetch. Non-table — computed per call,
/// never persisted (like CreatureStatus / StatDelta).
abstract class FeedResult implements _i1.SerializableModel {
  FeedResult._({
    required this.userResponse,
    required this.accepted,
    required this.status,
  });

  factory FeedResult({
    required String userResponse,
    required bool accepted,
    required _i2.CreatureStatus status,
  }) = _FeedResultImpl;

  factory FeedResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeedResult(
      userResponse: jsonSerialization['userResponse'] as String,
      accepted: _i1.BoolJsonExtension.fromJson(jsonSerialization['accepted']),
      status: _i3.Protocol().deserialize<_i2.CreatureStatus>(
        jsonSerialization['status'],
      ),
    );
  }

  /// The user-facing, in-character response (LLM-generated, or canned copy on a
  /// full-refusal / model-failure degrade).
  String userResponse;

  /// Whether the creature ate the food. False on a full-refusal (already full)
  /// or a picky-refusal — neither is an error; both ride this flag.
  bool accepted;

  /// The creature's post-feed status: updated stats (on an accepted feed) plus a
  /// freshly re-derived mood.
  _i2.CreatureStatus status;

  /// Returns a shallow copy of this [FeedResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FeedResult copyWith({
    String? userResponse,
    bool? accepted,
    _i2.CreatureStatus? status,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeedResult',
      'userResponse': userResponse,
      'accepted': accepted,
      'status': status.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _FeedResultImpl extends FeedResult {
  _FeedResultImpl({
    required String userResponse,
    required bool accepted,
    required _i2.CreatureStatus status,
  }) : super._(
         userResponse: userResponse,
         accepted: accepted,
         status: status,
       );

  /// Returns a shallow copy of this [FeedResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FeedResult copyWith({
    String? userResponse,
    bool? accepted,
    _i2.CreatureStatus? status,
  }) {
    return FeedResult(
      userResponse: userResponse ?? this.userResponse,
      accepted: accepted ?? this.accepted,
      status: status ?? this.status.copyWith(),
    );
  }
}
