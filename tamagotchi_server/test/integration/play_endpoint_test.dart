import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/play_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:tamagotchi_server/src/llm/play_copy.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

import '../helpers/scripted_random.dart';
import 'test_tools/serverpod_test_tools.dart';

/// An [LlmService] that always throws, to drive the degrade path: the endpoint
/// must catch this, substitute canned play copy, and still commit the
/// stat+journal pair.
class _ThrowingLlmService implements LlmService {
  const _ThrowingLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async => throw Exception('model unreachable');
}

/// Reassigns the production [playServiceFactory] seam to inject a [PlayService]
/// with (by default) the hermetic [StubLlmService]. Play has no rng seam — it is
/// deterministic — so the only injected collaborator is the LLM.
void _injectPlayService({LlmService llm = const StubLlmService()}) {
  // Play is deterministic — the rng feeds only the blocked-path exhaustedLine()
  // pick (nextInt), never the stat math, so an empty ScriptedRandom is safe: it
  // throws if a nextDouble is ever drawn, asserting the stat path stays RNG-free.
  playServiceFactory = (_) =>
      PlayService(rng: ScriptedRandom(const []), llm: llm);
  // Self-cleaning: restore production wiring when this test ends, even on
  // failure, so a fake never leaks into the next sequential test.
  addTearDown(() => playServiceFactory = playServiceFor);
}

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature + its 1:1 personality directly (bypassing hatch so the test
/// controls `love`, `energy`, and `loveRegenMod` — the inputs the play math
/// reads).
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  int love = 50,
  int energy = 100,
  int hunger = 20,
  int illness = 0,
  double loveRegenMod = 1.0,
}) async {
  final creature = await Creature.db.insertRow(
    session,
    Creature(
      ownerUuid: UuidValue.fromString(userUuid),
      name: 'Testy',
      hunger: hunger,
      energy: energy,
      love: love,
      illness: illness,
    ),
  );
  await CreaturePersonality.db.insertRow(
    session,
    CreaturePersonality(
      creatureId: creature.id!,
      hungerDecayMod: 1.0,
      hungerRegenMod: 1.0,
      energyDecayMod: 1.0,
      energyRegenMod: 1.0,
      loveRegenMod: loveRegenMod,
      illnessDecayMod: 1.0,
      illnessRegenMod: 1.0,
    ),
  );
  return creature;
}

Future<List<JournalEntry>> _playEntries(
  Session session,
  UuidValue creatureId,
) => JournalEntry.db.find(
  session,
  where: (t) =>
      t.creatureId.equals(creatureId) & t.event.equals(JournalEvent.play),
);

void main() {
  withServerpod('Given CreatureEndpoint.play', (sessionBuilder, endpoints) {
    test(
      'an accepted play raises love +15 / lowers energy -4 (baseline), leaves '
      'hunger+illness, writes exactly one play entry with the matching delta + '
      'prose, and re-derives mood',
      () async {
        _injectPlayService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          love: 50,
          energy: 100,
          hunger: 20,
        );

        final result = await endpoints.creature.play(authed);

        // Returned outcome: stub play copy + post-play stats + mood.
        expect(result.userResponse, stubUserResponse);
        expect(result.exhausted, isFalse); // affordable: gate did not fire
        expect(result.status.canPlay, isTrue); // energy 100 >= cost
        expect(result.status.creature.love, 65); // +15
        expect(result.status.creature.energy, 96); // -4
        expect(result.status.creature.hunger, 20); // untouched
        expect(result.status.creature.illness, 0); // untouched
        // deriveMood(20, 96, 65, 0): worst distress = 100-65 = 35 ⇒ content.
        expect(result.status.mood, CreatureMood.content);

        // Persisted stat change.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.love, 65);
        expect(stored.energy, 96);

        // Exactly one play entry, matching delta, non-empty prose.
        final entries = await _playEntries(session, creature.id!);
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.prose, stubJournalNarrative);
        expect(entry.prose, isNotEmpty);
        expect(entry.statDelta!.loveDelta, 15);
        expect(entry.statDelta!.energyDelta, -4);
        expect(entry.statDelta!.hungerDelta, 0);
        expect(entry.statDelta!.illnessDelta, 0);
      },
    );

    test(
      'an introvert gains less love and loses more energy than an extravert '
      '(FR-005 sociability axis)',
      () async {
        _injectPlayService();
        final introUuid = const Uuid().v4();
        final extraUuid = const Uuid().v4();
        final session = sessionBuilder.build();
        final intro = await _seedCreature(
          session,
          introUuid,
          love: 50,
          energy: 100,
          loveRegenMod: 0.5, // introvert
        );
        final extra = await _seedCreature(
          session,
          extraUuid,
          love: 50,
          energy: 100,
          loveRegenMod: 1.49, // extravert
        );

        await endpoints.creature.play(_authedAs(sessionBuilder, introUuid));
        await endpoints.creature.play(_authedAs(sessionBuilder, extraUuid));

        final storedIntro = await Creature.db.findById(session, intro.id!);
        final storedExtra = await Creature.db.findById(session, extra.id!);
        // introvert +8 -> 58; extravert +22 -> 72.
        expect(storedIntro!.love, 58);
        expect(storedExtra!.love, 72);
        expect(storedExtra.love, greaterThan(storedIntro.love));
        // introvert -6 -> 94; extravert -2 -> 98 (introvert tires more).
        expect(storedIntro.energy, 94);
        expect(storedExtra.energy, 98);
        expect(storedExtra.energy, greaterThan(storedIntro.energy));
      },
    );

    test(
      'max-love (love==100): love delta is zero, energy still costs, a play entry '
      'is still written, and the LLM is still called (no gate)',
      () async {
        _injectPlayService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          love: 100,
          energy: 100,
        );

        final result = await endpoints.creature.play(authed);

        // Love holds at 100; energy still costs.
        expect(result.status.creature.love, 100);
        expect(result.status.creature.energy, 96);
        // The LLM WAS called — stub copy proves no max-love short-circuit.
        expect(result.userResponse, stubUserResponse);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.love, 100);
        expect(stored.energy, 96);

        // A play entry is still written, with a zero love delta.
        final entries = await _playEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.statDelta!.loveDelta, 0);
        expect(entries.single.statDelta!.energyDelta, -4);
        expect(entries.single.prose, stubJournalNarrative);
      },
    );

    test(
      'when the model call fails the play degrades: stats still change, a play '
      'entry lands with the degrade prose, and play() does not throw',
      () async {
        _injectPlayService(llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          love: 50,
          energy: 100,
        );

        final result = await endpoints.creature.play(authed);

        expect(result.userResponse, degradeUserResponse);
        // Stats still change despite the model failure.
        expect(result.status.creature.love, 65);
        expect(result.status.creature.energy, 96);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.love, 65);
        expect(stored.energy, 96);

        final entries = await _playEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.prose, degradeJournalNarrative);
        expect(entries.single.statDelta!.loveDelta, 15);
        expect(entries.single.statDelta!.energyDelta, -4);
      },
    );

    test(
      'an exhausted creature (energy < playEnergyCost) is gated: a canned '
      'exhausted line, no LLM call, no journal entry, no stat change, '
      'exhausted flag true, and canPlay false',
      () async {
        // playEnergyCost(1.0) = 4; energy 3 < 4. The throwing LLM proves the
        // model is never reached (a regressed gate would return the degrade line
        // and write an entry); the empty ScriptedRandom in _injectPlayService
        // throws if the deterministic stat path ever drew a nextDouble.
        _injectPlayService(llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          love: 50,
          energy: 3,
        );

        final result = await endpoints.creature.play(authed);

        expect(result.exhausted, isTrue);
        expect(result.userResponse, isIn(playExhaustedLines));
        expect(result.status.canPlay, isFalse);
        // Stats unchanged on the returned status.
        expect(result.status.creature.energy, 3);
        expect(result.status.creature.love, 50);

        // Nothing persisted: stats untouched, no play journal entry.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.energy, 3);
        expect(stored.love, 50);
        expect(await _playEntries(session, creature.id!), isEmpty);
      },
    );

    test(
      'playing with no creature throws CreaturePlayError(noCreature)',
      () async {
        _injectPlayService();
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await expectLater(
          () => endpoints.creature.play(authed),
          throwsA(
            isA<CreaturePlayError>().having(
              (e) => e.reason,
              'reason',
              CreaturePlayErrorReason.noCreature,
            ),
          ),
        );
      },
    );

    test(
      "play is owner-scoped: playing as user B never touches user A's creature",
      () async {
        _injectPlayService();
        final userA = const Uuid().v4();
        final userB = const Uuid().v4();
        final session = sessionBuilder.build();
        final creatureA = await _seedCreature(session, userA, love: 50);
        final creatureB = await _seedCreature(session, userB, love: 50);

        // B plays — only B's creature should change.
        await endpoints.creature.play(_authedAs(sessionBuilder, userB));

        final storedA = await Creature.db.findById(session, creatureA.id!);
        final storedB = await Creature.db.findById(session, creatureB.id!);
        expect(storedA!.love, 50, reason: "A's creature must be untouched");
        expect(storedB!.love, 65, reason: "B's creature was playted");

        expect(await _playEntries(session, creatureA.id!), isEmpty);
        expect(await _playEntries(session, creatureB.id!), hasLength(1));
      },
    );
  });
}
