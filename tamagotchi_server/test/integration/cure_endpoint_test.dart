import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/cure_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/cure_copy.dart';
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// An [LlmService] that always throws, to drive the degrade path: the endpoint
/// must catch this, substitute canned cure copy, and still commit the
/// stat+journal pair.
class _ThrowingLlmService implements LlmService {
  const _ThrowingLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async => throw Exception('model unreachable');
}

/// Reassigns the production [cureServiceFactory] seam to inject a [CureService]
/// with (by default) the hermetic [StubLlmService]. Cure has no rng seam — it is
/// deterministic — so the only injected collaborator is the LLM.
void _injectCureService({LlmService llm = const StubLlmService()}) {
  cureServiceFactory = (_) => CureService(llm: llm);
  // Self-cleaning: restore production wiring when this test ends, even on
  // failure, so a fake never leaks into the next sequential test.
  addTearDown(() => cureServiceFactory = cureServiceFor);
}

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature + its 1:1 personality directly (bypassing hatch so the test
/// controls `illness`, `energy`, and `illnessDecayMod` — the inputs the cure
/// math reads).
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  int illness = 70,
  int energy = 100,
  int hunger = 20,
  int love = 50,
  double illnessDecayMod = 1.0,
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
      loveRegenMod: 1.0,
      illnessDecayMod: illnessDecayMod,
      illnessRegenMod: 1.0,
    ),
  );
  return creature;
}

Future<List<JournalEntry>> _cureEntries(
  Session session,
  UuidValue creatureId,
) => JournalEntry.db.find(
  session,
  where: (t) =>
      t.creatureId.equals(creatureId) & t.event.equals(JournalEvent.cure),
);

void main() {
  withServerpod('Given CreatureEndpoint.cure', (sessionBuilder, endpoints) {
    test(
      'a sick creature is cured: illness drops -40 (baseline), leaves '
      'energy+hunger+love, writes exactly one cure entry with the matching '
      'delta + prose, and re-derives mood',
      () async {
        _injectCureService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          illness: 70,
          energy: 100,
          hunger: 20,
          love: 50,
        );

        final result = await endpoints.creature.cure(authed);

        // Returned outcome: stub cure copy + post-cure stats + mood.
        expect(result.userResponse, stubUserResponse);
        expect(result.status.creature.illness, 30); // 70 - 40
        expect(result.status.creature.energy, 100); // untouched
        expect(result.status.creature.hunger, 20); // untouched
        expect(result.status.creature.love, 50); // untouched
        // deriveMood(20, 100, 50, 30): illness 30 < 50 ⇒ not sick; worst
        // distress = 100-50 = 50 ⇒ content.
        expect(result.status.mood, CreatureMood.content);

        // Persisted stat change.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.illness, 30);
        expect(stored.energy, 100);

        // Exactly one cure entry, matching delta, non-empty prose.
        final entries = await _cureEntries(session, creature.id!);
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.prose, stubJournalNarrative);
        expect(entry.prose, isNotEmpty);
        expect(entry.statDelta!.illnessDelta, -40);
        expect(entry.statDelta!.energyDelta, 0);
        expect(entry.statDelta!.hungerDelta, 0);
        expect(entry.statDelta!.loveDelta, 0);
      },
    );

    test(
      'a recovery-responsive creature heals more than a sluggish one (FR-006 '
      'illnessDecayMod axis)',
      () async {
        _injectCureService();
        final sluggishUuid = const Uuid().v4();
        final responsiveUuid = const Uuid().v4();
        final session = sessionBuilder.build();
        final sluggish = await _seedCreature(
          session,
          sluggishUuid,
          illness: 90,
          illnessDecayMod: 0.5, // sluggish recovery
        );
        final responsive = await _seedCreature(
          session,
          responsiveUuid,
          illness: 90,
          illnessDecayMod: 1.49, // responsive recovery
        );

        await endpoints.creature.cure(_authedAs(sessionBuilder, sluggishUuid));
        await endpoints.creature.cure(
          _authedAs(sessionBuilder, responsiveUuid),
        );

        final storedSluggish = await Creature.db.findById(
          session,
          sluggish.id!,
        );
        final storedResponsive = await Creature.db.findById(
          session,
          responsive.id!,
        );
        // sluggish relief 20 -> 70; responsive relief 60 -> 30.
        expect(storedSluggish!.illness, 70);
        expect(storedResponsive!.illness, 30);
        expect(
          storedResponsive.illness,
          lessThan(storedSluggish.illness),
          reason: 'a more recovery-responsive creature heals more per cure',
        );
      },
    );

    test(
      'already-healthy (illness==0): illness delta is zero, energy untouched, a '
      'cure entry is still written, and the LLM is still called (no gate)',
      () async {
        _injectCureService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          illness: 0,
          energy: 100,
        );

        final result = await endpoints.creature.cure(authed);

        // Illness holds at 0; energy untouched.
        expect(result.status.creature.illness, 0);
        expect(result.status.creature.energy, 100);
        // The LLM WAS called — stub copy proves no illness short-circuit.
        expect(result.userResponse, stubUserResponse);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.illness, 0);
        expect(stored.energy, 100);

        // A cure entry is still written, with a zero illness delta.
        final entries = await _cureEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.statDelta!.illnessDelta, 0);
        expect(entries.single.prose, stubJournalNarrative);
      },
    );

    test(
      'when the model call fails the cure degrades: stats still change, a cure '
      'entry lands with the degrade prose, and cure() does not throw',
      () async {
        _injectCureService(llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          illness: 70,
          energy: 100,
        );

        final result = await endpoints.creature.cure(authed);

        expect(result.userResponse, degradeUserResponse);
        // Stats still change despite the model failure.
        expect(result.status.creature.illness, 30);
        expect(result.status.creature.energy, 100);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.illness, 30);
        expect(stored.energy, 100);

        final entries = await _cureEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.prose, degradeJournalNarrative);
        expect(entries.single.statDelta!.illnessDelta, -40);
        expect(entries.single.statDelta!.energyDelta, 0);
      },
    );

    test(
      'curing with no creature throws CreatureCureError(noCreature)',
      () async {
        _injectCureService();
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await expectLater(
          () => endpoints.creature.cure(authed),
          throwsA(
            isA<CreatureCureError>().having(
              (e) => e.reason,
              'reason',
              CreatureCureErrorReason.noCreature,
            ),
          ),
        );
      },
    );

    test(
      "cure is owner-scoped: curing as user B never touches user A's creature",
      () async {
        _injectCureService();
        final userA = const Uuid().v4();
        final userB = const Uuid().v4();
        final session = sessionBuilder.build();
        final creatureA = await _seedCreature(session, userA, illness: 70);
        final creatureB = await _seedCreature(session, userB, illness: 70);

        // B cures — only B's creature should change.
        await endpoints.creature.cure(_authedAs(sessionBuilder, userB));

        final storedA = await Creature.db.findById(session, creatureA.id!);
        final storedB = await Creature.db.findById(session, creatureB.id!);
        expect(storedA!.illness, 70, reason: "A's creature must be untouched");
        expect(storedB!.illness, 30, reason: "B's creature was cured");

        expect(await _cureEntries(session, creatureA.id!), isEmpty);
        expect(await _cureEntries(session, creatureB.id!), hasLength(1));
      },
    );

    test(
      'cure succeeds at energy 0: no energy precondition (FR-006), illness still '
      'drops and energy stays 0',
      () async {
        _injectCureService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          illness: 70,
          energy: 0,
        );

        final result = await endpoints.creature.cure(authed);

        // Cure is not gated by energy — it heals and never charges energy.
        expect(result.userResponse, stubUserResponse);
        expect(result.status.creature.illness, 30);
        expect(result.status.creature.energy, 0);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.illness, 30);
        expect(stored.energy, 0);

        expect(await _cureEntries(session, creature.id!), hasLength(1));
      },
    );
  });
}
