import '../generated/protocol.dart';

/// The schema version current generators emit. A spec carrying a different `v`
/// is from another format and is rejected rather than silently reinterpreted.
const int kCritterSpecVersion = 1;

/// The single supported grid edge. The model draws a full `kCritterSize`×
/// `kCritterSize` square and we accept it as-is (no mirroring — see
/// `context/changes/generate-creature-image/change.md`). Kept as a named constant
/// so a future size change is one edit here plus a regenerated stub.
const int kCritterSize = 32;

/// The transparent sentinel cell. Never a palette key (Serverpod map values are
/// non-null, so transparency is encoded by *absence*); any cell that is this char
/// — or any char missing from the palette — renders empty.
const String kCritterTransparent = '.';

final RegExp _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Validates a generated [CritterSpec] against the fixed contract, returning a
/// list of human-readable problems — **empty means valid**. Pure: no [Session],
/// no I/O. Phase 3 runs [repairCritterSpec] first and then gates on this; any
/// remaining problem makes the generation call throw (block-hatch posture).
///
/// Checks: `v` and `size` match the contract; `base` has exactly `size` rows,
/// each exactly `size` chars; every palette key is a single non-transparent char
/// mapped to a `#RRGGBB` value; every non-transparent cell char exists in the
/// palette.
List<String> validateCritterSpec(CritterSpec spec) {
  final problems = <String>[];

  if (spec.v != kCritterSpecVersion) {
    problems.add('version is ${spec.v}, expected $kCritterSpecVersion');
  }
  if (spec.size != kCritterSize) {
    problems.add('size is ${spec.size}, expected $kCritterSize');
  }

  // Palette membership is checked against the well-formed entries only, so a
  // malformed entry surfaces as both a palette problem and (if referenced) an
  // unknown-cell problem — repair fixes both.
  final validKeys = <String>{};
  spec.palette.forEach((key, value) {
    if (key == kCritterTransparent) {
      problems.add('palette must not map the transparent char "$key"');
    } else if (key.length != 1) {
      problems.add('palette key "$key" must be a single char');
    } else if (!_hexColor.hasMatch(value)) {
      problems.add('palette["$key"] = "$value" is not #RRGGBB');
    } else {
      validKeys.add(key);
    }
  });

  if (spec.base.length != spec.size) {
    problems.add('base has ${spec.base.length} rows, expected ${spec.size}');
  }
  for (var r = 0; r < spec.base.length; r++) {
    final row = spec.base[r];
    if (row.length != spec.size) {
      problems.add('row $r has ${row.length} chars, expected ${spec.size}');
    }
    for (final ch in row.split('')) {
      if (ch != kCritterTransparent && !validKeys.contains(ch)) {
        problems.add('row $r references char "$ch" absent from palette');
      }
    }
  }

  return problems;
}

/// Auto-repairs the fixable defects the model tends to produce, returning a new
/// [CritterSpec] normalised to the contract — so Phase 3 can ship the result
/// without a reprompt round-trip. Pure: no [Session], no I/O.
///
/// Repairs: drop malformed palette entries (bad hex, multi-char key, the
/// transparent key); pad/truncate every row to `kCritterSize` chars and the row
/// count to `kCritterSize` (padding with transparent cells); replace any cell
/// char not in the repaired palette with the transparent char; pin `v`/`size`.
///
/// Idempotent on already-valid specs: repairing a valid spec returns an
/// equivalent one. What it cannot invent (a too-empty or nonsense body) is left
/// for [validateCritterSpec] to reject.
CritterSpec repairCritterSpec(CritterSpec spec) {
  // 1. Keep only well-formed palette entries.
  final palette = <String, String>{};
  spec.palette.forEach((key, value) {
    if (key != kCritterTransparent &&
        key.length == 1 &&
        _hexColor.hasMatch(value)) {
      palette[key] = value;
    }
  });

  // 2. Normalise the grid to exactly kCritterSize rows of kCritterSize chars,
  //    mapping unknown cells to transparent.
  final base = <String>[];
  for (var r = 0; r < kCritterSize; r++) {
    final source = r < spec.base.length ? spec.base[r] : '';
    final buffer = StringBuffer();
    for (var c = 0; c < kCritterSize; c++) {
      final ch = c < source.length ? source[c] : kCritterTransparent;
      buffer.write(palette.containsKey(ch) ? ch : kCritterTransparent);
    }
    base.add(buffer.toString());
  }

  return CritterSpec(
    v: kCritterSpecVersion,
    size: kCritterSize,
    palette: palette,
    base: base,
  );
}
