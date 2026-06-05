import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'creature_service.dart';

/// The first first-party `requireLogin` endpoint: hatch a creature and view it.
///
/// Both methods bundle the persisted creature with its derived mood (mood is
/// computed on read, never stored).
class CreatureEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Hatches the caller's one and only creature and returns its status.
  ///
  /// Rejects a blank [name] and a caller who already owns a creature. The three
  /// inserts (creature, personality, hatched journal marker) run in one
  /// transaction; the `ownerUuid` unique index is the race-safe backstop behind
  /// the non-atomic app pre-check.
  Future<CreatureStatus> hatch(Session session, String name) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw CreatureHatchError(reason: CreatureHatchErrorReason.emptyName);
    }

    final existing = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    if (existing != null) {
      throw CreatureHatchError(reason: CreatureHatchErrorReason.alreadyHatched);
    }

    final mods = randomPersonalityModifiers(Random());

    final creature = await session.db.transaction((transaction) async {
      final created = await Creature.db.insertRow(
        session,
        Creature(
          ownerUuid: ownerUuid,
          name: trimmedName,
          hunger: baselineCreatureStats.hunger,
          energy: baselineCreatureStats.energy,
          love: baselineCreatureStats.love,
          illness: baselineCreatureStats.illness,
        ),
        transaction: transaction,
      );

      await CreaturePersonality.db.insertRow(
        session,
        CreaturePersonality(
          creatureId: created.id!,
          hungerDecayMod: mods.hungerDecayMod,
          hungerRegenMod: mods.hungerRegenMod,
          energyDecayMod: mods.energyDecayMod,
          energyRegenMod: mods.energyRegenMod,
          loveDecayMod: mods.loveDecayMod,
          loveRegenMod: mods.loveRegenMod,
          illnessDecayMod: mods.illnessDecayMod,
          illnessRegenMod: mods.illnessRegenMod,
        ),
        transaction: transaction,
      );

      await JournalEntry.db.insertRow(
        session,
        JournalEntry(
          creatureId: created.id!,
          ownerUuid: ownerUuid,
          event: JournalEvent.hatched,
          prose: '',
          statDelta: null,
        ),
        transaction: transaction,
      );

      return created;
    });

    return CreatureStatus(creature: creature, mood: _moodOf(creature));
  }

  /// Returns the caller's creature with its derived mood, or null if none.
  Future<CreatureStatus?> myCreature(Session session) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final creature = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    if (creature == null) return null;

    return CreatureStatus(creature: creature, mood: _moodOf(creature));
  }

  CreatureMood _moodOf(Creature c) =>
      deriveMood(c.hunger, c.energy, c.love, c.illness);
}
