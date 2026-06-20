import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Postgres `unique_violation` SQLSTATE — raised when an insert collides with a
/// unique index.
const _uniqueViolationCode = '23505';

/// Fixed stats every creature is hatched with (0-100 scale). Personality, not
/// stats, is randomized at hatch (S-02 has no decay/regen). Love starts at 50 so
/// a newborn reads as `content` — bonded over time, not instantly.
const baselineCreatureStats = (hunger: 0, energy: 100, love: 50, illness: 0);

/// The seven per-stat decay/regen multipliers produced at hatch. A plain record
/// so this logic stays database-free; the endpoint assembles the
/// [CreaturePersonality] row from it. Love has a single dial (`loveRegenMod`,
/// the introvert↔extravert axis), so there is no `loveDecayMod`.
typedef PersonalityModifiers = ({
  double hungerDecayMod,
  double hungerRegenMod,
  double energyDecayMod,
  double energyRegenMod,
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

/// Rolls the seven personality modifiers, each a multiplier in `[0.5, 1.5)`
/// around the `1.0` baseline. The [rng] seam keeps every other piece of hatch
/// logic deterministically testable.
PersonalityModifiers randomPersonalityModifiers(Random rng) {
  double roll() => 0.5 + rng.nextDouble();
  return (
    hungerDecayMod: roll(),
    hungerRegenMod: roll(),
    energyDecayMod: roll(),
    energyRegenMod: roll(),
    loveRegenMod: roll(),
    illnessDecayMod: roll(),
    illnessRegenMod: roll(),
  );
}

/// Whether [error] is a Postgres unique-violation (SQLSTATE 23505).
///
/// This is only the *trigger* for the hatch backstop: a unique violation
/// escaping the insert transaction means a concurrent hatch may have raced past
/// the non-atomic app pre-check. The endpoint then re-reads the owner's creature
/// to confirm the race before reporting `alreadyHatched`, so this layer never
/// parses table or constraint names — a unique index added elsewhere later
/// (e.g. on the personality row) cannot be misclassified here.
bool isUniqueViolation(Object error) =>
    error is DatabaseQueryException && error.code == _uniqueViolationCode;
