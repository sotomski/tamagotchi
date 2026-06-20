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
import '../creature/creature_status.dart' as _i2;
import 'package:tamagotchi_server/src/generated/protocol.dart' as _i3;

/// The Play interaction outcome returned to the client: the in-character user
/// response plus the post-play creature+mood so the client renders without a
/// second fetch. Non-table — computed per call, never persisted (like
/// CreatureStatus / StatDelta / FeedResult).
///
/// No `accepted` field: playing is deterministic and always succeeds
/// (`prd.md:39`). The shared two-interaction UI supplies `accepted: true` for
/// Play itself.
abstract class PlayResult
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  PlayResult._({
    required this.userResponse,
    required this.status,
  });

  factory PlayResult({
    required String userResponse,
    required _i2.CreatureStatus status,
  }) = _PlayResultImpl;

  factory PlayResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return PlayResult(
      userResponse: jsonSerialization['userResponse'] as String,
      status: _i3.Protocol().deserialize<_i2.CreatureStatus>(
        jsonSerialization['status'],
      ),
    );
  }

  /// The user-facing, in-character response (LLM-generated, or canned play copy
  /// on a model-failure degrade).
  String userResponse;

  /// The creature's post-play status: updated stats (love up, energy down) plus
  /// a freshly re-derived mood.
  _i2.CreatureStatus status;

  /// Returns a shallow copy of this [PlayResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  PlayResult copyWith({
    String? userResponse,
    _i2.CreatureStatus? status,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlayResult',
      'userResponse': userResponse,
      'status': status.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PlayResult',
      'userResponse': userResponse,
      'status': status.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _PlayResultImpl extends PlayResult {
  _PlayResultImpl({
    required String userResponse,
    required _i2.CreatureStatus status,
  }) : super._(
         userResponse: userResponse,
         status: status,
       );

  /// Returns a shallow copy of this [PlayResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  PlayResult copyWith({
    String? userResponse,
    _i2.CreatureStatus? status,
  }) {
    return PlayResult(
      userResponse: userResponse ?? this.userResponse,
      status: status ?? this.status.copyWith(),
    );
  }
}
