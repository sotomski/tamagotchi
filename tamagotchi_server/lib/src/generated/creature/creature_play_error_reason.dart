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

/// Why a play attempt failed outright. A single reason (typed for client switch
/// parity with CreatureFeedErrorReason); behind the UI this should never fire —
/// you can only play with a creature you can see.
enum CreaturePlayErrorReason implements _i1.SerializableModel {
  /// The caller owns no creature to play with.
  noCreature;

  static CreaturePlayErrorReason fromJson(String name) {
    switch (name) {
      case 'noCreature':
        return CreaturePlayErrorReason.noCreature;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "CreaturePlayErrorReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
