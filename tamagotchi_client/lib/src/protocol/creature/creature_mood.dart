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

/// The creature's mood, derived-on-read from its four stats (never stored) so it
/// stays consistent once S-07 decay mutates stats. Derivation rule lives in
/// creature_service.dart.
enum CreatureMood implements _i1.SerializableModel {
  happy,
  content,
  sad,
  sick;

  static CreatureMood fromJson(String name) {
    switch (name) {
      case 'happy':
        return CreatureMood.happy;
      case 'content':
        return CreatureMood.content;
      case 'sad':
        return CreatureMood.sad;
      case 'sick':
        return CreatureMood.sick;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "CreatureMood"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
