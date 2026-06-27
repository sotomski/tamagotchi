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

/// Why a hatch attempt was rejected. Lets the Flutter client switch on a typed
/// reason instead of parsing a message string.
enum CreatureHatchErrorReason implements _i1.SerializableModel {
  /// The caller already owns a creature (one creature per user).
  alreadyHatched,

  /// The supplied name was blank.
  emptyName,

  /// The birth narrative could not be generated (the LLM call failed). Hatch
  /// blocks on this rather than degrading to canned prose, so no creature is
  /// created — the owner can simply retry.
  narrativeUnavailable;

  static CreatureHatchErrorReason fromJson(String name) {
    switch (name) {
      case 'alreadyHatched':
        return CreatureHatchErrorReason.alreadyHatched;
      case 'emptyName':
        return CreatureHatchErrorReason.emptyName;
      case 'narrativeUnavailable':
        return CreatureHatchErrorReason.narrativeUnavailable;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "CreatureHatchErrorReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
