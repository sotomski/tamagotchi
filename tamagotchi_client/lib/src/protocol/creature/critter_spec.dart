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
import 'package:tamagotchi_client/src/protocol/protocol.dart' as _i2;

/// One static, retro pixel-art critter body, generated at hatch and nested onto
/// `Creature` (so it lands in a single `json` column and crosses the RPC boundary
/// to the Flutter client). Serialized model only — no `table:` key.
///
/// The grid is the FULL `size`×`size` square the model draws; we accept its output
/// as-is. (The Phase 0 probe showed every Mistral model draws a complete centred
/// creature, not a true left half, so the original mirror protocol was dropped —
/// see `context/changes/generate-creature-image/change.md`.)
abstract class CritterSpec implements _i1.SerializableModel {
  CritterSpec._({
    required this.v,
    required this.size,
    required this.palette,
    required this.base,
  });

  factory CritterSpec({
    required int v,
    required int size,
    required Map<String, String> palette,
    required List<String> base,
  }) = _CritterSpecImpl;

  factory CritterSpec.fromJson(Map<String, dynamic> jsonSerialization) {
    return CritterSpec(
      v: jsonSerialization['v'] as int,
      size: jsonSerialization['size'] as int,
      palette: _i2.Protocol().deserialize<Map<String, String>>(
        jsonSerialization['palette'],
      ),
      base: _i2.Protocol().deserialize<List<String>>(jsonSerialization['base']),
    );
  }

  /// Schema version, so a future format change can be told apart from this one.
  int v;

  /// Grid edge in cells; the body is `size` rows of `size` chars. Currently 32.
  int size;

  /// Char → `#RRGGBB`. `.` (and any char absent here) is transparent and is NOT a
  /// key — Serverpod map values are non-null, so transparency is encoded by absence.
  Map<String, String> palette;

  /// The pixel grid: exactly `size` strings, each exactly `size` chars long. Each
  /// char indexes `palette` (or is `.`/absent → transparent).
  List<String> base;

  /// Returns a shallow copy of this [CritterSpec]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CritterSpec copyWith({
    int? v,
    int? size,
    Map<String, String>? palette,
    List<String>? base,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CritterSpec',
      'v': v,
      'size': size,
      'palette': palette.toJson(),
      'base': base.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _CritterSpecImpl extends CritterSpec {
  _CritterSpecImpl({
    required int v,
    required int size,
    required Map<String, String> palette,
    required List<String> base,
  }) : super._(
         v: v,
         size: size,
         palette: palette,
         base: base,
       );

  /// Returns a shallow copy of this [CritterSpec]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CritterSpec copyWith({
    int? v,
    int? size,
    Map<String, String>? palette,
    List<String>? base,
  }) {
    return CritterSpec(
      v: v ?? this.v,
      size: size ?? this.size,
      palette:
          palette ??
          this.palette.map(
            (
              key0,
              value0,
            ) => MapEntry(
              key0,
              value0,
            ),
          ),
      base: base ?? this.base.map((e0) => e0).toList(),
    );
  }
}
