# Real-Time Stat Decay & Energy Regen (FR-008 / S-07) Implementation Plan

## Overview

Implement FR-008: creature stats change in real time at personality-driven
rates (including while the user is away), never dropping below a minimum floor,
and energy regenerates in real time. Decay is computed **lazily on read** from
elapsed wall-clock time, quantized into **10-minute decay ticks**, and scaled by
a client-controlled **time-acceleration slider (`timeScale`, 1×–8×)** that
compresses both how fast the server decays stats and how often the frontend
refreshes. No journal entries are produced by decay.

## Current State Analysis

(Grounded in `context/changes/real-time-stat-decay/research.md`.)

- **Personality dials already exist** but no decay anchor. `CreaturePersonality`
  carries per-stat `*DecayMod` / `*RegenMod` multipliers in `[0.5, 1.5)`
  (`creature_personality.spy.yaml:1-27`). The only timestamp on `Creature` is
  `hatchedAt` — there is **no `lastDecayedAt`** (`creature.spy.yaml:1-27`).
- **`loveDecayMod` does not exist** — only `loveRegenMod`. Love decay must be
  derived from the existing dial.
- **"Derive on read" is the established idiom.** `myCreature` returns the stored
  row plus a server-computed `mood` that is never persisted
  (`creature_endpoint.dart:115-128`, `creature_service.dart:44-51`).
- **One clamp helper, clamp-encoded deltas everywhere.** `clampStat(v) =
  v.clamp(0,100)` (`creature_service.dart:20`); interaction deltas are
  `clampStat(target) - current`.
- **No clock seam exists.** No domain code reads wall-clock time; decay
  introduces the first time-dependence. `lessons.md:24-29` explicitly names
  "clock" as a factory-seam collaborator.
- **Interactions persist atomically** — each writes the creature row + a
  `JournalEntry` in one `session.db.transaction(...)`
  (`creature_endpoint.dart:207-231`). Feed/Play/Cure read **zero** wall-clock
  time today and act on the stored stats verbatim.
- **Frontend has no refresh-on-return.** `creatureProvider` is
  `keepAlive: true` and re-fetches only on explicit `ref.invalidate` after an
  interaction or error-retry (`creature_provider.dart:11-13`). No timer, no
  lifecycle hook, no pull-to-refresh.

## Desired End State

- A creature's stats reflect elapsed time whenever observed: hunger has risen,
  energy has regenerated toward 100, love has decayed (floored), illness is
  unchanged — all scaled by personality and by the current `timeScale`.
- A user can drag a 1×–8× slider and watch stats change faster and the display
  refresh more often, proportional to the slider.
- Decay never produces a journal entry; the journal still reflects only
  interactions.
- All decay math is deterministic given (stats, personality, elapsed, timeScale)
  and unit-testable without a DB or wall clock via an injected clock seam.

**Verification:** unit tests for the pure decay function; integration tests that
seed a creature with an old `lastDecayedAt` and assert `myCreature` / `feed` /
`play` / `cure` return decayed-then-acted stats; a Flutter widget test that the
slider drives the poll cadence and the passed `timeScale`; manual play with the
slider.

### Key Discoveries:

- Insertion seam for lazy decay: `creature_endpoint.dart:115-128` (`myCreature`)
  and the four interaction transactions (e.g. `:207-231`).
- Floor mechanic reuses `clampStat` (`creature_service.dart:20`); only `love`
  needs an extra soft floor.
- Factory-seam template to mirror for the clock:
  `feed_service.dart:158-166` + `creature_endpoint.dart:164`; test injection at
  `feed_endpoint_test.dart:29-40`.
- Personality math idiom for inverse dial: `play_service.dart` uses
  `(2 - loveRegenMod)` — reuse it for love decay.
- Migration applied via `serverpod run start` (`lessons.md:5-9`), not
  `--apply-migrations`.

## What We're NOT Doing

- **No FutureCall / background scheduler.** Decay is lazy-on-read only.
- **No passive illness drift.** Illness changes only via Cure.
- **No new personality field** (`loveDecayMod` is not added). Love decay reuses
  `loveRegenMod` inversely.
- **No journal entries for decay.**
- **No stat schema change to doubles.** Stats stay `int`; the tick model avoids
  fractional accumulation.
- **No server-side persistence of `timeScale`.** It is a per-call parameter;
  slider state lives only in the client.
- **No expressive stat display redesign** (PRD Open Question #2, deferred to v2).
  Decayed values flow into the existing `_StatRow` widgets unchanged.

## Implementation Approach

Decay is a pure function quantized into **ticks** of `TICK_MINUTES = 10`
game-minutes. On any read/interaction the server computes effective elapsed game
time `= realElapsed × timeScale`, takes `ticks = floor(effElapsed /
TICK_MINUTES)`, applies `ticks` worth of per-stat deltas, and advances
`lastDecayedAt` by **only the real time consumed by whole ticks** — leaving the
sub-tick remainder so it accumulates across reads (this is what prevents fast
polling from starving decay). The clock is injected through a single
production-default factory seam so the math is deterministic in tests. The
endpoints pass a clamped `timeScale` parameter; the Flutter client owns the
slider and a poll timer whose interval scales with `timeScale`.

Per-stat per-tick model (base amounts are tunable named constants):

| Stat    | Direction        | Per-tick amount (before clamp/floor)        |
| ------- | ---------------- | ------------------------------------------- |
| hunger  | ↑ (gets hungry)  | `round(ticks × HUNGER_PER_TICK × hungerDecayMod)` |
| energy  | ↑ (regenerates)  | `round(ticks × ENERGY_PER_TICK × energyRegenMod)`, capped at 100 |
| love    | ↓ (fades)        | `round(ticks × LOVE_PER_TICK × (2 − loveRegenMod))`, floored at `LOVE_FLOOR` |
| illness | — (no drift)     | unchanged                                   |

Starting constants (tunable): `TICK_MINUTES = 10`, `HUNGER_PER_TICK = 2`,
`ENERGY_PER_TICK = 1`, `LOVE_PER_TICK = 1`, `LOVE_FLOOR = 20`,
`MIN_TIME_SCALE = 1.0`, `MAX_TIME_SCALE = 8.0`.

## Critical Implementation Details

**Tick quantization & anchor advance (decay-starvation guard).** Never advance
`lastDecayedAt` to `now` on every read. Advance it only by the real duration of
the whole ticks actually applied; when `ticks == 0`, leave stats and the anchor
untouched and persist nothing. This makes decay independent of read/poll
frequency and free of per-read rounding drift.

```dart
final realElapsedMin = now.difference(lastDecayedAt).inMilliseconds / 60000.0;
final effElapsedMin  = realElapsedMin * timeScale;          // game-minutes
final ticks = (effElapsedMin / tickMinutes).floor();
if (ticks <= 0) return DecayOutcome.unchanged(creature);    // persist nothing
// ...apply `ticks` worth of deltas via clampStat / love floor...
final consumedRealMs = ((ticks * tickMinutes) / timeScale * 60000).round();
final newAnchor = lastDecayedAt.add(Duration(milliseconds: consumedRealMs));
```

**Clock units.** Store and compare `lastDecayedAt` in UTC (`DateTime.now().toUtc()`
in the seam default) to match Serverpod's DateTime persistence.

**Determinism guardrail (PRD §Guardrails).** Decay adds exactly one new input
(elapsed time, via the injected clock) and `timeScale`; given the same values it
is fully reproducible. It introduces no RNG and must not touch the feed
accept/refuse roll.

---

## Phase 1: Decay Anchor + Migration

> **Workflow: `/10x-implement`** — schema field + `serverpod generate` + migration;
> no branchable logic to test-drive, verification is mechanical (generate/migrate
> succeed, column exists).

### Overview

Add the persisted decay anchor to the `Creature` model and migrate the DB.

### Changes Required:

#### 1. Creature model

**File**: `tamagotchi_server/lib/src/creature/creature.spy.yaml`

**Intent**: Add the timestamp that decay measures elapsed time from, defaulting
to creation time so newly hatched creatures start with a fresh anchor and
existing rows backfill sensibly.

**Contract**: New field `lastDecayedAt: DateTime, default=now` alongside
`hatchedAt`. After editing, run `serverpod generate` (regenerates
`lib/src/generated/**` and the `tamagotchi_client` protocol), then
`serverpod create-migration`.

#### 2. Hatch sets the anchor

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart` (hatch path)

**Intent**: Ensure a newly hatched creature's `lastDecayedAt` is set to "now" at
insert so its first decay window starts at hatch, not at the schema default
evaluated elsewhere.

**Contract**: When constructing the `Creature` to insert in `hatch`, set
`lastDecayedAt` to the clock seam's current time (see Phase 2 for the seam). If
sequencing makes the seam unavailable here in Phase 1, rely on the
`default=now`; revisit in Phase 2 to route through the seam.

### Success Criteria:

#### Automated Verification:

- `serverpod generate` completes without error
- Migration created: `serverpod create-migration` produces a new migration dir
- Migration applies cleanly via `serverpod run start`
- Analyzer passes: `dart analyze` in `tamagotchi_server/`
- Generated `Creature` exposes `lastDecayedAt`

#### Manual Verification:

- `lastDecayedAt` column exists on the creature table
- An existing creature row (if any) has a non-null `lastDecayedAt` after migration

**Implementation Note**: Pause for manual confirmation after automated checks
pass before proceeding.

---

## Phase 2: Server Decay Engine (Read Path)

> **Workflow: `/10x-tdd`** — the pure decay function has a precise, branch-rich
> contract (tick quantization, love floor, energy cap, illness invariance,
> anchor-remainder advance, `timeScale`/mod scaling, determinism); write the
> failing cases first, then implement to green.

### Overview

Introduce the clock factory-seam and the pure decay function, and apply decay in
the `myCreature` read path with a `timeScale` parameter.

### Changes Required:

#### 1. Clock factory seam

**File**: `tamagotchi_server/lib/src/creature/decay_service.dart` (new)

**Intent**: Provide a single production-default seam for the impure clock so
decay math is deterministic under test, following the established
`feedServiceFor` / `feedServiceFactory` pattern.

**Contract**: `DateTime Function() clockFor(Session session)` returning
`() => DateTime.now().toUtc()`, plus a reassignable global
`DateTime Function() Function(Session session) clockFactory = clockFor`. Tests
reassign `clockFactory` and reset via `addTearDown`. (Mirror
`feed_service.dart:158-166`.)

#### 2. Pure decay function

**File**: `tamagotchi_server/lib/src/creature/decay_service.dart`

**Intent**: Compute decayed stats + advanced anchor from elapsed time, deterministic
and DB-free, matching the pure-function style of `deriveMood` / `evaluateFeed`.

**Contract**: A top-level pure function returning a small result record
(decayed `Creature` copy + `changed` flag), implementing the tick math and
anchor-advance rule in **Critical Implementation Details**. Inputs: current
stats, `PersonalityModifiers`, `lastDecayedAt`, `now`, `timeScale`, and the
tuning constants. Uses `clampStat`; applies `LOVE_FLOOR`; caps energy at 100;
leaves illness unchanged. `timeScale` is clamped to `[MIN_TIME_SCALE,
MAX_TIME_SCALE]` by the caller before being passed in.

#### 3. Apply decay in `myCreature`

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Make reads reflect elapsed-time decay before returning the creature,
persisting the decayed row only when a tick actually fired.

**Contract**: Add parameter `double timeScale = 1.0` to `myCreature`. Read
`now` via `clockFactory(session)()`, clamp `timeScale`, run the pure decay fn;
if `changed`, `Creature.db.updateRow` the decayed row (with new
`lastDecayedAt`); derive mood from the decayed stats; return
`CreatureStatus(creature, mood)`. Requires `serverpod generate` to expose the new
param on the client.

### Success Criteria:

#### Automated Verification:

- Unit tests pass for the pure decay fn: zero elapsed → unchanged; sub-tick
  elapsed → unchanged + anchor untouched; N-tick elapsed → exact deltas; love
  floor enforced; energy capped at 100; illness never changes; `timeScale`
  scales ticks; personality mods scale magnitude; two identical inputs → identical
  outputs (determinism)
- Integration test passes: seed a creature with an old `lastDecayedAt`, call
  `myCreature(timeScale: …)`, assert decayed stats + advanced anchor; calling
  again immediately yields no further decay
- `serverpod generate` clean; `dart analyze` passes
- `dart format --set-exit-if-changed .` clean in `tamagotchi_server/`

#### Manual Verification:

- Against a running server, an idle creature's stats reflect decay on the next
  `myCreature` call; raising `timeScale` increases the decay applied

**Implementation Note**: Pause for manual confirmation after automated checks
pass before proceeding.

---

## Phase 3: Decay-Before-Interaction

> **Workflow: `/10x-tdd`** — wiring is small (the decay fn exists from Phase 2),
> but the behavioral contract is precise and regression-prone (decay-then-interact,
> atomic persist, exactly one journal entry, feed RNG draw-order preserved); encode
> those as failing integration tests first.

### Overview

Apply decay at the start of `feed`, `play`, and `cure` so interactions act on
current stats, inside each one's existing transaction.

### Changes Required:

#### 1. Shared apply-decay step for interactions

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Before each interaction computes its delta, fold in any elapsed-time
decay so the interaction operates on up-to-date stats; persist decay + interaction
+ journal atomically in the one transaction the interaction already opens.

**Contract**: Add `double timeScale = 1.0` to `feed`, `play`, `cure`. At the
start of each (inside the loaded-creature scope, before the service computes its
result), run the pure decay fn with `clockFactory(session)()` + clamped
`timeScale`; use the decayed stats as the base for the interaction math; write
the combined result (decayed + interaction delta, plus advanced `lastDecayedAt`)
and the `JournalEntry` within the existing `session.db.transaction`. Decay itself
adds **no** journal entry. Requires `serverpod generate` for the new params.

### Success Criteria:

#### Automated Verification:

- Integration tests pass: for each of feed/play/cure, seeding an old
  `lastDecayedAt` results in decay applied before the interaction delta, with
  `lastDecayedAt` advanced and exactly one journal entry (the interaction's)
- Existing feed/play/cure integration + unit tests still pass (RNG draw-order
  contract for feed preserved)
- `serverpod generate` clean; `dart analyze` passes
- `dart format --set-exit-if-changed .` clean in `tamagotchi_server/`

#### Manual Verification:

- Interacting after an idle period shows stats that reflect decay-then-interaction
  (not the pre-decay values)

**Implementation Note**: Pause for manual confirmation after automated checks
pass before proceeding.

---

## Phase 4: Frontend Slider + Scaled Polling

> **Workflow: `/10x-implement`** — mostly UI + Riverpod timer-lifecycle assembly
> (slider render, layout, wiring `timeScale`), which is build-first by nature; add
> the widget/timer tests alongside. Only the poll-interval scaling is a small
> TDD-able unit — optional to drive first.

### Overview

Add the `timeScale` provider + 1×–8× slider, a poll timer scaled by the slider,
and thread `timeScale` through the provider and interaction controllers.

### Changes Required:

#### 1. Time-scale state

**File**: `tamagotchi_flutter/lib/creature/time_scale_provider.dart` (new)

**Intent**: Hold the current slider value as app state, clamped to 1–8.

**Contract**: A Riverpod provider exposing a `double` time scale (default 1.0,
range 1–8). Mirror existing provider conventions in `lib/creature/`.

#### 2. Pass `timeScale` on reads

**File**: `tamagotchi_flutter/lib/creature/creature_provider.dart`

**Intent**: Every creature fetch carries the current slider value so the server
decays proportionally; changing the slider re-fetches.

**Contract**: `creatureProvider` watches the time-scale provider and calls
`client.creature.myCreature(timeScale: scale)`. Stays `keepAlive: true`.

#### 3. Scaled poll timer

**File**: `tamagotchi_flutter/lib/creature/decay_poll.dart` (new)

**Intent**: Periodically refresh the creature so live decay is visible, at a
cadence proportional to the slider (faster speed → more frequent refresh).

**Contract**: A Riverpod-managed `Timer.periodic` with interval
`TICK_MINUTES / timeScale` (10 min at 1×, ~75 s at 8×) that calls
`ref.invalidate(creatureProvider)`. Recreate the timer when the time scale
changes; dispose via `ref.onDispose`. Existing invalidate-after-interaction
behavior is unchanged.

#### 4. Slider UI

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`

**Intent**: Give the user a visible 1×–8× speed control.

**Contract**: A Material `Slider` (min 1, max 8, default 1) bound to the
time-scale provider, with a label showing the current multiplier; placed near
the stat display. Keyed for testability (e.g. `key: 'timeScaleSlider'`).

#### 5. Pass `timeScale` on interactions

**Files**: `tamagotchi_flutter/lib/creature/{feed_controller,play_controller,cure_controller}.dart`

**Intent**: Interactions decay consistently with reads.

**Contract**: Each controller reads the time-scale provider and passes
`timeScale:` to the corresponding `client.creature.{feed,play,cure}` call.

### Success Criteria:

#### Automated Verification:

- Widget test: slider renders, defaults to 1×, and updating it changes the
  time-scale provider value
- Widget test: `creatureProvider` override receives/passes the current
  `timeScale`; interaction controllers pass `timeScale`
- Widget/unit test: poll timer interval scales inversely with `timeScale` and
  invalidates `creatureProvider` (using fake async + provider overrides per
  `lessons.md:12-22`)
- `flutter analyze` passes; `dart format --set-exit-if-changed .` clean in
  `tamagotchi_flutter/`
- `flutter test` passes

#### Manual Verification:

- Dragging the slider visibly speeds up stat change and increases refresh
  frequency; at 1× changes are slow (one tick / 10 min); decayed values render
  in the existing stat rows without layout breakage
- (Optional) `patrol` e2e smoke still passes per `lessons.md:43-48`

**Implementation Note**: Pause for manual confirmation after automated checks
pass.

---

## Testing Strategy

### Unit Tests:

- Pure decay fn: zero/sub-tick/N-tick elapsed; anchor-advance leaves remainder;
  love floor; energy cap; illness invariance; `timeScale` scaling; personality
  mod scaling; determinism (identical inputs → identical outputs).
- Clock seam default returns UTC; reassignment + teardown works.

### Integration Tests:

- `myCreature` applies decay and persists only on a tick; second immediate call
  is a no-op.
- feed/play/cure apply decay-before-interaction atomically, advance the anchor,
  and write exactly the interaction's journal entry; feed RNG draw-order intact.

### Manual Testing Steps:

1. Hatch a creature; note stats and `lastDecayedAt`.
2. Wait / set `timeScale` high; refresh and confirm hunger↑, energy↑, love↓
   (floored at 20), illness unchanged.
3. Interact after idle; confirm decay applied before the interaction.
4. Drag the slider 1×→8×; confirm refresh cadence and decay speed both increase.

## Performance Considerations

Decay is O(1) per read and persists only when a tick fires, so frequent polling
does not write on every call. Polling load is one creature fetch per
`10/timeScale` minutes — negligible at single-user MVP scale.

## Migration Notes

One additive migration adds `lastDecayedAt` (`default=now`) to `Creature`;
existing rows backfill to migration time. Apply via `serverpod run start`
(`lessons.md:5-9`). Endpoint signature changes (`timeScale` params) require
`serverpod generate` so the `tamagotchi_client` protocol exposes them.

## References

- Research: `context/changes/real-time-stat-decay/research.md`
- Insertion seam: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:115-128`
- Factory-seam template: `tamagotchi_server/lib/src/creature/feed_service.dart:158-166`
- Clamp / mood: `tamagotchi_server/lib/src/creature/creature_service.dart:20,44-51`
- Inverse-dial idiom: `tamagotchi_server/lib/src/creature/play_service.dart`
- Provider: `tamagotchi_flutter/lib/creature/creature_provider.dart:11-13`
- Lessons: `context/foundation/lessons.md:5-9,12-22,24-29,50-55`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Decay Anchor + Migration

#### Automated

- [x] 1.1 `serverpod generate` completes without error — ca8ff89
- [x] 1.2 Migration created via `serverpod create-migration` — ca8ff89
- [x] 1.3 Migration applies cleanly via `serverpod run start` — ca8ff89
- [x] 1.4 `dart analyze` passes in `tamagotchi_server/` — ca8ff89
- [x] 1.5 Generated `Creature` exposes `lastDecayedAt` — ca8ff89

#### Manual

- [x] 1.6 `lastDecayedAt` column exists on the creature table — ca8ff89
- [x] 1.7 Existing creature row backfilled with non-null `lastDecayedAt` — ca8ff89

### Phase 2: Server Decay Engine (Read Path)

#### Automated

- [x] 2.1 Unit tests pass for the pure decay fn (elapsed cases, floor, cap, illness, scaling, determinism) — 78c52e0
- [x] 2.2 Integration test: `myCreature` decays + advances anchor; immediate re-call is a no-op — 78c52e0
- [x] 2.3 `serverpod generate` clean; `dart analyze` passes — 78c52e0
- [x] 2.4 `dart format --set-exit-if-changed .` clean in `tamagotchi_server/` — 78c52e0

#### Manual

- [x] 2.5 Idle creature reflects decay on next `myCreature`; higher `timeScale` increases decay — 78c52e0

### Phase 3: Decay-Before-Interaction

#### Automated

- [x] 3.1 Integration tests: feed/play/cure decay-before-interaction, anchor advanced, single journal entry — f35d5b1
- [x] 3.2 Existing feed/play/cure tests still pass (feed RNG draw-order intact) — f35d5b1
- [x] 3.3 `serverpod generate` clean; `dart analyze` passes — f35d5b1
- [x] 3.4 `dart format --set-exit-if-changed .` clean in `tamagotchi_server/` — f35d5b1

#### Manual

- [x] 3.5 Interacting after idle reflects decay-then-interaction — f35d5b1

### Phase 4: Frontend Slider + Scaled Polling

#### Automated

- [x] 4.1 Widget test: slider renders, defaults 1×, updates time-scale provider — ed86d69
- [x] 4.2 Widget test: provider + interaction controllers pass `timeScale` — ed86d69
- [x] 4.3 Test: poll timer interval scales inversely with `timeScale` and invalidates `creatureProvider` — ed86d69
- [x] 4.4 `flutter analyze` passes; `dart format --set-exit-if-changed .` clean in `tamagotchi_flutter/` — ed86d69
- [x] 4.5 `flutter test` passes — ed86d69

#### Manual

- [x] 4.6 Slider visibly scales decay speed + refresh cadence; decayed values render without layout breakage — ed86d69
- [x] 4.7 (Optional) `patrol` e2e smoke still passes — ed86d69
