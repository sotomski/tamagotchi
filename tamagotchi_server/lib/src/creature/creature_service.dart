import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The unique index that enforces one creature per owner at the database layer
/// (declared in `creature.spy.yaml`, applied by the S-02 migration). It is the
/// race-safe backstop behind the endpoint's non-atomic app pre-check.
const ownerCreatureUniqueConstraint = 'creature_owner_idx';

/// Postgres `unique_violation` SQLSTATE — raised when an insert collides with a
/// unique index.
const _uniqueViolationCode = '23505';

/// Fixed stats every creature is hatched with (0-100 scale). Personality, not
/// stats, is randomized at hatch (S-02 has no decay/regen). Love starts at 50 so
/// a newborn reads as `content` — bonded over time, not instantly.
const baselineCreatureStats = (hunger: 0, energy: 100, love: 50, illness: 0);

/// The eight per-stat decay/regen multipliers produced at hatch. A plain record
/// so this logic stays database-free; the endpoint assembles the
/// [CreaturePersonality] row from it.
typedef PersonalityModifiers = ({
  double hungerDecayMod,
  double hungerRegenMod,
  double energyDecayMod,
  double energyRegenMod,
  double loveDecayMod,
  double loveRegenMod,
  double illnessDecayMod,
  double illnessRegenMod,
});

/// Derives a creature's mood from its four raw stats. Pure and deterministic so
/// it stays consistent once S-07 decay mutates stats (mood is never stored).
///
/// Rule (the decided oracle — see plan Critical Implementation Details):
/// per-stat distress is `hunger`, `100 - energy`, `100 - love`, `illness`.
/// Illness has priority: `illness >= 50` is always [CreatureMood.sick].
/// Otherwise the worst of the other three distresses decides:
/// `< 25` happy, `< 55` content, else sad.
CreatureMood deriveMood(int hunger, int energy, int love, int illness) {
  if (illness >= 50) return CreatureMood.sick;

  final worst = [hunger, 100 - energy, 100 - love].reduce(max);
  if (worst < 25) return CreatureMood.happy;
  if (worst < 55) return CreatureMood.content;
  return CreatureMood.sad;
}

/// Rolls the eight personality modifiers, each a multiplier in `[0.5, 1.5)`
/// around the `1.0` baseline. The [rng] seam keeps every other piece of hatch
/// logic deterministically testable.
PersonalityModifiers randomPersonalityModifiers(Random rng) {
  double roll() => 0.5 + rng.nextDouble();
  return (
    hungerDecayMod: roll(),
    hungerRegenMod: roll(),
    energyDecayMod: roll(),
    energyRegenMod: roll(),
    loveDecayMod: roll(),
    loveRegenMod: roll(),
    illnessDecayMod: roll(),
    illnessRegenMod: roll(),
  );
}

/// Whether [error] is the Postgres unique-violation on the owner index — i.e. a
/// concurrent hatch slipped past the non-atomic app pre-check and the DB
/// backstop rejected the duplicate creature row.
///
/// The endpoint translates this into a typed
/// `CreatureHatchError(alreadyHatched)` so the rare race surfaces the same
/// client-visible error as the common case instead of a raw database fault.
/// Matches the owner constraint by name, falling back to the `creature` table
/// (whose only unique index is the owner one) if the driver leaves
/// `constraintName` null — without masking a unique violation on any other
/// table (e.g. the personality row).
bool isOwnerAlreadyHatchedViolation(Object error) {
  if (error is! DatabaseQueryException) return false;
  if (error.code != _uniqueViolationCode) return false;
  return error.constraintName == ownerCreatureUniqueConstraint ||
      error.tableName == 'creature';
}
