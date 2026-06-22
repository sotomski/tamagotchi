---
date: 2026-06-21T10:57:01+00:00
researcher: Karol Sotomski
git_commit: 7f86e6cea931f428a75ffd88f843e21c6cd50595
branch: main
repository: sotomski/tamagotchi
topic: "Real-time stat decay and energy regen (FR-008 / roadmap S-07)"
tags: [research, codebase, creature, stats, decay, future-calls, serverpod, riverpod]
status: complete
last_updated: 2026-06-21
last_updated_by: Karol Sotomski
---

# Research: Real-time stat decay and energy regen (FR-008 / roadmap S-07)

**Date**: 2026-06-21T10:57:01+00:00
**Researcher**: Karol Sotomski
**Git Commit**: 7f86e6cea931f428a75ffd88f843e21c6cd50595
**Branch**: main
**Repository**: sotomski/tamagotchi

## Research Question

What does the codebase already provide for implementing FR-008 — "Stats change in
real time at personality-driven rates (including while the user is away), and
never drop below a minimum floor. Energy regenerates in real time." — and what
are the concrete, codebase-grounded trade-offs for the two deferred design
decisions in roadmap slice **S-07** (`real-time-stat-decay`):

1. The personality-driven decay-rate formula/table.
2. **Lazy-on-read** decay computation vs **Serverpod FutureCall**-pushed decay.

## Summary

The codebase is well-positioned for this slice and the dominant patterns point
toward a **lazy-on-read** design, while the roadmap explicitly flags FutureCall
as the "more conventional" option and an intentional learning target.

Key facts:

- **The data model has the personality dials but is missing a decay anchor.**
  `CreaturePersonality` already carries per-stat `*DecayMod` / `*RegenMod`
  multipliers (range `[0.5, 1.5)`) purpose-built for personality-driven rates.
  The only timestamp on `Creature` is `hatchedAt` — there is **no
  `lastDecayedAt` / `lastSeenAt`** field, so any elapsed-time approach needs a
  new column + migration.
- **"Derive on read" is already the idiom.** `myCreature` returns the stored row
  plus a server-computed `mood` (`deriveMood`) that is never persisted. Applying
  elapsed-time decay in that same read path is a natural fit and changes nothing
  for clients.
- **The DI / determinism patterns are proven and reusable.** Interactions inject
  impure collaborators (RNG, LLM) through a single production-default factory
  seam (`feedServiceFactory` etc.); `lessons.md` explicitly names **"clock"** as
  an in-scope collaborator for this exact seam. No clock seam exists yet — this
  slice introduces the first one.
- **FutureCalls are fully supported but entirely unused.** They are DB-backed and
  restart-surviving, so the no-Redis / single-instance constraint does **not**
  disqualify them; adopting them means net-new bootstrap wiring + a `serverpod
  generate` cycle.
- **The frontend has no refresh-on-return today.** `creatureProvider` is
  `keepAlive: true` and only re-fetches on explicit `ref.invalidate` after an
  interaction or an error retry. Leaving and returning to the tab shows stale
  stats — closing this gap is part of the slice if "return to see decayed stats"
  is to work without a manual interaction.

## Detailed Findings

### Creature & personality data model

The creature row and its 1:1 personality row hold all the mechanical state.

- Creature model: `tamagotchi_server/lib/src/creature/creature.spy.yaml:1-27`.
  Stats are `int` on a 0–100 scale: `hunger` (higher = hungrier), `energy`
  (higher = more rested), `love` (higher = bonded), `illness` (higher = sicker).
  The **only timestamp is `hatchedAt: DateTime, default=now`** (line ~21). There
  is **no `updatedAt` / `lastDecayedAt` / `lastInteractionAt`**.
- Personality model: `tamagotchi_server/lib/src/creature/creature_personality.spy.yaml:1-27`.
  Seven `double` multipliers around a 1.0 baseline (range `[0.5, 1.5)`):
  `hungerDecayMod`, `hungerRegenMod`, `energyDecayMod`, `energyRegenMod`,
  `loveRegenMod` (a single introvert↔extravert dial — **note there is no
  `loveDecayMod`**), `illnessDecayMod`, `illnessRegenMod`.
- The modifier tuple is mirrored as a typedef in
  `tamagotchi_server/lib/src/creature/creature_service.dart:26-34`
  (`PersonalityModifiers`), with `randomPersonalityModifiers(Random rng)` rolling
  each via `0.5 + rng.nextDouble()` at `creature_service.dart:56-67`.
- Baseline hatch stats: `const baselineCreatureStats = (hunger: 0, energy: 100,
  love: 50, illness: 0)` — `creature_service.dart:14`.

**Implication for decay rates:** the dials already exist and map cleanly onto
FR-008 ("personality-driven rates"). The gap is (a) a decay *anchor* timestamp
and (b) deciding how `love` decays given it has only a regen dial.

### Stat read path & mood derivation (the "derive on read" seam)

- `CreatureEndpoint.myCreature` —
  `tamagotchi_server/lib/src/creature/creature_endpoint.dart:115-128`: loads the
  row with `Creature.db.findFirstRow` and returns
  `CreatureStatus(creature: creature, mood: _moodOf(creature))`. **The stored row
  is returned verbatim; the only computed layer is `mood`.**
- `deriveMood` — `tamagotchi_server/lib/src/creature/creature_service.dart:44-51`:
  `illness >= 50 → sick`; else `worst = max(hunger, 100-energy, 100-love)`;
  `<25 → happy`, `<55 → content`, else `sad`. Computed server-side, **never
  stored** (mood enum: `creature_mood.spy.yaml`).
- Every interaction return (`hatch`, `feed`, `play`, `cure`) wraps the updated
  creature in `CreatureStatus(updated, _moodOf(updated))` — same pattern.

This is the cleanest insertion point for lazy decay: compute elapsed-time decay,
persist the decayed stats, then derive mood from the decayed values.

### Stat mutation, clamping & the determinism gate

- **Single clamp helper:** `int clampStat(int v) => v.clamp(0, 100)` —
  `creature_service.dart:20`. All interaction deltas are **clamp-encoded**:
  `delta = clampStat(target) - current`, so adding the delta always lands inside
  [0,100]. Decay should reuse this so the **floor mechanic** (FR-008's "never
  below a minimum floor") is just the lower clamp bound (or a higher per-stat
  floor if desired).
- **Feed** (`feed_service.dart`): `feedHungerDrop = 30`, `feedEnergyCost = 10`
  (fixed); short-circuits when `hunger == 0`; deltas built at
  `feed_service.dart:93-94`; the **picky accept/refuse roll** is the one source of
  non-determinism. RNG **draw order is contract**: tastiness first, then reject
  roll (`feed_service.dart:49-52`). `pickyFactor = 1.5 - hungerDecayMod`
  (`feed_service.dart:27`).
- **Play/Pet** (`play_service.dart`): deterministic. `playLoveGain = round(15 *
  loveRegenMod)` (~8–22); `playEnergyCost = round(4 * (2 - loveRegenMod))` (~2–6,
  introverts tire more). Deltas at `play_service.dart:39-40`.
- **Cure** (`cure_service.dart`): deterministic, **no energy cost**
  (`energyDelta: 0`), always available. `cureRelief = round(40 *
  illnessDecayMod)` (~20–60). Delta at `cure_service.dart:32`.
- **Atomic persist:** every mutation writes the creature row **and** a
  `JournalEntry` inside one `session.db.transaction(...)` — Feed example at
  `creature_endpoint.dart:207-231` (`Creature.db.updateRow` +
  `JournalEntry.db.insertRow`). Decay must decide whether it writes a journal
  entry (interactions always do; decay likely should not, to avoid log spam).

### Dependency-injection factory-seam pattern (the clock will follow this)

The canonical pattern (`lessons.md:24-29`, "inject impure collaborators via one
production-default factory seam, never `@visibleForTesting`"):

1. Production factory: `FeedService feedServiceFor(Session session) =>
   FeedService(rng: Random(), llm: llmServiceFor(session));` —
   `feed_service.dart:158-159`.
2. Global seam: `FeedService Function(Session session) feedServiceFactory =
   feedServiceFor;` — `feed_service.dart:166`.
3. Endpoint always calls through the seam:
   `final feedService = feedServiceFactory(session);` —
   `creature_endpoint.dart:164`.
4. Test reassigns + self-cleans: `feedServiceFactory = (_) => FeedService(rng:
   ScriptedRandom(doubles), llm: llm); addTearDown(() => feedServiceFactory =
   feedServiceFor);` — `test/integration/feed_endpoint_test.dart:29-40`.

Mirror seams exist for `playServiceFactory` (`play_service.dart:86-94`) and
`cureServiceFactory` (`cure_service.dart:79-87`). The LLM seam
`llmServiceFor(session)` selects real vs stub by `session.passwords['mistralApiKey']`
(`llm/llm_service.dart:77-88`).

**`lessons.md:26` explicitly lists "clock" as a collaborator for this seam** — so
a `DateTime Function() clockFor(session)` / `clockFactory` seam is the
project-blessed way to make decay deterministically testable.

### Time usage today — no clock seam exists

- A sweep of `tamagotchi_server/lib/src/` for `DateTime.now()` / `clock` /
  `Stopwatch` finds **no domain usage**: only the scaffold
  `greetings/greeting_endpoint.dart:31`, the default
  `web/widgets/built_with_serverpod_page.dart:9`, and a string literal in
  `llm/feed_copy.dart`. The creature services read **zero** wall-clock time — all
  stat math is from current stat values.
- `DateTime.now()` defaults live only in generated constructors
  (`generated/creature/creature.dart:28` for `hatchedAt`,
  `generated/creature/journal_entry.dart:31` for `timestamp`).

So decay introduces the first real time-dependence in the domain, and the first
clock seam.

### Lazy-on-read vs FutureCall — codebase-grounded trade-offs

The roadmap already frames it (`roadmap.md` S-07 Unknowns): "Both work;
future-call is more conventional, lazy-on-read is cheaper," and notes the slice
"stretches the unfamiliar future-call API of Serverpod (per `main_goal: learn`,
this is a feature, not a bug)."

**FutureCall API available (Serverpod 3.4.8, `.claude/skills/serverpod-scheduling/SKILL.md`):**
- DB-backed, survives restarts, "execute once across all instances," **not
  available in serverless mode** (`SKILL.md:9`).
- Extend `FutureCall`; methods take `Session` + optional one serializable model
  (`SKILL.md:14-22`); requires `serverpod generate` to expose `pod.futureCalls`
  (`SKILL.md:25`).
- Schedule via `callWithDelay(Duration)` / `callAtTime(DateTime.utc(...))`
  (`SKILL.md:40-47`); cancel by `identifier` (`SKILL.md:50-54`).
- **No native "every N min" primitive** — recurrence = the call reschedules
  itself at the end of its body (`SKILL.md:59-69`); an unhandled throw breaks the
  chain, so you must catch + reschedule (`SKILL.md:71`).
- Config defaults: `futureCallExecutionEnabled` true, `concurrencyLimit` 1,
  `scanInterval` 5000ms (≈5s scheduling latency) (`SKILL.md:76-80`).

**Current state:** **zero** FutureCall usage anywhere in `tamagotchi_server/`
(excluding generated). Bootstrap `lib/server.dart:66-154` registers auth + web
routes and `pod.start()` — no future-call registration. The future-call config
block is commented out in every runmode (`config/development.yaml:55-59` and
peers), i.e. running on enabled-by-default framework settings, just unused.

**Infra constraints (do NOT block FutureCalls):** single instance, no Redis —
`prd.md:11`, `infrastructure.md:60` & `:103`, `tamagotchi_server/CLAUDE.md`.
Because FutureCalls are DB-backed (Postgres), they persist and survive restarts
without Redis; the "once across all instances" property is simply unused at one
instance. The only caveat is "not available in serverless mode" — the scloud
target is a persistent process, so confirm at deploy time.

| Axis | Lazy-on-read | FutureCall |
| --- | --- | --- |
| New infra/wiring | None — reuses `myCreature` read path | New `FutureCall` subclass, bootstrap registration, `serverpod generate` cycle, self-reschedule + catch-or-chain-dies |
| Cost | Computes only when fetched | Runs on a cadence even with nobody looking |
| Testability | Pure `decay(creature, personality, elapsed)` fn + injected clock seam → deterministic unit tests, no DB, no wall clock (matches existing `evaluateFeed`/`deriveMood` style) | Timing driven by framework scanner + DB rows → needs `withServerpod`; still wants a clock seam for the math anyway |
| Conventionality / learning goal | Less "Serverpod-idiomatic" but matches this repo's "derive on read" idiom | The "more conventional" choice and the explicit `main_goal: learn` target |
| Migration needed | Yes — a `lastDecayedAt` anchor on `Creature` | Often still wants the anchor to be drift-proof; could instead decay a fixed cadence |
| "While away" semantics | Computed at the moment of return (exactly when observed) | Continuously applied; observed value already current |

Both require a **new timestamp column + migration**; only FutureCall requires
net-new bootstrap wiring and a generate-cycle run. (Evidence only — the decision
is for `/10x-plan`.)

### Frontend stat display & the refresh-on-return gap

- `creatureProvider` —
  `tamagotchi_flutter/lib/creature/creature_provider.dart:11-13`:
  `@Riverpod(keepAlive: true) Future<CreatureStatus?> creature(Ref ref) =>
  ref.read(serverpodClientProvider).creature.myCreature();` — **not**
  auto-disposed (`creature_provider.g.dart:39` `isAutoDispose: false`).
- Re-fetch happens **only** via explicit `ref.invalidate(creatureProvider)`
  after hatch / feed / play / cure (`hatch_controller.dart:23`,
  `feed_controller.dart:29`, `play_controller.dart:30`, `cure_controller.dart:30`)
  and on the error-retry button (`home/home_screen.dart:47`).
- **No `AppLifecycleListener` / `didChangeAppLifecycleState`, no
  `RefreshIndicator` pull-to-refresh, no `Timer.periodic` polling, no GoRouter
  route observers.** Leaving the tab and returning re-shows cached stats — nothing
  triggers a re-fetch. This is the gap S-07's "return to see decayed stats" must
  close (e.g. a lifecycle-resume invalidate, a pull-to-refresh, or light polling).
- Stats render as raw ints in keyed `_StatRow` widgets (`key: 'statRow-$label'`)
  and mood as `'Mood: ${status.mood.name}'` —
  `tamagotchi_flutter/lib/creature/creature_view.dart:54-64` and `:209-228`.
  Decayed values flow straight into these with no widget changes.

### Test patterns to mirror

- **Server determinism gate:** `ScriptedRandom` implements `Random` with a
  scripted `nextDouble()` queue (`test/helpers/scripted_random.dart`); the seed
  oracle test asserts equality between two `Random(42)` runs
  (`test/unit/feed_service_test.dart:209-231`). A decay clock seam would get the
  same treatment (a `FakeClock`/scripted instants helper).
- **Integration:** `withServerpod` harness with per-test DB rollback (default),
  direct `Creature` + `CreaturePersonality` seeding via `*.db.insertRow`, and the
  factory-seam injection + `addTearDown` reset —
  `test/integration/feed_endpoint_test.dart:29-111`,
  `test/creature/creature_endpoint_test.dart:19-54`.
- **Flutter widget:** override `creatureProvider.overrideWith((ref) => ...)`
  inside `ProviderScope`; flip a `StateProvider` seam to simulate invalidation;
  fake controllers bypass the network — `test/creature/creature_view_test.dart`
  (e.g. "stats refresh after a successful feed" at `:421-450`). Matches
  `lessons.md:12-22` ("Test async Riverpod surfaces with provider overrides").
- **Runmodes:** `test` runmode → `tamagotchi_test` DB, no Redis
  (`config/test.yaml`); `e2e` runmode boots without `mistralApiKey` so
  `llmServiceFor` picks `StubLlmService` (`integration_test/E2E_RULES.md:96-100`).
  No clock seam or FutureCall test exists yet to copy from.

## Code References

- `tamagotchi_server/lib/src/creature/creature.spy.yaml:1-27` — creature stats + `hatchedAt` (no decay anchor)
- `tamagotchi_server/lib/src/creature/creature_personality.spy.yaml:1-27` — per-stat decay/regen mods (no `loveDecayMod`)
- `tamagotchi_server/lib/src/creature/creature_service.dart:14` — `baselineCreatureStats`
- `tamagotchi_server/lib/src/creature/creature_service.dart:20` — `clampStat` (floor/cap)
- `tamagotchi_server/lib/src/creature/creature_service.dart:26-34,56-67` — `PersonalityModifiers` typedef + `randomPersonalityModifiers`
- `tamagotchi_server/lib/src/creature/creature_service.dart:44-51` — `deriveMood`
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:115-128` — `myCreature` read path (derive-on-read)
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:207-231` — atomic stat-update + journal-insert transaction
- `tamagotchi_server/lib/src/creature/feed_service.dart:27,49-52,93-94,158-166` — picky factor, RNG draw-order contract, deltas, factory seam
- `tamagotchi_server/lib/src/creature/play_service.dart:25-43,86-94` — play math + seam
- `tamagotchi_server/lib/src/creature/cure_service.dart:23-36,79-87` — cure math (no energy cost) + seam
- `tamagotchi_server/lib/src/llm/llm_service.dart:77-88` — real-vs-stub selection by password
- `tamagotchi_server/lib/server.dart:66-154` — bootstrap (no future-call registration)
- `tamagotchi_server/config/development.yaml:55-59` — commented-out future-call block (peers in test/staging/production)
- `.claude/skills/serverpod-scheduling/SKILL.md:9-80` — FutureCall API + gotchas
- `tamagotchi_flutter/lib/creature/creature_provider.dart:11-13` — `creatureProvider` (keepAlive, manual invalidate only)
- `tamagotchi_flutter/lib/creature/creature_view.dart:54-64,209-228` — stat/mood rendering, keyed `_StatRow`
- `tamagotchi_flutter/lib/home/home_screen.dart:47` — error-retry invalidate
- `tamagotchi_server/test/helpers/scripted_random.dart` — deterministic RNG helper (template for a clock fake)
- `tamagotchi_server/test/integration/feed_endpoint_test.dart:29-111` — `withServerpod` seeding + seam injection
- `tamagotchi_flutter/test/creature/creature_view_test.dart:421-450` — provider-override stat-refresh test

## Architecture Insights

- **"Derive on read" is an established idiom** (`mood`), making lazy decay a
  low-friction extension of an existing pattern rather than a new concept.
- **One clamp, clamp-encoded deltas everywhere** — the FR-008 floor is naturally
  expressed as the lower clamp bound; reuse `clampStat` (or a per-stat floor) and
  keep the delta-encoding convention.
- **Determinism is a first-class product property** (PRD Guardrails) enforced via
  a single injectable-RNG seam. Decay must preserve this: a pure decay function +
  an injectable clock keeps "same inputs → same outputs," with elapsed-time the
  only new input.
- **`loveDecayMod` is absent** — a real design question, not an oversight to
  copy: decide whether love decays at all, decays at a flat rate, or reuses
  `loveRegenMod` inversely. Flag for `/10x-plan`.
- **A new persisted anchor + migration is unavoidable** for an elapsed-time
  model; follow `lessons.md` ("Apply Serverpod migrations via `serverpod run
  start`").

## Historical Context (from prior changes)

- `context/foundation/roadmap.md` — S-07 slice spec (outcome, prereqs S-02,
  the two named Unknowns: decay-rate formula; lazy-vs-future-call); Stream C
  "Background decay"; baseline notes "No future-call scaffolding."
- `context/foundation/prd.md:68` (FR-008) — the requirement, incl. the floor as
  the revised resolution to the "real-time decay creates guilt" counter-argument.
- `context/foundation/prd.md:39` (Guardrails) — determinism-except-feed-roll
  contract decay must not violate.
- `context/foundation/infrastructure.md:60,103` & `prd.md:11` — single instance,
  no Redis (FutureCalls remain viable: DB-backed).
- `context/foundation/lessons.md:24-29` — the factory-seam rule that names
  "clock" as in-scope; `:5-9` — apply migrations via `serverpod run start`.
- Archived interaction slices (`context/archive/2026-06-05-feed-with-personality-response`,
  `2026-06-20-pet-with-personality-response`, `2026-06-20-cure-the-creature`) —
  the established service/seam/test pattern this slice mirrors.

## Related Research

- No prior `research.md` exists for the interaction slices in
  `context/archive/**`; their `plan.md` files are the closest precedent for the
  service + seam + test shape.

## Open Questions

1. **Decay-rate formula/table per stat** (roadmap Unknown; owner: user) — exact
   units (points/hour?) and how each `*DecayMod` / `*RegenMod` scales them. Pick
   at `/10x-plan`; tunable later.
2. **Lazy-on-read vs FutureCall** (roadmap Unknown; owner: user) — evidence laid
   out above; not decided here. Note `main_goal: learn` tilts toward FutureCall,
   while cost/testability/existing-patterns tilt toward lazy.
3. **How does `love` decay?** There is no `loveDecayMod` — decide whether love
   decays, at what rate, and which dial (if any) modulates it.
4. **Per-stat floor values** — is the floor just 0 (existing clamp), or a higher
   "sad but recoverable" floor per FR-008's guilt-cap intent? And does energy
   regen toward 100 or a cap?
5. **Anchor field semantics** — one `lastDecayedAt`, or rely on `hatchedAt` +
   stored stats? Lazy needs a per-read-updated anchor to avoid re-applying decay.
6. **Frontend refresh trigger** — lifecycle-resume invalidate vs pull-to-refresh
   vs light polling to make "return to see decayed stats" work without a manual
   interaction. Which fits NFR "continuous visible progress"?
7. **Does decay write a journal entry?** Interactions always do; decay probably
   should not (log spam) — confirm at plan time.
