import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/pet_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:tamagotchi_server/src/llm/pet_copy.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// An [LlmService] that always throws, to drive the degrade path: the endpoint
/// must catch this, substitute canned pet copy, and still commit the
/// stat+journal pair.
class _ThrowingLlmService implements LlmService {
  const _ThrowingLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async => throw Exception('model unreachable');
}

/// Reassigns the production [petServiceFactory] seam to inject a [PetService]
/// with (by default) the hermetic [StubLlmService]. Pet has no rng seam — it is
/// deterministic — so the only injected collaborator is the LLM.
void _injectPetService({LlmService llm = const StubLlmService()}) {
  petServiceFactory = (_) => PetService(llm: llm);
  // Self-cleaning: restore production wiring when this test ends, even on
  // failure, so a fake never leaks into the next sequential test.
  addTearDown(() => petServiceFactory = petServiceFor);
}

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature + its 1:1 personality directly (bypassing hatch so the test
/// controls `love`, `energy`, and `loveRegenMod` — the inputs the pet math
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

Future<List<JournalEntry>> _petEntries(
  Session session,
  UuidValue creatureId,
) => JournalEntry.db.find(
  session,
  where: (t) =>
      t.creatureId.equals(creatureId) & t.event.equals(JournalEvent.pet),
);

void main() {
  withServerpod('Given CreatureEndpoint.pet', (sessionBuilder, endpoints) {
    test(
      'an accepted pet raises love +15 / lowers energy -4 (baseline), leaves '
      'hunger+illness, writes exactly one pet entry with the matching delta + '
      'prose, and re-derives mood',
      () async {
        _injectPetService();
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

        final result = await endpoints.creature.pet(authed);

        // Returned outcome: stub pet copy + post-pet stats + mood.
        expect(result.userResponse, stubUserResponse);
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

        // Exactly one pet entry, matching delta, non-empty prose.
        final entries = await _petEntries(session, creature.id!);
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
        _injectPetService();
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

        await endpoints.creature.pet(_authedAs(sessionBuilder, introUuid));
        await endpoints.creature.pet(_authedAs(sessionBuilder, extraUuid));

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
      'max-love (love==100): love delta is zero, energy still costs, a pet entry '
      'is still written, and the LLM is still called (no gate)',
      () async {
        _injectPetService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          love: 100,
          energy: 100,
        );

        final result = await endpoints.creature.pet(authed);

        // Love holds at 100; energy still costs.
        expect(result.status.creature.love, 100);
        expect(result.status.creature.energy, 96);
        // The LLM WAS called — stub copy proves no max-love short-circuit.
        expect(result.userResponse, stubUserResponse);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.love, 100);
        expect(stored.energy, 96);

        // A pet entry is still written, with a zero love delta.
        final entries = await _petEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.statDelta!.loveDelta, 0);
        expect(entries.single.statDelta!.energyDelta, -4);
        expect(entries.single.prose, stubJournalNarrative);
      },
    );

    test(
      'when the model call fails the pet degrades: stats still change, a pet '
      'entry lands with the degrade prose, and pet() does not throw',
      () async {
        _injectPetService(llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          love: 50,
          energy: 100,
        );

        final result = await endpoints.creature.pet(authed);

        expect(result.userResponse, degradeUserResponse);
        // Stats still change despite the model failure.
        expect(result.status.creature.love, 65);
        expect(result.status.creature.energy, 96);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.love, 65);
        expect(stored.energy, 96);

        final entries = await _petEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.prose, degradeJournalNarrative);
        expect(entries.single.statDelta!.loveDelta, 15);
        expect(entries.single.statDelta!.energyDelta, -4);
      },
    );

    test(
      'petting with no creature throws CreaturePetError(noCreature)',
      () async {
        _injectPetService();
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await expectLater(
          () => endpoints.creature.pet(authed),
          throwsA(
            isA<CreaturePetError>().having(
              (e) => e.reason,
              'reason',
              CreaturePetErrorReason.noCreature,
            ),
          ),
        );
      },
    );

    test(
      "pet is owner-scoped: petting as user B never touches user A's creature",
      () async {
        _injectPetService();
        final userA = const Uuid().v4();
        final userB = const Uuid().v4();
        final session = sessionBuilder.build();
        final creatureA = await _seedCreature(session, userA, love: 50);
        final creatureB = await _seedCreature(session, userB, love: 50);

        // B pets — only B's creature should change.
        await endpoints.creature.pet(_authedAs(sessionBuilder, userB));

        final storedA = await Creature.db.findById(session, creatureA.id!);
        final storedB = await Creature.db.findById(session, creatureB.id!);
        expect(storedA!.love, 50, reason: "A's creature must be untouched");
        expect(storedB!.love, 65, reason: "B's creature was petted");

        expect(await _petEntries(session, creatureA.id!), isEmpty);
        expect(await _petEntries(session, creatureB.id!), hasLength(1));
      },
    );
  });
}
