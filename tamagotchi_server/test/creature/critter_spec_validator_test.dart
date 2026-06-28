import 'package:tamagotchi_server/src/creature/critter_spec_validator.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

/// Builds a contract-valid spec: a filled centre block over a transparent field,
/// exactly [kCritterSize]×[kCritterSize], one palette entry.
CritterSpec _validSpec() {
  final rows = <String>[];
  for (var r = 0; r < kCritterSize; r++) {
    final buf = StringBuffer();
    for (var c = 0; c < kCritterSize; c++) {
      final filled = r >= 8 && r < 24 && c >= 8 && c < 24;
      buf.write(filled ? 'B' : kCritterTransparent);
    }
    rows.add(buf.toString());
  }
  return CritterSpec(
    v: kCritterSpecVersion,
    size: kCritterSize,
    palette: {'B': '#11AA33'},
    base: rows,
  );
}

void main() {
  group('validateCritterSpec', () {
    test('a well-formed spec has no problems', () {
      expect(validateCritterSpec(_validSpec()), isEmpty);
    });

    test('flags a wrong version', () {
      final spec = _validSpec().copyWith(v: 99);
      expect(
        validateCritterSpec(spec),
        contains(allOf(contains('version'), contains('99'))),
      );
    });

    test('flags a wrong size', () {
      final spec = _validSpec().copyWith(size: 16);
      expect(
        validateCritterSpec(spec),
        contains(allOf(contains('size'), contains('16'))),
      );
    });

    test('flags a wrong row count', () {
      final spec = _validSpec();
      final spec2 = spec.copyWith(base: spec.base.sublist(0, spec.size - 1));
      expect(
        validateCritterSpec(spec2),
        contains(allOf(contains('base'), contains('rows'))),
      );
    });

    test('flags a row of the wrong width', () {
      final spec = _validSpec();
      final rows = [...spec.base];
      rows[0] = '${rows[0]}X'; // one char too long
      expect(
        validateCritterSpec(spec.copyWith(base: rows)),
        contains(allOf(contains('row 0'), contains('chars'))),
      );
    });

    test('flags a cell char missing from the palette', () {
      final spec = _validSpec();
      final rows = [...spec.base];
      rows[10] = rows[10].replaceFirst('B', 'Z');
      expect(
        validateCritterSpec(spec.copyWith(base: rows)),
        contains(allOf(contains('"Z"'), contains('palette'))),
      );
    });

    test('flags a non-hex palette value', () {
      final spec = _validSpec().copyWith(palette: {'B': 'green'});
      expect(
        validateCritterSpec(spec),
        contains(allOf(contains('"B"'), contains('#RRGGBB'))),
      );
    });

    test('flags the transparent char used as a palette key', () {
      final spec = _validSpec().copyWith(
        palette: {'B': '#11AA33', kCritterTransparent: '#000000'},
      );
      expect(
        validateCritterSpec(spec),
        contains(contains('transparent')),
      );
    });

    test('flags a multi-char palette key', () {
      final spec = _validSpec().copyWith(palette: {'BB': '#11AA33'});
      expect(
        validateCritterSpec(spec),
        // 'BB' is not a single char AND the 'B' cells now reference a missing key
        contains(allOf(contains('"BB"'), contains('single char'))),
      );
    });
  });

  group('repairCritterSpec', () {
    test('repairing a valid spec is content-preserving', () {
      final spec = _validSpec();
      final repaired = repairCritterSpec(spec);
      expect(validateCritterSpec(repaired), isEmpty);
      expect(repaired.v, spec.v);
      expect(repaired.size, spec.size);
      expect(repaired.palette, spec.palette);
      expect(repaired.base, spec.base);
    });

    test('repair is idempotent', () {
      final once = repairCritterSpec(_validSpec());
      final twice = repairCritterSpec(once);
      expect(twice.base, once.base);
      expect(twice.palette, once.palette);
    });

    test('pads a short grid up to the contract and validates', () {
      // 31 rows of 31 chars, declared size 31 — the ±1 drift the model produces.
      final rows = List.generate(31, (_) => 'B' * 31);
      final spec = CritterSpec(
        v: kCritterSpecVersion,
        size: 31,
        palette: {'B': '#11AA33'},
        base: rows,
      );
      final repaired = repairCritterSpec(spec);
      expect(validateCritterSpec(repaired), isEmpty);
      expect(repaired.size, kCritterSize);
      expect(repaired.base.length, kCritterSize);
      expect(repaired.base.every((row) => row.length == kCritterSize), isTrue);
      // The padded last row and trailing column are transparent.
      expect(repaired.base.last, kCritterTransparent * kCritterSize);
      expect(repaired.base.first[kCritterSize - 1], kCritterTransparent);
    });

    test('truncates an oversized grid and validates', () {
      final rows = List.generate(40, (_) => 'B' * 40);
      final spec = CritterSpec(
        v: kCritterSpecVersion,
        size: 40,
        palette: {'B': '#11AA33'},
        base: rows,
      );
      final repaired = repairCritterSpec(spec);
      expect(validateCritterSpec(repaired), isEmpty);
      expect(repaired.base.length, kCritterSize);
      expect(repaired.base.every((row) => row.length == kCritterSize), isTrue);
    });

    test('drops a malformed palette entry and transpar-ifies its cells', () {
      final spec = _validSpec().copyWith(palette: {'B': 'not-a-color'});
      final repaired = repairCritterSpec(spec);
      expect(validateCritterSpec(repaired), isEmpty);
      expect(repaired.palette, isEmpty);
      // Every former 'B' cell is now transparent.
      expect(
        repaired.base.every((row) => !row.contains('B')),
        isTrue,
      );
    });

    test('replaces unknown cell chars with transparent', () {
      final spec = _validSpec();
      final rows = [...spec.base];
      rows[12] = rows[12].replaceAll('B', 'Q'); // 'Q' not in palette
      final repaired = repairCritterSpec(spec.copyWith(base: rows));
      expect(validateCritterSpec(repaired), isEmpty);
      expect(repaired.base[12].contains('Q'), isFalse);
    });

    test('pins version and size even when both are wrong', () {
      final spec = _validSpec().copyWith(v: 7, size: 99);
      final repaired = repairCritterSpec(spec);
      expect(repaired.v, kCritterSpecVersion);
      expect(repaired.size, kCritterSize);
      expect(validateCritterSpec(repaired), isEmpty);
    });
  });
}
