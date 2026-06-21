import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/cure_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/cure_copy.dart' as cure;
import 'package:tamagotchi_server/src/llm/feed_copy.dart' as feed;
import 'package:tamagotchi_server/src/llm/play_copy.dart' as play;
import 'package:test/test.dart';

const _ownerUuid = '00000000-0000-0000-0000-000000000001';
const _creatureId = '00000000-0000-0000-0000-000000000002';

/// A creature with the given volatile stats; the rest are fixed placeholders the
/// cure math never reads.
Creature _creature({
  int hunger = 20,
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

/// A personality with the given `illnessDecayMod` (the only field cure math
/// reads, the recovery-responsiveness axis); the other six mods are inert here.
CreaturePersonality _personality(double illnessDecayMod) => CreaturePersonality(
  creatureId: UuidValue.fromString(_creatureId),
  hungerDecayMod: 1.0,
  hungerRegenMod: 1.0,
  energyDecayMod: 1.0,
  energyRegenMod: 1.0,
  loveRegenMod: 1.0,
  illnessDecayMod: illnessDecayMod,
  illnessRegenMod: 1.0,
);

void main() {
  group('cureRelief', () {
    // Oracle = the plan's contract: round(baseCureRelief * illnessDecayMod),
    // with baseCureRelief = 40, over the personality range
    // illnessDecayMod∈[0.5,1.5). Monotone ↑: a more recovery-responsive
    // creature (high mod) heals more per cure.
    test('low responsiveness (mod 0.5) relieves 20', () {
      expect(cureRelief(0.5), 20);
    });
    test('baseline (mod 1.0) relieves 40', () {
      expect(cureRelief(1.0), 40);
    });
    test('high responsiveness (mod ~1.49) relieves 60', () {
      expect(cureRelief(1.49), 60);
    });
    test('higher responsiveness strictly relieves more', () {
      expect(cureRelief(1.49), greaterThan(cureRelief(0.5)));
    });
  });

  group('cureDelta', () {
    // Oracle = the plan's contract: illness falls by cureRelief (clamp-encoded
    // at the 0 floor); hunger, energy and love never move. Cure costs no energy
    // (FR-006) and adds no randomness.
    test('a sick creature heals: illness drops, other stats untouched', () {
      final delta = cureDelta(
        _creature(illness: 70, energy: 100, hunger: 20, love: 50),
        _personality(1.0),
      );
      expect(delta.illnessDelta, -40); // 70 -> 30
      expect(delta.energyDelta, 0);
      expect(delta.hungerDelta, 0);
      expect(delta.loveDelta, 0);
    });

    test('illness clamps at 0: relief never drives illness negative', () {
      // illness 30 - 40 = -10 -> clamps to 0, so the delta is only -30.
      final delta = cureDelta(_creature(illness: 30), _personality(1.0));
      expect(delta.illnessDelta, -30);
    });

    test('already healthy (illness 0): zero relief, no stat moves', () {
      final delta = cureDelta(_creature(illness: 0), _personality(1.0));
      expect(delta.illnessDelta, 0);
      expect(delta.energyDelta, 0);
      expect(delta.hungerDelta, 0);
      expect(delta.loveDelta, 0);
    });

    test('illnessDelta is never positive (cure only ever helps)', () {
      for (final illness in [0, 10, 50, 100]) {
        expect(
          cureDelta(
            _creature(illness: illness),
            _personality(1.0),
          ).illnessDelta,
          lessThanOrEqualTo(0),
        );
      }
    });

    test('higher responsiveness heals strictly more from the same illness', () {
      final responsive = cureDelta(_creature(illness: 90), _personality(1.49));
      final sluggish = cureDelta(_creature(illness: 90), _personality(0.5));
      // illnessDelta is negative; healing MORE means a more-negative delta.
      expect(responsive.illnessDelta, lessThan(sluggish.illnessDelta));
    });

    test('energy is never read as a guard: cure heals at energy 0', () {
      final delta = cureDelta(
        _creature(illness: 70, energy: 0),
        _personality(1.0),
      );
      expect(delta.illnessDelta, -40);
      expect(delta.energyDelta, 0);
    });
  });

  group('cure_copy', () {
    // Oracle = the plan's Phase 1 contract: four cure strings (degrade pair +
    // stub pair), all non-empty, and distinct from feed's and play's stub
    // strings so integration assertions can tell the cure path apart.
    test('all four strings are non-empty', () {
      expect(cure.degradeUserResponse.trim(), isNotEmpty);
      expect(cure.degradeJournalNarrative.trim(), isNotEmpty);
      expect(cure.stubUserResponse.trim(), isNotEmpty);
      expect(cure.stubJournalNarrative.trim(), isNotEmpty);
    });

    test('cure stub strings are distinct from feed and play stub strings', () {
      expect(cure.stubUserResponse, isNot(feed.stubAcceptUserResponse));
      expect(cure.stubUserResponse, isNot(feed.stubRefuseUserResponse));
      expect(cure.stubUserResponse, isNot(play.stubUserResponse));
      expect(cure.stubJournalNarrative, isNot(play.stubJournalNarrative));
    });

    test('cure degrade and stub strings are distinguishable', () {
      // The degrade path and the stub path must not collide, so a test can tell
      // a real-stub run from an LLM-failure run.
      expect(cure.stubUserResponse, isNot(cure.degradeUserResponse));
      expect(cure.stubJournalNarrative, isNot(cure.degradeJournalNarrative));
    });
  });
}
