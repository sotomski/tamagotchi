import 'dart:math';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'creature_service.dart';

/// Lazy-on-read stat decay: the pure tick math plus the one impure collaborator
/// it needs — a clock. Decay is computed from elapsed wall-clock time quantized
/// into fixed [tickMinutes] ticks, scaled by personality dials and a client
/// `timeScale`. Everything here is DB-free and deterministic given (stats,
/// personality, `lastDecayedAt`, `now`, `timeScale`) — mirroring the pure-domain
/// style of `creature_service.dart` / `play_service.dart` so each rule is
/// unit-testable in isolation. The only non-determinism (the clock) is isolated
/// behind the [clockFactory] seam, following the same factory-seam pattern as
/// `feedServiceFor` / `feedServiceFactory`.

/// One decay tick is this many game-minutes. Elapsed time is floored into whole
/// ticks; sub-tick remainder is carried forward via the anchor (see
/// [decayCreature]) so polling frequency can never starve decay.
const tickMinutes = 10;

/// Hunger gained per tick at the baseline personality (scaled by `hungerDecayMod`).
const hungerPerTick = 2;

/// Energy regained per tick at the baseline personality (scaled by `energyRegenMod`).
const energyPerTick = 1;

/// Love lost per tick at the baseline personality (scaled inversely by the
/// `loveRegenMod` sociability axis — an extravert fades slower).
const lovePerTick = 1;

/// Love never decays below this soft floor; a bonded creature keeps a residue of
/// affection no matter how long it is neglected.
const loveFloor = 20;

/// The client time-acceleration slider's bounds. `timeScale` compresses both how
/// fast the server decays and how often the client refreshes.
const minTimeScale = 1.0;
const maxTimeScale = 8.0;

/// Clamps a raw `timeScale` onto `[minTimeScale, maxTimeScale]`. The endpoint
/// calls this on the inbound parameter before handing it to [decayCreature],
/// which assumes an already-clamped scale.
double clampTimeScale(double timeScale) =>
    timeScale.clamp(minTimeScale, maxTimeScale);

/// The result of applying decay: the (possibly) updated [creature] and whether a
/// whole tick actually fired. When [changed] is false the [creature] is returned
/// verbatim (same instance) and the caller persists nothing.
typedef DecayOutcome = ({Creature creature, bool changed});

/// Applies elapsed-time decay to [creature] given its [personality], the current
/// instant [now], and an already-clamped [timeScale].
///
/// Quantizes effective elapsed game-time (`realElapsed × timeScale`) into whole
/// [tickMinutes] ticks. With zero whole ticks it is a no-op — stats and the
/// `lastDecayedAt` anchor are untouched and [DecayOutcome.changed] is false, so
/// frequent reads neither write nor lose sub-tick progress. With `ticks > 0` it
/// applies `ticks` worth of per-stat deltas (hunger ↑, energy ↑ capped at 100,
/// love ↓ floored at [loveFloor]; illness never moves) and advances the anchor
/// by **only the real duration of the whole ticks consumed**, leaving the
/// remainder to accumulate across reads.
DecayOutcome decayCreature({
  required Creature creature,
  required CreaturePersonality personality,
  required DateTime now,
  required double timeScale,
}) {
  // Precondition: callers clamp via [clampTimeScale] (min 1.0). A zero/negative
  // scale would divide by zero at the anchor-advance step below.
  assert(timeScale >= minTimeScale);
  final realElapsedMin =
      now.difference(creature.lastDecayedAt).inMilliseconds / 60000.0;
  final effElapsedMin = realElapsedMin * timeScale;
  final ticks = (effElapsedMin / tickMinutes).floor();
  if (ticks <= 0) return (creature: creature, changed: false);

  final hungerRise = (ticks * hungerPerTick * personality.hungerDecayMod)
      .round();
  final energyRise = (ticks * energyPerTick * personality.energyRegenMod)
      .round();
  final loveDrop = (ticks * lovePerTick * (2 - personality.loveRegenMod))
      .round();

  final newHunger = clampStat(creature.hunger + hungerRise);
  final newEnergy = clampStat(creature.energy + energyRise);
  // Floor love at [loveFloor], but never lift a creature already below it.
  final newLove = max(creature.love - loveDrop, min(creature.love, loveFloor));

  // Advance the anchor by exactly the real time the whole ticks represent, so
  // the sub-tick remainder carries forward to the next read.
  final consumedRealMs = ((ticks * tickMinutes) / timeScale * 60000).round();
  final newAnchor = creature.lastDecayedAt.add(
    Duration(milliseconds: consumedRealMs),
  );

  return (
    creature: creature.copyWith(
      hunger: newHunger,
      energy: newEnergy,
      love: newLove,
      lastDecayedAt: newAnchor,
    ),
    changed: true,
  );
}

/// Production default for the [clockFactory] seam: the real UTC wall clock.
/// `lastDecayedAt` is stored/compared in UTC to match Serverpod's DateTime
/// persistence, so the clock yields UTC too.
DateTime Function() clockFor(Session session) =>
    () => DateTime.now().toUtc();

/// Dependency seam: the endpoint reads `now` through `clockFactory(session)()`,
/// never by calling `DateTime.now()` directly. Defaults to the production wiring
/// [clockFor]; tests reassign it to a fixed instant and self-clean with
/// `addTearDown`. Not a test-only member — its default *is* production.
DateTime Function() Function(Session session) clockFactory = clockFor;
