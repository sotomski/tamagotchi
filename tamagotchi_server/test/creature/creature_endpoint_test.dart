import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/creature_endpoint.dart';
import 'package:tamagotchi_server/src/creature/creature_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/hatch_copy.dart' as hatch;
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:test/test.dart';

import '../integration/test_tools/serverpod_test_tools.dart';

/// An [LlmService] that always throws, to drive hatch's block-on-failure path:
/// the birth narrative can't be generated, so hatch must abort and write nothing.
class _ThrowingLlmService implements LlmService {
  const _ThrowingLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async => throw Exception('model unreachable');
}

/// Returns a session builder authenticated as [userUuid] with no extra scopes —
/// enough to satisfy `requireLogin`.
TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature + its 1:1 personality directly (bypassing hatch so the test
/// controls `energy` and `loveRegenMod` — the inputs the affordability gate
/// reads). `lastDecayedAt` defaults to now, so no decay tick fires before the
/// read and the seeded `energy` is what the affordability booleans see.
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  required int energy,
  double loveRegenMod = 1.0,
}) async {
  final creature = await Creature.db.insertRow(
    session,
    Creature(
      ownerUuid: UuidValue.fromString(userUuid),
      name: 'Testy',
      hunger: 20,
      energy: energy,
      love: 50,
      illness: 0,
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

void main() {
  withServerpod('Given CreatureEndpoint', (sessionBuilder, endpoints) {
    test(
      'when hatching then it creates the creature with baseline stats, '
      'content mood, a personality row, and a single hatched journal marker '
      'carrying the LLM-generated birth prose',
      () async {
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);

        final status = await endpoints.creature.hatch(authed, 'Nibbles');

        // Returned status: name, baseline stats, derived mood.
        expect(status.creature.name, 'Nibbles');
        expect(status.creature.hunger, 0);
        expect(status.creature.energy, 100);
        expect(status.creature.love, 50);
        expect(status.creature.illness, 0);
        expect(status.creature.ownerUuid.uuid, userUuid);
        expect(status.mood, CreatureMood.content);

        // Side effects: exactly one personality row and one hatched marker.
        final session = authed.build();
        final personalities = await CreaturePersonality.db.find(
          session,
          where: (t) => t.creatureId.equals(status.creature.id!),
        );
        expect(personalities, hasLength(1));

        final journal = await JournalEntry.db.find(
          session,
          where: (t) => t.creatureId.equals(status.creature.id!),
        );
        expect(journal, hasLength(1));
        expect(journal.single.event, JournalEvent.hatched);
        // The birth marker now carries real, LLM-generated prose (the hermetic
        // stub's birth narrative in the test run mode) — no longer the blank ''.
        expect(journal.single.prose, isNotEmpty);
        expect(journal.single.prose, hatch.stubJournalNarrative);
        // A birth records no stat change.
        expect(journal.single.statDelta, isNull);
      },
    );

    test(
      'when the birth-narrative LLM fails then hatch blocks (narrativeUnavailable) '
      'and writes no creature, personality, or journal row',
      () async {
        // Inject a throwing LLM via the production seam; restore it after.
        hatchLlmServiceFactory = (_) => const _ThrowingLlmService();
        addTearDown(() => hatchLlmServiceFactory = llmServiceFor);

        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);

        await expectLater(
          () => endpoints.creature.hatch(authed, 'Nibbles'),
          throwsA(
            isA<CreatureHatchError>().having(
              (e) => e.reason,
              'reason',
              CreatureHatchErrorReason.narrativeUnavailable,
            ),
          ),
        );

        // Block-on-failure leaves NO partial state: the LLM call runs before the
        // transaction, so a thrown birth narrative writes nothing at all.
        final session = authed.build();
        final owner = UuidValue.fromString(userUuid);
        expect(
          await Creature.db.find(
            session,
            where: (t) => t.ownerUuid.equals(owner),
          ),
          isEmpty,
        );
        expect(
          await JournalEntry.db.find(
            session,
            where: (t) => t.ownerUuid.equals(owner),
          ),
          isEmpty,
        );
      },
    );

    test(
      'when hatching a second time then it is rejected as alreadyHatched',
      () async {
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await endpoints.creature.hatch(authed, 'Nibbles');

        await expectLater(
          () => endpoints.creature.hatch(authed, 'Spot'),
          throwsA(
            isA<CreatureHatchError>().having(
              (e) => e.reason,
              'reason',
              CreatureHatchErrorReason.alreadyHatched,
            ),
          ),
        );
      },
    );

    test(
      'when hatching with a blank name then it is rejected as emptyName',
      () async {
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await expectLater(
          () => endpoints.creature.hatch(authed, '   '),
          throwsA(
            isA<CreatureHatchError>().having(
              (e) => e.reason,
              'reason',
              CreatureHatchErrorReason.emptyName,
            ),
          ),
        );
      },
    );

    test(
      'myCreature returns null before hatch then the creature with mood',
      () async {
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        expect(await endpoints.creature.myCreature(authed), isNull);

        await endpoints.creature.hatch(authed, 'Nibbles');

        final status = await endpoints.creature.myCreature(authed);
        expect(status, isNotNull);
        expect(status!.creature.name, 'Nibbles');
        expect(status.mood, CreatureMood.content);
      },
    );

    test(
      'myCreature reports canFeed/canPlay affordability across an energy sweep '
      '(feedEnergyCost=10, playEnergyCost(1.0)=4)',
      () async {
        // (energy, canFeed, canPlay): feed needs >=10, play needs >=4 at the
        // baseline loveRegenMod=1.0.
        const cases = [
          (0, false, false),
          (3, false, false),
          (4, false, true),
          (5, false, true),
          (9, false, true),
          (10, true, true),
          (100, true, true),
        ];
        for (final (energy, canFeed, canPlay) in cases) {
          final userUuid = const Uuid().v4();
          final authed = _authedAs(sessionBuilder, userUuid);
          final session = authed.build();
          await _seedCreature(session, userUuid, energy: energy);

          final status = await endpoints.creature.myCreature(authed);

          expect(
            status!.canFeed,
            canFeed,
            reason: 'energy $energy → canFeed should be $canFeed',
          );
          expect(
            status.canPlay,
            canPlay,
            reason: 'energy $energy → canPlay should be $canPlay',
          );
        }
      },
    );

    // The double-hatch race can't be driven through two concurrent endpoint
    // calls here — the rollback harness forbids concurrent DB calls — so this
    // pins the load-bearing fact deterministically instead: a real duplicate
    // ownerUuid insert raises the live Postgres unique violation, and the
    // backstop's trigger recognises *that real error* (real SQLSTATE 23505),
    // not just a fabricated one. The endpoint then confirms the race by
    // re-reading the owner's creature and surfaces the typed alreadyHatched.
    test('a duplicate-owner insert raises a unique violation the backstop '
        'recognises as a unique violation', () async {
      final owner = UuidValue.fromString(const Uuid().v4());
      final session = sessionBuilder.build();

      Creature seed(String name) => Creature(
        ownerUuid: owner,
        name: name,
        hunger: baselineCreatureStats.hunger,
        energy: baselineCreatureStats.energy,
        love: baselineCreatureStats.love,
        illness: baselineCreatureStats.illness,
      );

      await Creature.db.insertRow(session, seed('first'));

      Object? caught;
      try {
        await Creature.db.insertRow(session, seed('second'));
      } catch (e) {
        caught = e;
      }

      expect(
        caught,
        isA<DatabaseQueryException>(),
        reason: 'the owner unique index should reject the duplicate row',
      );
      expect(isUniqueViolation(caught!), isTrue);
    });
  });
}
