import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/feed_copy.dart';
import '../llm/llm_service.dart';

/// The picky/tastiness gate that decides whether a creature accepts a feed, plus
/// the deterministic stat math behind an accepted feed. Pure and DB-free —
/// extends `creature_service.dart`'s style (small functions, an injectable
/// `Random` seam) so every rule is unit-testable in isolation.

/// Clamps a raw stat onto the 0-100 scale every creature stat lives on.
int clampStat(int v) => v.clamp(0, 100);

/// Hunger lost on an accepted feed (0-100 scale; higher hunger = hungrier, so a
/// feed *lowers* it). PRD oracle — fixed magnitude, never tastiness-scaled.
const feedHungerDrop = 30;

/// Energy spent eating an accepted feed (FR-004 energy cost). Fixed magnitude.
const feedEnergyCost = 10;

/// How fussy an eater the creature is, derived from its `hungerDecayMod` — no new
/// persisted field (plan: pickiness is *derived*). LOW decay ⇒ HIGH picky: a
/// placid metabolism is the fussy one. Range `(0,1]` over the personality band
/// `hungerDecayMod ∈ [0.5,1.5)`.
double pickyFactor(double hungerDecayMod) => 1.5 - hungerDecayMod;

/// Probability the creature refuses a feed: the picky factor scaled down by how
/// hungry it is and how tasty the food is. A starving creature (`hunger→100`) or
/// gourmet food (`tastiness→1`) drives it to 0; monotone in each factor.
double rejectProbability({
  required double picky,
  required int hunger,
  required double tastiness,
}) => picky * (1 - hunger / 100) * (1 - tastiness);

/// The outcome of one feed gate: whether the creature was already [full], whether
/// it [accepted], the rolled [tastiness] (fed into the LLM prompt), and the
/// [delta] to apply (all-zero on a refusal, so a picky refusal still records a
/// journal entry without moving stats).
typedef FeedDecision = ({
  bool full,
  bool accepted,
  double tastiness,
  StatDelta delta,
});

/// Resolves a single feed against an injectable [rng]. **RNG draw order is part
/// of the contract** (seeded tests depend on it): on a non-full creature we draw
/// `tastiness` FIRST, then the reject roll. A full creature (`hunger == 0`)
/// short-circuits before any draw.
///
/// Pickiness is derived from `personality.hungerDecayMod` (no persisted field);
/// accepted-feed magnitudes are the fixed, clamped [feedHungerDrop] /
/// [feedEnergyCost] — tastiness shapes only the accept gate, never the deltas.
FeedDecision evaluateFeed({
  required Creature creature,
  required CreaturePersonality personality,
  required Random rng,
}) {
  final zeroDelta = StatDelta(
    hungerDelta: 0,
    energyDelta: 0,
    loveDelta: 0,
    illnessDelta: 0,
  );

  if (creature.hunger == 0) {
    return (full: true, accepted: false, tastiness: 0, delta: zeroDelta);
  }

  final tastiness = rng.nextDouble();
  final picky = pickyFactor(personality.hungerDecayMod);
  final reject =
      rng.nextDouble() <
      rejectProbability(
        picky: picky,
        hunger: creature.hunger,
        tastiness: tastiness,
      );

  if (reject) {
    return (
      full: false,
      accepted: false,
      tastiness: tastiness,
      delta: zeroDelta,
    );
  }

  final delta = StatDelta(
    hungerDelta: clampStat(creature.hunger - feedHungerDrop) - creature.hunger,
    energyDelta: clampStat(creature.energy - feedEnergyCost) - creature.energy,
    loveDelta: 0,
    illnessDelta: 0,
  );
  return (full: false, accepted: true, tastiness: tastiness, delta: delta);
}

/// The impure collaborators a feed needs: a randomness source (the gate roll and
/// the full-refusal line pick) and the LLM. The endpoint composes the pure gate
/// math ([evaluateFeed]) and the DB writes around one of these — this type is the
/// single place where non-determinism and network access enter the feed flow.
///
/// Production instances are assembled by [feedServiceFor] (real entropy + the
/// key-presence-selected real/stub model). Tests construct one directly with a
/// seeded/scripted [Random] and a stub or deliberately-failing [LlmService], so
/// the endpoint never knows whether its collaborators are real or fake.
class FeedService {
  FeedService({required Random rng, required LlmService llm})
    : _rng = rng,
      _llm = llm;

  final Random _rng;
  final LlmService _llm;

  /// Rolls the picky/tastiness accept gate for [creature] given its
  /// [personality]. The draw order (tastiness, then the reject roll) is the
  /// contract seeded tests depend on — see [evaluateFeed].
  FeedDecision decide(Creature creature, CreaturePersonality personality) =>
      evaluateFeed(creature: creature, personality: personality, rng: _rng);

  /// Picks a canned "I'm stuffed" line for the full-refusal path off the *same*
  /// rng the gate used, so a seeded run is reproducible end to end.
  String fullRefusalLine() =>
      fullRefusalLines[_rng.nextInt(fullRefusalLines.length)];

  /// Produces the in-character response + journal narrative for one feed,
  /// degrading to canned [degradeUserResponse]/[degradeJournalNarrative] if the
  /// model call throws — so a flaky/unreachable model never blocks the
  /// interaction and the stat+journal pair still commits.
  Future<({String userResponse, String journalNarrative})> interaction(
    Session session,
    InteractionRequest request,
  ) async {
    try {
      return await _llm.generateInteraction(session, request);
    } catch (e, stackTrace) {
      session.log(
        'Feed LLM call failed; degrading to canned copy',
        level: LogLevel.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return (
        userResponse: degradeUserResponse,
        journalNarrative: degradeJournalNarrative,
      );
    }
  }
}

/// Builds the production [FeedService] for [session]: real entropy plus the
/// key-presence-selected real/stub LLM ([llmServiceFor]). This is the only wiring
/// the endpoint uses in production — there is nothing to misconfigure at the call
/// site.
FeedService feedServiceFor(Session session) =>
    FeedService(rng: Random(), llm: llmServiceFor(session));

/// Dependency seam: the endpoint obtains its [FeedService] through this, never by
/// constructing one. Defaults to the production wiring [feedServiceFor]; tests
/// reassign it to inject determinism (a seeded/scripted [Random]) and hermetic
/// collaborators (a stub or failing [LlmService]). Not a test-only member — it is
/// the production injection point, and its default *is* production.
FeedService Function(Session session) feedServiceFactory = feedServiceFor;
