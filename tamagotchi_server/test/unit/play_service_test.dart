import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/play_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/feed_copy.dart' as feed;
import 'package:tamagotchi_server/src/llm/play_copy.dart' as play;
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

import '../helpers/scripted_random.dart';

const _ownerUuid = '00000000-0000-0000-0000-000000000001';
const _creatureId = '00000000-0000-0000-0000-000000000002';

/// A creature with the given volatile stats; the rest are fixed placeholders the
/// play math never reads.
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

/// A personality with the given `loveRegenMod` (the only field play math reads,
/// the introvert↔extravert axis); the other six mods are inert here.
CreaturePersonality _personality(double loveRegenMod) => CreaturePersonality(
  creatureId: UuidValue.fromString(_creatureId),
  hungerDecayMod: 1.0,
  hungerRegenMod: 1.0,
  energyDecayMod: 1.0,
  energyRegenMod: 1.0,
  loveRegenMod: loveRegenMod,
  illnessDecayMod: 1.0,
  illnessRegenMod: 1.0,
);

void main() {
  group('playLoveGain', () {
    // Oracle = the plan's contract: round(basePlayLove * loveRegenMod), with
    // basePlayLove = 15, over the personality range loveRegenMod∈[0.5,1.5).
    // Monotone ↑: an extravert (high mod) gains more love than an introvert.
    test('introvert (mod 0.5) gains 8', () {
      expect(playLoveGain(0.5), 8);
    });
    test('baseline (mod 1.0) gains 15', () {
      expect(playLoveGain(1.0), 15);
    });
    test('extravert (mod ~1.49) gains 22', () {
      expect(playLoveGain(1.49), 22);
    });
    test('extravert strictly gains more love than introvert', () {
      expect(playLoveGain(1.49), greaterThan(playLoveGain(0.5)));
    });
  });

  group('playEnergyCost', () {
    // Oracle = the plan's contract: round(basePlayEnergy * (2 - loveRegenMod)),
    // with basePlayEnergy = 4. Monotone ↓: an introvert (low mod) tires more, so
    // it pays MORE energy than an extravert.
    test('introvert (mod 0.5) costs 6', () {
      expect(playEnergyCost(0.5), 6);
    });
    test('baseline (mod 1.0) costs 4', () {
      expect(playEnergyCost(1.0), 4);
    });
    test('extravert (mod ~1.49) costs 2', () {
      expect(playEnergyCost(1.49), 2);
    });
    test('introvert strictly costs more energy than extravert', () {
      expect(playEnergyCost(0.5), greaterThan(playEnergyCost(1.49)));
    });
  });

  group('playDelta', () {
    // Oracle = the plan's contract: love rises by playLoveGain, energy falls by
    // playEnergyCost, both clamp-encoded; hunger and illness never move.
    test(
      'baseline play raises love and lowers energy, leaves hunger/illness',
      () {
        final delta = playDelta(
          _creature(love: 50, energy: 100, hunger: 20, illness: 0),
          _personality(1.0),
        );
        expect(delta.loveDelta, 15); // 50 -> 65
        expect(delta.energyDelta, -4); // 100 -> 96
        expect(delta.hungerDelta, 0);
        expect(delta.illnessDelta, 0);
      },
    );

    test('love clamps at 100: a fully-loved creature gains zero love', () {
      final delta = playDelta(_creature(love: 100), _personality(1.0));
      // clampStat(100 + 15) - 100 = 100 - 100 = 0.
      expect(delta.loveDelta, 0);
      // energy still costs (no gate).
      expect(delta.energyDelta, -4);
    });

    test('love clamps at 100 from just-below too', () {
      // love 90 + 15 = 105 -> clamps to 100, so the delta is only +10.
      final delta = playDelta(_creature(love: 90), _personality(1.0));
      expect(delta.loveDelta, 10);
    });

    test('energy clamps at 0: a near-exhausted creature never goes negative', () {
      // energy 3 - 6 = -3 -> clamps to 0, so the delta is the clamped distance -3.
      final delta = playDelta(
        _creature(energy: 3),
        _personality(0.5), // introvert: playEnergyCost = 6
      );
      expect(delta.energyDelta, -3);
    });

    test('extravert gains more love and spends less energy than introvert', () {
      final extravert = playDelta(
        _creature(love: 50, energy: 100),
        _personality(1.49),
      );
      final introvert = playDelta(
        _creature(love: 50, energy: 100),
        _personality(0.5),
      );
      expect(extravert.loveDelta, greaterThan(introvert.loveDelta));
      // energyDelta is negative; spending LESS energy means a delta closer to 0.
      expect(extravert.energyDelta, greaterThan(introvert.energyDelta));
    });
  });

  group('play_copy', () {
    // Oracle = the plan's Phase 2 contract: four play strings (degrade pair +
    // stub pair), all non-empty, and distinct from feed's stub strings so
    // integration assertions can tell the play path from the feed path.
    test('all four strings are non-empty', () {
      expect(play.degradeUserResponse.trim(), isNotEmpty);
      expect(play.degradeJournalNarrative.trim(), isNotEmpty);
      expect(play.stubUserResponse.trim(), isNotEmpty);
      expect(play.stubJournalNarrative.trim(), isNotEmpty);
    });

    test('play stub strings are distinct from feed stub strings', () {
      expect(play.stubUserResponse, isNot(feed.stubAcceptUserResponse));
      expect(play.stubUserResponse, isNot(feed.stubRefuseUserResponse));
      expect(play.stubJournalNarrative, isNot(feed.stubAcceptJournalNarrative));
      expect(play.stubJournalNarrative, isNot(feed.stubRefuseJournalNarrative));
    });

    test('play degrade and stub strings are distinguishable', () {
      // The degrade path and the stub path must not collide, so a test can tell
      // a real-stub run from an LLM-failure run.
      expect(play.stubUserResponse, isNot(play.degradeUserResponse));
      expect(play.stubJournalNarrative, isNot(play.degradeJournalNarrative));
    });

    group('playExhaustedLines', () {
      // Oracle = the plan's Phase 1 contract (FR-007): ~10 play+tired lines, all
      // non-empty, flat pre-written copy for the energy-gate path (no LLM).
      test('has 10-20 entries', () {
        expect(play.playExhaustedLines.length, inInclusiveRange(10, 20));
      });

      test('every line is non-empty and trimmed', () {
        for (final line in play.playExhaustedLines) {
          expect(line.trim(), isNotEmpty);
        }
      });

      test('lines are distinct (no accidental duplicates)', () {
        expect(
          play.playExhaustedLines.toSet(),
          hasLength(play.playExhaustedLines.length),
        );
      });
    });
  });

  group('PlayService.exhaustedLine', () {
    // Mirrors FeedService.fullRefusalLine: picks a member of playExhaustedLines
    // off the injected Random via nextInt only — it must draw NO nextDouble (an
    // empty ScriptedRandom throws if it does), so the stat path stays RNG-free.
    test('returns a member of playExhaustedLines and draws no nextDouble', () {
      final service = PlayService(
        rng: ScriptedRandom(const []),
        llm: const StubLlmService(),
      );
      expect(service.exhaustedLine(), isIn(play.playExhaustedLines));
    });
  });
}
