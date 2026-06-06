import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/feed_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../helpers/scripted_random.dart';

const _ownerUuid = '00000000-0000-0000-0000-000000000001';
const _creatureId = '00000000-0000-0000-0000-000000000002';

/// A creature with the given volatile stats; the rest are fixed placeholders the
/// gate never reads.
Creature _creature({
  required int hunger,
  int energy = 100,
  int love = 50,
  int illness = 0,
}) => Creature(
  id: UuidValue.fromString(_creatureId),
  ownerUuid: UuidValue.fromString(_ownerUuid),
  name: 'Testy',
  hunger: hunger,
  energy: energy,
  love: love,
  illness: illness,
);

/// A personality with the given `hungerDecayMod` (the only field the gate reads,
/// via `pickyFactor`); the other seven mods are inert here.
CreaturePersonality _personality(double hungerDecayMod) => CreaturePersonality(
  creatureId: UuidValue.fromString(_creatureId),
  hungerDecayMod: hungerDecayMod,
  hungerRegenMod: 1.0,
  energyDecayMod: 1.0,
  energyRegenMod: 1.0,
  loveDecayMod: 1.0,
  loveRegenMod: 1.0,
  illnessDecayMod: 1.0,
  illnessRegenMod: 1.0,
);

void main() {
  group('pickyFactor', () {
    // Oracle = the plan's contract: pickyFactor(mod) = 1.5 - mod, over the
    // personality range mod∈[0.5,1.5). Direction is load-bearing: LOW decay mod
    // ⇒ HIGH picky factor (a placid metabolism is the fussy eater). Asserted
    // against the spec formula, not the implementation's output.
    final cases = <({String name, double mod, double expected})>[
      (name: 'min mod 0.5 -> maximally picky 1.0', mod: 0.5, expected: 1.0),
      (name: 'baseline mod 1.0 -> 0.5', mod: 1.0, expected: 0.5),
      (name: 'top of range mod 1.5 -> 0.0', mod: 1.5, expected: 0.0),
    ];
    for (final c in cases) {
      test(c.name, () {
        expect(pickyFactor(c.mod), closeTo(c.expected, 1e-9));
      });
    }

    test('lower decay mod is strictly pickier than higher', () {
      expect(pickyFactor(0.6), greaterThan(pickyFactor(1.2)));
    });
  });

  group('rejectProbability', () {
    // Oracle = the plan's composition:
    //   picky * (1 - hunger/100) * (1 - tastiness)
    // Monotone in each factor; a starving creature (hunger→100) or gourmet food
    // (tastiness→1) drives it to 0.
    test('drops to 0 when the creature is starving (hunger==100)', () {
      expect(
        rejectProbability(picky: 1.0, hunger: 100, tastiness: 0.0),
        closeTo(0.0, 1e-9),
      );
    });

    test('drops to 0 for maximally tasty food (tastiness→1)', () {
      expect(
        rejectProbability(picky: 1.0, hunger: 0, tastiness: 1.0),
        closeTo(0.0, 1e-9),
      );
    });

    test('composes the three factors multiplicatively', () {
      // picky 0.8, hunger 50 → (1-0.5)=0.5, tastiness 0.25 → (1-0.25)=0.75.
      // 0.8 * 0.5 * 0.75 = 0.3 — a hand-computed oracle, not a re-run of the code.
      expect(
        rejectProbability(picky: 0.8, hunger: 50, tastiness: 0.25),
        closeTo(0.3, 1e-9),
      );
    });

    test('pickier + fuller + blander strictly raises the probability', () {
      final mild = rejectProbability(picky: 0.4, hunger: 80, tastiness: 0.8);
      final harsh = rejectProbability(picky: 1.0, hunger: 10, tastiness: 0.1);
      expect(harsh, greaterThan(mild));
    });
  });

  group('clampStat', () {
    // Oracle = the 0-100 stat scale: values pin to the boundary, never escape it.
    test('clamps above 100 down to 100', () => expect(clampStat(150), 100));
    test('clamps below 0 up to 0', () => expect(clampStat(-5), 0));
    test('leaves an in-range value untouched', () => expect(clampStat(73), 73));
  });

  group('evaluateFeed', () {
    test('a full creature (hunger==0) refuses with no draws and no delta', () {
      // Oracle: hunger==0 means full (creature.spy.yaml:13). The full path is a
      // cheap short-circuit — it must return BEFORE drawing the RNG (an empty
      // scripted queue throws if drawn), accepted:false, and zero delta.
      final result = evaluateFeed(
        creature: _creature(hunger: 0),
        personality: _personality(1.0),
        rng: ScriptedRandom(const []),
      );
      expect(result.full, isTrue);
      expect(result.accepted, isFalse);
      expect(
        (
          result.delta.hungerDelta,
          result.delta.energyDelta,
          result.delta.loveDelta,
          result.delta.illnessDelta,
        ),
        (0, 0, 0, 0),
      );
    });

    test(
      'accepted feed draws tastiness first, then applies the -30/-10 delta',
      () {
        // picky = pickyFactor(1.0) = 0.5; reject p = 0.5*(1-0.8)*(1-0.5)=0.05.
        // Draw order is the contract: tastiness (0.5) FIRST, then the reject roll
        // (0.99, which is ≥ 0.05 ⇒ accepted). Stats: hunger 80→50 (-30),
        // energy 100→90 (-10), love/illness untouched.
        final result = evaluateFeed(
          creature: _creature(hunger: 80, energy: 100),
          personality: _personality(1.0),
          rng: ScriptedRandom(const [0.5, 0.99]),
        );
        expect(result.full, isFalse);
        expect(result.accepted, isTrue);
        expect(result.tastiness, closeTo(0.5, 1e-9));
        expect(result.delta.hungerDelta, -30);
        expect(result.delta.energyDelta, -10);
        expect(result.delta.loveDelta, 0);
        expect(result.delta.illnessDelta, 0);
      },
    );

    test(
      'accepted delta clamps so a near-full creature never goes negative',
      () {
        // hunger 10, energy 5: the fixed -30/-10 would underflow, but clampStat
        // floors each stat at 0, so the delta is the clamped distance: -10 / -5.
        final result = evaluateFeed(
          creature: _creature(hunger: 10, energy: 5),
          personality: _personality(1.0),
          rng: ScriptedRandom(const [0.9, 0.9999]),
        );
        expect(result.accepted, isTrue);
        expect(result.delta.hungerDelta, -10);
        expect(result.delta.energyDelta, -5);
      },
    );

    test('a picky refusal accepts nothing and leaves stats unchanged', () {
      // picky = pickyFactor(0.5) = 1.0 (maximally fussy); reject p =
      // 1.0*(1-0.1)*(1-0.0)=0.9. Reject roll 0.0 < 0.9 ⇒ refuse. Not full (it
      // still drew), accepted:false, and the delta is all zeros.
      final result = evaluateFeed(
        creature: _creature(hunger: 10),
        personality: _personality(0.5),
        rng: ScriptedRandom(const [0.0, 0.0]),
      );
      expect(result.full, isFalse);
      expect(result.accepted, isFalse);
      expect(
        (
          result.delta.hungerDelta,
          result.delta.energyDelta,
          result.delta.loveDelta,
          result.delta.illnessDelta,
        ),
        (0, 0, 0, 0),
      );
    });

    test('hunger=1 is NOT treated as full', () {
      // Oracle FR-004: the full-creature gate fires only at hunger==0; any
      // positive hunger must proceed to the random gate.
      // pickyFactor(1.0)=0.5; tastiness=0.5; rejectProbability=
      //   0.5*(1-0.01)*(1-0.5)≈0.2475; roll 0.99>0.2475 ⇒ accepted.
      // hungerDelta: clampStat(1-30)-1 = 0-1 = -1; energyDelta: 90-100 = -10.
      final result = evaluateFeed(
        creature: _creature(hunger: 1),
        personality: _personality(1.0),
        rng: ScriptedRandom(const [0.5, 0.99]),
      );
      expect(result.full, isFalse);
      expect(result.accepted, isTrue);
      expect(result.delta.hungerDelta, -1);
      expect(result.delta.energyDelta, -10);
    });

    test('same Random(seed) produces identical FeedDecision', () {
      // Oracle PRD §Success Criteria: same seed + same inputs → identical
      // outputs. Two independent Random(42) instances must produce
      // bit-identical nextDouble() streams; the oracle is equality between
      // the two calls, not any particular value.
      final result1 = evaluateFeed(
        creature: _creature(hunger: 60),
        personality: _personality(1.0),
        rng: Random(42),
      );
      final result2 = evaluateFeed(
        creature: _creature(hunger: 60),
        personality: _personality(1.0),
        rng: Random(42),
      );
      expect(result1.accepted, result2.accepted);
      expect(result1.full, result2.full);
      expect(result1.tastiness, result2.tastiness);
      expect(result1.delta.hungerDelta, result2.delta.hungerDelta);
      expect(result1.delta.energyDelta, result2.delta.energyDelta);
      expect(result1.delta.loveDelta, result2.delta.loveDelta);
      expect(result1.delta.illnessDelta, result2.delta.illnessDelta);
    });

    test(
      'opposite hungerDecayMod produces measurably different accept outcomes',
      () {
        // Oracle FR-004 + PRD: opposite-trait creatures must diverge under
        // identical conditions.
        // max-picky: mod=0.5 → pickyFactor=1.0; rejectProbability=
        //   1.0*(1-0.6)*(1-0.5)=0.2; roll 0.1<0.2 ⇒ rejected.
        // min-picky: mod=1.5 → pickyFactor=0.0; rejectProbability=0.0;
        //   0.1<0.0 is always false ⇒ accepted.
        final maxPickyResult = evaluateFeed(
          creature: _creature(hunger: 60),
          personality: _personality(0.5),
          rng: ScriptedRandom(const [0.5, 0.1]),
        );
        final minPickyResult = evaluateFeed(
          creature: _creature(hunger: 60),
          personality: _personality(1.5),
          rng: ScriptedRandom(const [0.5, 0.1]),
        );
        expect(maxPickyResult.accepted, isFalse);
        expect(minPickyResult.accepted, isTrue);
      },
    );
  });
}
