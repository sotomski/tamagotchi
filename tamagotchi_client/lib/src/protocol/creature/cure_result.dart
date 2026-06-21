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

/// The Cure interaction outcome returned to the client: the in-character user
/// response plus the post-cure creature+mood so the client renders without a
/// second fetch. Non-table — computed per call, never persisted (like
/// CreatureStatus / StatDelta / PlayResult).
///
/// No `accepted` field: curing is deterministic and always succeeds
/// (`prd.md:39`, FR-006). The shared three-interaction UI supplies
/// `accepted: true` for Cure itself.
abstract class CureResult implements _i1.SerializableModel {
  CureResult._({
    required this.userResponse,
    required this.status,
  });

  factory CureResult({
    required String userResponse,
    required _i2.CreatureStatus status,
  }) = _CureResultImpl;

  factory CureResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return CureResult(
      userResponse: jsonSerialization['userResponse'] as String,
      status: _i3.Protocol().deserialize<_i2.CreatureStatus>(
        jsonSerialization['status'],
      ),
    );
  }

  /// The user-facing, in-character response (LLM-generated, or canned cure copy
  /// on a model-failure degrade).
  String userResponse;

  /// The creature's post-cure status: updated stats (illness down) plus a
  /// freshly re-derived mood.
  _i2.CreatureStatus status;

  /// Returns a shallow copy of this [CureResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CureResult copyWith({
    String? userResponse,
    _i2.CreatureStatus? status,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CureResult',
      'userResponse': userResponse,
      'status': status.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _CureResultImpl extends CureResult {
  _CureResultImpl({
    required String userResponse,
    required _i2.CreatureStatus status,
  }) : super._(
         userResponse: userResponse,
         status: status,
       );

  /// Returns a shallow copy of this [CureResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CureResult copyWith({
    String? userResponse,
    _i2.CreatureStatus? status,
  }) {
    return CureResult(
      userResponse: userResponse ?? this.userResponse,
      status: status ?? this.status.copyWith(),
    );
  }
}
