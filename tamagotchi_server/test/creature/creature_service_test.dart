import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/creature_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

/// A stand-in for a Serverpod query failure so the duplicate-owner classifier
/// can be tested hermetically — without forcing a real mid-transaction unique
/// violation (root CLAUDE.md guidance for non-atomic save sequences). Extends
/// the public `base` exception; only the fields the classifier reads are set.
final class _FakeQueryException extends DatabaseQueryException {
  _FakeQueryException({this.code, this.constraintName, this.tableName});

  @override
  final String? code;
  @override
  final String? constraintName;
  @override
  final String? tableName;

  @override
  String get message => 'fake query failure';
  @override
  String? get detail => null;
  @override
  String? get hint => null;
  @override
  String? get columnName => null;
  @override
  int? get position => null;
}

void main() {
  group('deriveMood', () {
    // Oracle = the decided rule from the plan's Critical Implementation Details,
    // NOT a re-derivation of the implementation:
    //   distress: hunger, 100-energy, 100-love, illness
    //   illness >= 50              -> sick   (illness has priority)
    //   else worst = max(hunger, 100-energy, 100-love)
    //   worst < 25 -> happy ; worst < 55 -> content ; else -> sad
    final cases =
        <
          ({
            String name,
            int hunger,
            int energy,
            int love,
            int illness,
            CreatureMood expected,
          })
        >[
          // Hatch baseline: love distress 50 -> content ("newborn, not yet bonded").
          (
            name: 'baseline -> content',
            hunger: 0,
            energy: 100,
            love: 50,
            illness: 0,
            expected: CreatureMood.content,
          ),
          // All stats ideal: every distress 0 -> happy.
          (
            name: 'all-good -> happy',
            hunger: 0,
            energy: 100,
            love: 100,
            illness: 0,
            expected: CreatureMood.happy,
          ),
          // Bad stats but healthy: worst distress 100 -> sad.
          (
            name: 'all-bad-but-healthy -> sad',
            hunger: 100,
            energy: 0,
            love: 0,
            illness: 0,
            expected: CreatureMood.sad,
          ),
          // Illness priority: sick even when the other three stats are perfect.
          (
            name: 'illness overrides otherwise-perfect stats -> sick',
            hunger: 0,
            energy: 100,
            love: 100,
            illness: 50,
            expected: CreatureMood.sick,
          ),
          // Illness just below the sick threshold falls through to the worst rule.
          (
            name: 'illness 49 with perfect stats -> happy',
            hunger: 0,
            energy: 100,
            love: 100,
            illness: 49,
            expected: CreatureMood.happy,
          ),
          // happy/content boundary at 25: distress 24 is still happy.
          (
            name: 'worst distress 24 -> happy',
            hunger: 24,
            energy: 100,
            love: 100,
            illness: 0,
            expected: CreatureMood.happy,
          ),
          // happy/content boundary at 25: distress 25 tips into content.
          (
            name: 'worst distress 25 -> content',
            hunger: 25,
            energy: 100,
            love: 100,
            illness: 0,
            expected: CreatureMood.content,
          ),
          // content/sad boundary at 55: distress 54 is still content.
          (
            name: 'worst distress 54 -> content',
            hunger: 54,
            energy: 100,
            love: 100,
            illness: 0,
            expected: CreatureMood.content,
          ),
          // content/sad boundary at 55: distress 55 tips into sad.
          (
            name: 'worst distress 55 -> sad',
            hunger: 55,
            energy: 100,
            love: 100,
            illness: 0,
            expected: CreatureMood.sad,
          ),
        ];

    for (final c in cases) {
      test(c.name, () {
        expect(
          deriveMood(c.hunger, c.energy, c.love, c.illness),
          c.expected,
        );
      });
    }
  });

  group('randomPersonalityModifiers', () {
    test('returns seven modifiers all within the 0.5-1.5 range', () {
      final mods = randomPersonalityModifiers(Random(1));
      final values = [
        mods.hungerDecayMod,
        mods.hungerRegenMod,
        mods.energyDecayMod,
        mods.energyRegenMod,
        mods.loveRegenMod,
        mods.illnessDecayMod,
        mods.illnessRegenMod,
      ];
      expect(values, hasLength(7));
      for (final v in values) {
        expect(v, inInclusiveRange(0.5, 1.5));
      }
    });

    test('is deterministic for a given seed', () {
      final a = randomPersonalityModifiers(Random(42));
      final b = randomPersonalityModifiers(Random(42));
      expect(a.hungerDecayMod, b.hungerDecayMod);
      expect(a.illnessRegenMod, b.illnessRegenMod);
    });
  });

  group('isUniqueViolation', () {
    // Oracle: this is only the *trigger* for the hatch backstop — true for any
    // Postgres unique violation (SQLSTATE 23505), false for every other error.
    // It deliberately does NOT inspect table or constraint names: the endpoint
    // disambiguates a real duplicate hatch by re-reading the owner's creature,
    // so adding a unique index elsewhere later can't be misclassified here.

    test('true: a unique violation regardless of table/constraint name', () {
      expect(
        isUniqueViolation(
          _FakeQueryException(
            code: '23505',
            constraintName: 'creature_owner_idx',
          ),
        ),
        isTrue,
      );
    });

    test(
      'true: a unique violation when the driver omits the constraint name',
      () {
        expect(
          isUniqueViolation(_FakeQueryException(code: '23505')),
          isTrue,
        );
      },
    );

    test('false: a non-unique database error (e.g. FK violation 23503)', () {
      expect(
        isUniqueViolation(
          _FakeQueryException(code: '23503', tableName: 'creature'),
        ),
        isFalse,
      );
    });

    test('false: an error that is not a database query exception', () {
      expect(isUniqueViolation(StateError('boom')), isFalse);
    });
  });
}
