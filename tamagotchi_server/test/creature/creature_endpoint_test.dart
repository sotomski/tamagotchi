import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/creature_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../integration/test_tools/serverpod_test_tools.dart';

/// Returns a session builder authenticated as [userUuid] with no extra scopes —
/// enough to satisfy `requireLogin`.
TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

void main() {
  withServerpod('Given CreatureEndpoint', (sessionBuilder, endpoints) {
    test(
      'when hatching then it creates the creature with baseline stats, '
      'content mood, a personality row, and a single hatched journal marker',
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
        expect(journal.single.prose, '');
        expect(journal.single.statDelta, isNull);
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
