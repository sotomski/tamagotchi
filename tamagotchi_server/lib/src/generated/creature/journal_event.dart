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

/// The kind of event a journal entry records. Only `hatched` is written at S-02;
/// feed/play/cure arrive with the interaction slices (S-03+).
enum JournalEvent implements _i1.SerializableModel {
  hatched,
  feed,
  play,
  cure;

  static JournalEvent fromJson(String name) {
    switch (name) {
      case 'hatched':
        return JournalEvent.hatched;
      case 'feed':
        return JournalEvent.feed;
      case 'play':
        return JournalEvent.play;
      case 'cure':
        return JournalEvent.cure;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "JournalEvent"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
