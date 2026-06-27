import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/llm_service.dart';
import 'creature_service.dart';
import 'cure_service.dart';
import 'decay_service.dart';
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

    // Birth narrative: a real LLM round-trip BEFORE the transaction (mirroring
    // feed's call-then-transaction ordering), so a failure throws and nothing is
    // written — no half-hatched creature. There is deliberately NO canned
    // fallback: hatch blocks on failure. The hermetic stub keeps dev/test/e2e
    // deterministic, so only a real-key production call can actually fail. The
    // rolled `mods` are simply discarded if this throws (no creature row exists).
    final ({String userResponse, String journalNarrative}) birth;
    try {
      birth = await hatchLlmServiceFactory(session).generateInteraction(
        session,
        _birthRequest(trimmedName, mods),
      );
    } catch (e, stackTrace) {
      session.log(
        'Hatch LLM call failed; blocking the hatch (no canned fallback)',
        level: LogLevel.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      throw CreatureHatchError(
        reason: CreatureHatchErrorReason.narrativeUnavailable,
      );
    }

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
            prose: birth.journalNarrative,
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

    return _statusFor(creature, mods.loveRegenMod);
  }

  /// Deletes the caller's creature, cascading to its personality and journal,
  /// returning the user to the creatureless (re-hatch) state.
  ///
  /// Idempotent: deleting zero rows is success, so calling reset with no creature
  /// is a silent no-op (FR-010). Wrapped in a transaction to keep the
  /// `creature_owner_idx` from a half state, mirroring [hatch]'s transactional
  /// write.
  Future<void> reset(Session session) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    // One owner-scoped delete: the `onDelete=Cascade` FKs on
    // `creature_personality` and `journal_entry` let Postgres remove the
    // personality and journal rows as the single creature row goes. Deleting
    // zero rows is success, so this is a no-op for a creatureless caller.
    await session.db.transaction(
      (transaction) => Creature.db.deleteWhere(
        session,
        where: (t) => t.ownerUuid.equals(ownerUuid),
        transaction: transaction,
      ),
    );
  }

  /// Returns the caller's creature with its derived mood, or null if none.
  ///
  /// Applies elapsed-time decay before returning: reads `now` through the
  /// [clockFactory] seam, runs the pure [decayCreature] with the clamped
  /// [timeScale], and persists the decayed row **only when a whole tick fired**
  /// (so frequent polling never writes on every call). Mood is then derived from
  /// the decayed stats. `timeScale` is the client's 1×–8× acceleration slider;
  /// it is nullable at the RPC boundary (so older callers omit it) and defaults
  /// to `1.0` (real time) when absent.
  Future<CreatureStatus?> myCreature(
    Session session, {
    double? timeScale,
  }) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final creature = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    if (creature == null) return null;

    final personality = await CreaturePersonality.db.findFirstRow(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
    );
    if (personality == null) {
      // Personality is written 1:1 with the creature at hatch; its absence is a
      // data-integrity bug, not a user-facing path — fail loudly (as in feed).
      throw StateError('Creature ${creature.id} has no personality row');
    }

    final now = clockFactory(session)();
    final scale = clampTimeScale(timeScale ?? 1.0);

    // Decay is computed lock-free first: the common polling case fires no tick
    // and returns immediately, never taking a row lock or writing. Only when a
    // tick actually fired do we persist — and then under a `forUpdate` lock,
    // re-reading and recomputing from the committed row, so this read-path write
    // can't clobber an overlapping feed/play/cure write (last-writer-wins lost
    // update).
    final optimistic = decayCreature(
      creature: creature,
      personality: personality,
      now: now,
      timeScale: scale,
    );
    final DecayOutcome decayed;
    if (!optimistic.changed) {
      decayed = optimistic;
    } else {
      decayed = await session.db.transaction((transaction) async {
        final fresh = await Creature.db.findById(
          session,
          creature.id!,
          transaction: transaction,
          lockMode: LockMode.forUpdate,
        );
        // Row vanished mid-call (no delete path in this app) — keep the
        // optimistic value rather than resurrecting a deleted row.
        if (fresh == null) return optimistic;
        final reDecayed = decayCreature(
          creature: fresh,
          personality: personality,
          now: now,
          timeScale: scale,
        );
        if (reDecayed.changed) {
          await Creature.db.updateRow(
            session,
            reDecayed.creature,
            transaction: transaction,
          );
        }
        return reDecayed;
      });
    }

    return _statusFor(decayed.creature, personality.loveRegenMod);
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
  Future<FeedResult> feed(Session session, {double? timeScale}) async {
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

    // Decay-before-interaction: fold in any elapsed-time decay first so the gate
    // and the feed delta act on up-to-date stats. `base` carries the decayed
    // stats + advanced `lastDecayedAt`; both land in the one transaction below.
    final decayed = decayCreature(
      creature: creature,
      personality: personality,
      now: clockFactory(session)(),
      timeScale: clampTimeScale(timeScale ?? 1.0),
    );
    final base = decayed.creature;

    final feedService = feedServiceFactory(session);

    // Empty-energy gate (FR-007): a creature too tired to eat. This takes
    // priority over the full-refusal check below — a creature too tired to eat
    // shouldn't first be told it's full. Like full-refusal, it's a plain early
    // return: a canned exhausted line, no LLM call, no journal entry, no stat
    // change, and no persistence. Not persisting the (possibly decayed) `base` is
    // safe: `lastDecayedAt` isn't advanced, so the same elapsed window is
    // recomputed idempotently on the next poll/interaction.
    if (base.energy < feedEnergyCost) {
      return FeedResult(
        userResponse: feedService.exhaustedLine(),
        accepted: false,
        exhausted: true,
        status: _statusFor(base, personality.loveRegenMod),
      );
    }

    final decision = feedService.decide(base, personality);

    // A refused feed still flows through the LLM and records a zero-delta entry —
    // a full refusal (stuffed) and a picky refusal (distaste) are narrated
    // distinctly via [RefusalSeverity], and only an accepted feed moves stats.
    final refusalSeverity = decision.full
        ? RefusalSeverity.full
        : decision.accepted
        ? RefusalSeverity.none
        : RefusalSeverity.picky;

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
        hunger: base.hunger,
        energy: base.energy,
        love: base.love,
        illness: base.illness,
        mood: _moodOf(base),
        interactionType: JournalEvent.feed,
        accepted: decision.accepted,
        tastiness: decision.tastiness,
        recentEntries: recentEntries,
        refusalSeverity: refusalSeverity,
      ),
    );

    // Coherent pair: stat update + journal entry in one transaction, applied to
    // the decayed `base`. The delta already encodes the 0-100 clamp, so adding it
    // to the decayed stat lands the clamped target directly. Persist whenever the
    // feed was accepted OR decay advanced the creature (a picky refusal still
    // commits the decayed stats + advanced anchor); decay itself adds no entry.
    final updated = await session.db.transaction((transaction) async {
      var result = base;
      if (decision.accepted) {
        result = base.copyWith(
          hunger: base.hunger + decision.delta.hungerDelta,
          energy: base.energy + decision.delta.energyDelta,
        );
      }
      if (decision.accepted || decayed.changed) {
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
      exhausted: false,
      status: _statusFor(updated, personality.loveRegenMod),
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
  Future<PlayResult> play(Session session, {double? timeScale}) async {
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

    // Decay-before-interaction: fold in elapsed-time decay first; `base` carries
    // the decayed stats + advanced `lastDecayedAt`, both persisted in the one
    // transaction below alongside the play delta.
    final decayed = decayCreature(
      creature: creature,
      personality: personality,
      now: clockFactory(session)(),
      timeScale: clampTimeScale(timeScale ?? 1.0),
    );
    final base = decayed.creature;
    final playService = playServiceFactory(session);

    // Empty-energy gate (FR-007): a creature too tired to play. Plain early
    // return mirroring [feed]'s gate: a canned exhausted line, no LLM call, no
    // journal entry, no stat change, no persistence (decay is recomputed
    // idempotently next call since `lastDecayedAt` isn't advanced).
    final playCost = playEnergyCost(personality.loveRegenMod);
    if (base.energy < playCost) {
      return PlayResult(
        userResponse: playService.exhaustedLine(),
        exhausted: true,
        status: _statusFor(base, personality.loveRegenMod),
      );
    }

    // Deterministic — no rng. The delta encodes the 0-100 clamp.
    final delta = playDelta(base, personality);

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

    final reply = await playService.interaction(
      session,
      InteractionRequest(
        personality: personality,
        hunger: base.hunger,
        energy: base.energy,
        love: base.love,
        illness: base.illness,
        mood: _moodOf(base),
        interactionType: JournalEvent.play,
        accepted: true,
        // tastiness is feed-only; the play prompt branch ignores it.
        tastiness: 0,
        recentEntries: recentEntries,
      ),
    );

    // Coherent pair: the stat update (always — energy always changes, and decay
    // is always folded in) + the journal entry in one transaction, applied to the
    // decayed `base`.
    final updated = await session.db.transaction((transaction) async {
      final result = base.copyWith(
        love: base.love + delta.loveDelta,
        energy: base.energy + delta.energyDelta,
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
      exhausted: false,
      status: _statusFor(updated, personality.loveRegenMod),
    );
  }

  /// Cures the caller's creature once and returns the in-character outcome.
  ///
  /// Like [play], Cure is **fully deterministic** (`prd.md:39`): no accept/refuse
  /// gate. The stat change ([cureDelta] — illness down, scaled by the
  /// `illnessDecayMod` recovery-responsiveness axis; energy/hunger/love untouched)
  /// is computed up front, then the LLM is asked for a response + journal
  /// narrative (degrading to canned cure copy on failure), and the stat change +
  /// journal entry are written as one coherent pair. Exactly one `cure` entry is
  /// always written.
  ///
  /// **FR-006 / S-06 invariant:** Cure is always available *regardless of energy*
  /// and costs no energy — this method must **never** read energy as a guard. When
  /// S-06 adds the empty-energy gate to Feed/Pet, it must explicitly exempt Cure.
  ///
  /// At `illness == 0` the cure is a no-op on illness ([cureDelta] is zero) yet
  /// the LLM is still called and a journal entry is still written (mirrors Play's
  /// max-love behaviour). The disabled-button rule is a client-side UX guard only;
  /// the server carries no illness precondition.
  ///
  /// As in [play], the LLM call sits **outside** the transaction so a degrade
  /// still commits the stat+journal pair atomically.
  Future<CureResult> cure(Session session, {double? timeScale}) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final creature = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    if (creature == null) {
      throw CreatureCureError(reason: CreatureCureErrorReason.noCreature);
    }

    final personality = await CreaturePersonality.db.findFirstRow(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
    );
    if (personality == null) {
      // Personality is written 1:1 with the creature at hatch; its absence is a
      // data-integrity bug, not a user-facing path — fail loudly (as in play).
      throw StateError('Creature ${creature.id} has no personality row');
    }

    // Decay-before-interaction: fold in elapsed-time decay first; `base` carries
    // the decayed stats + advanced `lastDecayedAt`, both persisted in the one
    // transaction below alongside the cure delta. Illness itself never decays, so
    // only hunger/energy/love move here — but the advanced anchor still lands.
    final decayed = decayCreature(
      creature: creature,
      personality: personality,
      now: clockFactory(session)(),
      timeScale: clampTimeScale(timeScale ?? 1.0),
    );
    final base = decayed.creature;

    // Deterministic — no rng. The delta encodes the 0-100 clamp (illness floors
    // at 0).
    final delta = cureDelta(base, personality);

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

    final reply = await cureServiceFactory(session).interaction(
      session,
      InteractionRequest(
        personality: personality,
        hunger: base.hunger,
        energy: base.energy,
        love: base.love,
        illness: base.illness,
        mood: _moodOf(base),
        interactionType: JournalEvent.cure,
        accepted: true,
        // tastiness is feed-only; the cure prompt branch ignores it.
        tastiness: 0,
        recentEntries: recentEntries,
      ),
    );

    // Coherent pair: the stat update (illness from the cure, plus the decayed
    // hunger/energy/love and advanced anchor) + the journal entry in one
    // transaction, applied to the decayed `base`.
    final updated = await session.db.transaction((transaction) async {
      final result = base.copyWith(
        illness: base.illness + delta.illnessDelta,
      );
      await Creature.db.updateRow(session, result, transaction: transaction);

      await JournalEntry.db.insertRow(
        session,
        JournalEntry(
          creatureId: creature.id!,
          ownerUuid: ownerUuid,
          event: JournalEvent.cure,
          prose: reply.journalNarrative,
          statDelta: delta,
        ),
        transaction: transaction,
      );

      return result;
    });

    return CureResult(
      userResponse: reply.userResponse,
      status: _statusFor(updated, personality.loveRegenMod),
    );
  }

  /// Returns the caller's journal entries newest-first for the journal screen.
  ///
  /// Unlike the short-term LLM memory window, this keeps the empty-prose
  /// `hatched` marker (the screen renders it as the origin card) and lifts the
  /// limit to a generous bounded cap (no pagination yet — `research.md` Open Q1).
  Future<List<JournalEntry>> readJournal(Session session) async {
    final ownerUuid = UuidValue.fromString(
      session.authenticated!.userIdentifier,
    );

    final creature = await Creature.db.findFirstRow(
      session,
      where: (t) => t.ownerUuid.equals(ownerUuid),
    );
    // No creature yet → empty journal (the screen renders an empty state).
    if (creature == null) return [];

    // Scope by creatureId, with the owner constraint as a belt-and-suspenders
    // backstop against IDOR. Keep the empty-prose hatched marker (the origin
    // card needs it) — unlike the LLM memory window, which drops it.
    return JournalEntry.db.find(
      session,
      where: (t) =>
          t.creatureId.equals(creature.id!) & t.ownerUuid.equals(ownerUuid),
      orderBy: (t) => t.timestamp,
      orderDescending: true,
      limit: _journalReadCap,
    );
  }

  /// Builds the birth [InteractionRequest] for [name] from the freshly-rolled
  /// [mods]. The creature does not exist yet, so this carries baseline stats and a
  /// throwaway [CreaturePersonality] whose `creatureId` is never read — only its
  /// modifiers feed the birth prompt's personality summary. No tastiness, accept
  /// decision, or memory window: a birth has none.
  InteractionRequest _birthRequest(String name, PersonalityModifiers mods) =>
      InteractionRequest(
        personality: CreaturePersonality(
          creatureId: UuidValue.fromString(
            '00000000-0000-0000-0000-000000000000',
          ),
          hungerDecayMod: mods.hungerDecayMod,
          hungerRegenMod: mods.hungerRegenMod,
          energyDecayMod: mods.energyDecayMod,
          energyRegenMod: mods.energyRegenMod,
          loveRegenMod: mods.loveRegenMod,
          illnessDecayMod: mods.illnessDecayMod,
          illnessRegenMod: mods.illnessRegenMod,
        ),
        name: name,
        hunger: baselineCreatureStats.hunger,
        energy: baselineCreatureStats.energy,
        love: baselineCreatureStats.love,
        illness: baselineCreatureStats.illness,
        mood: deriveMood(
          baselineCreatureStats.hunger,
          baselineCreatureStats.energy,
          baselineCreatureStats.love,
          baselineCreatureStats.illness,
        ),
        interactionType: JournalEvent.hatched,
        accepted: true,
        tastiness: 0,
        recentEntries: const [],
      );

  CreatureMood _moodOf(Creature c) =>
      deriveMood(c.hunger, c.energy, c.love, c.illness);

  /// Bundles [c] with its derived mood and current affordability. `canFeed`/
  /// `canPlay` mirror the server-side gate: Feed needs [feedEnergyCost], Play
  /// needs the personality-derived [playEnergyCost] of [loveRegenMod] (which the
  /// client can't compute, so it's reported here). The single construction point
  /// for every [CreatureStatus] the endpoint returns.
  CreatureStatus _statusFor(Creature c, double loveRegenMod) => CreatureStatus(
    creature: c,
    mood: _moodOf(c),
    canFeed: c.energy >= feedEnergyCost,
    canPlay: c.energy >= playEnergyCost(loveRegenMod),
  );
}

/// Generous bounded cap for a full journal read — MVP fetches everything at once;
/// pagination is deferred (`research.md` Open Q1).
const int _journalReadCap = 500;

/// Dependency seam for hatch's birth-narrative LLM call. Defaults to the
/// production wiring [llmServiceFor] (real Mistral when a key is present, the
/// hermetic stub otherwise); tests reassign it to inject a deliberately-throwing
/// [LlmService] (to exercise block-on-failure) and self-clean with `addTearDown`.
/// Not a test-only member — its default IS the production injection point.
LlmService Function(Session session) hatchLlmServiceFactory = llmServiceFor;
