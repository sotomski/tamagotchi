import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/llm_service.dart';
import 'creature_service.dart';
import 'feed_service.dart';
import 'play_service.dart';

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

    final Creature creature;
    try {
      creature = await session.db.transaction((transaction) async {
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
    } catch (e) {
      // The non-atomic pre-check can be raced: a concurrent hatch may commit
      // between our check and insert, and the owner unique index then rejects
      // ours. Rather than parse the violation's table/constraint strings,
      // confirm the race by re-reading the owner's creature — a unique violation
      // that leaves a creature in place is a duplicate hatch and surfaces the
      // same typed error the pre-check throws; anything else propagates.
      if (isUniqueViolation(e)) {
        final raced = await Creature.db.findFirstRow(
          session,
          where: (t) => t.ownerUuid.equals(ownerUuid),
        );
        if (raced != null) {
          throw CreatureHatchError(
            reason: CreatureHatchErrorReason.alreadyHatched,
          );
        }
      }
      rethrow;
    }

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

  /// Feeds the caller's creature once and returns the in-character outcome.
  ///
  /// Rolls the picky/tastiness accept gate, asks the LLM for a response + journal
  /// narrative (degrading to canned copy on failure), and writes the stat change
  /// and journal entry as one coherent pair (mirroring [hatch]'s single
  /// transaction). All randomness and the model call are encapsulated in the
  /// [FeedService] obtained from [feedServiceFactory], so this method stays pure
  /// orchestration — production gets the real wiring, tests inject fakes.
  ///
  /// The LLM call sits **outside** the transaction so a degrade still commits the
  /// stat+journal pair atomically — a stat change never lands without its entry.
  Future<FeedResult> feed(Session session) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final creature = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    if (creature == null) {
      throw CreatureFeedError(reason: CreatureFeedErrorReason.noCreature);
    }

    final personality = await CreaturePersonality.db.findFirstRow(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
    );
    if (personality == null) {
      // Personality is written 1:1 with the creature at hatch; its absence is a
      // data-integrity bug, not a user-facing path — fail loudly.
      throw StateError('Creature ${creature.id} has no personality row');
    }

    final feedService = feedServiceFactory(session);
    final decision = feedService.decide(creature, personality);

    // Already full: a cheap canned line — no LLM call, no journal entry, no stat
    // change.
    if (decision.full) {
      return FeedResult(
        userResponse: feedService.fullRefusalLine(),
        accepted: false,
        status: CreatureStatus(creature: creature, mood: _moodOf(creature)),
      );
    }

    // Short-term memory window (ORQ-1): the last 10 journal entries, newest
    // first, narrative prose only (the empty-prose hatched marker is dropped).
    final recent = await JournalEntry.db.find(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
      orderBy: (t) => t.timestamp,
      orderDescending: true,
      limit: 10,
    );
    final recentEntries = recent
        .map((e) => e.prose)
        .where((p) => p.isNotEmpty)
        .toList();

    final reply = await feedService.interaction(
      session,
      InteractionRequest(
        personality: personality,
        hunger: creature.hunger,
        energy: creature.energy,
        love: creature.love,
        illness: creature.illness,
        mood: _moodOf(creature),
        interactionType: JournalEvent.feed,
        accepted: decision.accepted,
        tastiness: decision.tastiness,
        recentEntries: recentEntries,
      ),
    );

    // Coherent pair: stat update (accepted only) + journal entry in one
    // transaction. The delta already encodes the 0-100 clamp, so adding it to the
    // current stat lands the clamped target directly.
    final updated = await session.db.transaction((transaction) async {
      var result = creature;
      if (decision.accepted) {
        result = creature.copyWith(
          hunger: creature.hunger + decision.delta.hungerDelta,
          energy: creature.energy + decision.delta.energyDelta,
        );
        await Creature.db.updateRow(session, result, transaction: transaction);
      }

      await JournalEntry.db.insertRow(
        session,
        JournalEntry(
          creatureId: creature.id!,
          ownerUuid: ownerUuid,
          event: JournalEvent.feed,
          prose: reply.journalNarrative,
          // Zero delta on a picky-refusal — the entry still records the refusal.
          statDelta: decision.delta,
        ),
        transaction: transaction,
      );

      return result;
    });

    return FeedResult(
      userResponse: reply.userResponse,
      accepted: decision.accepted,
      status: CreatureStatus(creature: updated, mood: _moodOf(updated)),
    );
  }

  /// Plays with the caller's creature once and returns the in-character outcome.
  ///
  /// Unlike [feed], Play is **fully deterministic** (`prd.md:39`): no
  /// accept/refuse gate and no max-love gate. The stat change ([playDelta] — love
  /// up, energy down, scaled by the `loveRegenMod` sociability axis) is computed
  /// up front, then the LLM is asked for a response + journal narrative (degrading
  /// to canned play copy on failure), and the stat change + journal entry are
  /// written as one coherent pair. The creature is **always** updated (energy
  /// always changes) and **always** gets exactly one `play` entry.
  ///
  /// As in [feed], the LLM call sits **outside** the transaction so a degrade
  /// still commits the stat+journal pair atomically.
  Future<PlayResult> play(Session session) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final creature = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    if (creature == null) {
      throw CreaturePlayError(reason: CreaturePlayErrorReason.noCreature);
    }

    final personality = await CreaturePersonality.db.findFirstRow(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
    );
    if (personality == null) {
      // Personality is written 1:1 with the creature at hatch; its absence is a
      // data-integrity bug, not a user-facing path — fail loudly (as in feed).
      throw StateError('Creature ${creature.id} has no personality row');
    }

    // Deterministic — no rng. The delta encodes the 0-100 clamp.
    final delta = playDelta(creature, personality);

    // Short-term memory window (ORQ-1): the last 10 narrative entries, newest
    // first (the empty-prose hatched marker is dropped).
    final recent = await JournalEntry.db.find(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
      orderBy: (t) => t.timestamp,
      orderDescending: true,
      limit: 10,
    );
    final recentEntries = recent
        .map((e) => e.prose)
        .where((p) => p.isNotEmpty)
        .toList();

    final reply = await playServiceFactory(session).interaction(
      session,
      InteractionRequest(
        personality: personality,
        hunger: creature.hunger,
        energy: creature.energy,
        love: creature.love,
        illness: creature.illness,
        mood: _moodOf(creature),
        interactionType: JournalEvent.play,
        accepted: true,
        // tastiness is feed-only; the play prompt branch ignores it.
        tastiness: 0,
        recentEntries: recentEntries,
      ),
    );

    // Coherent pair: the stat update (always — energy always changes) + the
    // journal entry in one transaction.
    final updated = await session.db.transaction((transaction) async {
      final result = creature.copyWith(
        love: creature.love + delta.loveDelta,
        energy: creature.energy + delta.energyDelta,
      );
      await Creature.db.updateRow(session, result, transaction: transaction);

      await JournalEntry.db.insertRow(
        session,
        JournalEntry(
          creatureId: creature.id!,
          ownerUuid: ownerUuid,
          event: JournalEvent.play,
          prose: reply.journalNarrative,
          statDelta: delta,
        ),
        transaction: transaction,
      );

      return result;
    });

    return PlayResult(
      userResponse: reply.userResponse,
      status: CreatureStatus(creature: updated, mood: _moodOf(updated)),
    );
  }

  CreatureMood _moodOf(Creature c) =>
      deriveMood(c.hunger, c.energy, c.love, c.illness);
}
