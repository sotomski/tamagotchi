import 'dart:math';

import 'package:meta/meta.dart';

import '../generated/protocol.dart';

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
}) =>
    picky * (1 - hunger / 100) * (1 - tastiness);

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
  final reject = rng.nextDouble() <
      rejectProbability(
        picky: picky,
        hunger: creature.hunger,
        tastiness: tastiness,
      );

  if (reject) {
    return (full: false, accepted: false, tastiness: tastiness, delta: zeroDelta);
  }

  final delta = StatDelta(
    hungerDelta: clampStat(creature.hunger - feedHungerDrop) - creature.hunger,
    energyDelta: clampStat(creature.energy - feedEnergyCost) - creature.energy,
    loveDelta: 0,
    illnessDelta: 0,
  );
  return (full: false, accepted: true, tastiness: tastiness, delta: delta);
}

/// Test seam for the feed RNG: integration tests override this with a seeded
/// `Random` so the gate is reproducible end-to-end (mirrors the
/// `randomPersonalityModifiers` seam in `creature_service.dart`).
@visibleForTesting
Random Function() feedRandomFactory = () => Random();
