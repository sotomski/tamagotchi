import 'dart:math';

import '../generated/protocol.dart';

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
