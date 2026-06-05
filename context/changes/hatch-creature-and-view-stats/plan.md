# Hatch a creature and view its stats (S-02) — Implementation Plan

## Overview

S-02 is the project's **first first-party persisted vertical slice**. A logged-in
user hatches exactly one creature (random personality modifiers, fixed baseline
stats), then sees its four stats (hunger / energy / love / illness), a derived
**mood**, and its name. No AI, no decay, no interactions — those are deferred to
S-03 (AI responses) and S-07 (real-time decay/regen). This slice **fixes the data
model for creature + personality + journal**, which S-03–S-09 extend.

## Current State Analysis

- **No first-party persisted model exists.** The only `.spy.yaml` is
  `tamagotchi_server/lib/src/greetings/greeting.spy.yaml` with `table:` commented
  out — a wire-only serializable, not an ORM precedent. S-02 introduces the first
  `CREATE TABLE`, the first `requireLogin` first-party endpoint, the first
  migration with a first-party table, and the first async-data Riverpod provider.
- **Owner scoping pattern is established by auth:** the migrated auth tables store
  `authUserId uuid` as a bare scalar (`migrations/20260521163433251/migration.sql:245`).
  `config/generator.yaml` has **no `modules:` nickname**, so cross-module FK
  shorthand will not resolve — owner is a plain `ownerUuid: UuidValue` scoped in
  app code.
- **Flutter home is the slot:** `tamagotchi_flutter/lib/home/home_screen.dart` is
  already a `ConsumerWidget` whose body is a `const Center` with
  `Text('No creature yet — hatch one to begin')` (`:34-42`). Its docstring notes
  "no Hatch button (hatching is S-02)". All existing providers are synchronous
  `Provider`s — S-02 introduces the first `FutureProvider`/async surface.
- **Test harness exists (S-01):** `test/home/home_screen_test.dart` wires a real
  `Client` to an in-memory auth session and pumps via `UncontrolledProviderScope`.
  Lines `:93,96` currently assert the "No creature yet" copy and
  `find.byType(ElevatedButton) → findsNothing` — adding a Hatch button breaks
  these **by design**; S-02 updates them.
- **Determinism is a hard PRD guardrail** (`prd.md:39`): mood derivation and stat
  seeding must be pure functions of their inputs. Trait-modifier randomization at
  hatch is the one sanctioned source of nondeterminism and must be isolated so the
  rest stays deterministically testable.

## Desired End State

A signed-in user with no creature sees a name input and a **Hatch** button on
`/`. Hatching creates their creature (baseline stats, random personality
modifiers), writes a "hatched" journal marker, and immediately shows the stats
view: the creature's **name**, four raw stat numbers (0–100), and a derived
**mood** label. Reloading and calling `myCreature` returns the same creature with
the same mood (deterministic). A second hatch attempt by the same user is
rejected. The creature, personality, and journal tables exist in a new applied
migration.

**Verification:** `client.creature.hatch('Nibbles')` returns a `CreatureStatus`
with the baseline stats and mood `content`; a second call throws; `myCreature`
returns it; the Flutter home shows the stats view; backend mood unit tests and the
hatch integration test pass.

### Key Discoveries:

- Owner-as-scalar, not cross-module FK — `migration.sql:245`; driven by the absent
  `modules:` nickname in `config/generator.yaml`.
- Endpoint auto-registers from the feature dir; client name = class minus
  `Endpoint`, lowercased → `client.creature` (`research.md:87`).
- Auth user id inside a method: `UuidValue.fromString(session.authenticated!.userIdentifier)`
  (`research.md:99-102`).
- Mood must be **derived-on-read** (un-stored) so it stays consistent once S-07
  decay mutates stats (`frame.md:50`).
- `riverpod_lint` is inert in this workspace — Riverpod-rule violations need manual
  review ([[project_riverpod_lint_inert_in_pub_workspace]]).

## What We're NOT Doing

- **No real-time decay or energy regen** (S-07). Stats are static after hatch.
  Personality modifiers are persisted but **inert** — nothing reads them at S-02.
- **No AI responses or narrative journal generation** (S-03). The hatched journal
  marker carries no narrative prose.
- **No Feed / Pet / Cure interactions** or interaction modifiers (picky/gluttonous,
  introvert/extravert) — those modifier fields are added when S-03/S-04 land
  (additive, non-destructive).
- **No mood icons / expressive display** — raw stat numbers for MVP (`prd.md:117`).
- **No reset / re-hatch** (S-09), **no journal reading screen** (S-08), **no
  trait-roll constraints** (no constraint for MVP per `prd.md:116`).
- **No vector column** on the journal (ORQ-1 resolved to last-10 narrative entries;
  semantic search is a future AI tool).

## Implementation Approach

Build server-first so `serverpod generate` can produce the RPC client before the
Flutter side compiles. Three persisted tables (creature, personality 1:1, journal)
plus two enums and a non-table `CreatureStatus` DTO that bundles the creature with
its derived mood. The endpoint stays thin; the pure mood function and the
randomized seeding live in `creature_service.dart` for isolated unit testing.
One-creature-per-user is enforced in two layers: an app pre-check and a DB unique
index backstop. The Flutter side establishes the `AsyncValue.when` +
provider-override-in-tests pattern every later interactive slice will copy.

## Critical Implementation Details

- **Mood derivation rule (the decided oracle).** `CreatureMood {happy, content,
  sad, sick}`, pure function of the four stats. Per-stat *distress*: `hunger`,
  `100-energy`, `100-love`, `illness`. **Illness has priority**: `illness ≥ 50 →
  sick`. Otherwise `worst = max(hungerDistress, energyDistress, loveDistress)` and
  `worst < 25 → happy`, `< 55 → content`, else `sad`. Thresholds (`50/25/55`) are
  the agreed design choice — at the hatch baseline (love distress 50) this yields
  **content**, the intended "newborn, not yet bonded" state. These constants are
  the test oracle; tests assert against them, not against a re-derivation of the
  implementation.
- **Atomicity.** Hatch performs three inserts (creature, personality, journal
  marker). Wrap them in `session.transaction(...)`. The app-level one-per-user
  pre-check is non-atomic, so the `ownerUuid` **unique index is the race-safe
  backstop** — the concurrent-double-hatch branch is integration-tested against a
  real DB, not mocked (root `CLAUDE.md` test guidance).
- **Randomization isolation.** Only the 8 personality modifiers are randomized;
  stats are fixed baseline. Keep the RNG behind a seam in `creature_service.dart`
  so mood/seeding logic stays deterministically testable.

---

## Phase 1: Backend data model & migration

### Overview

Define the three tables, two enums, and the response DTO; regenerate Serverpod
code; create and apply the migration locally.

### Changes Required:

#### 1. Creature model

**File**: `tamagotchi_server/lib/src/creature/creature.spy.yaml`

**Intent**: The core persisted creature, owned by the auth user, with fixed
baseline stats set at hatch.

**Contract**: `class: Creature`, `table: creature`. Fields: `id: UuidValue?,
defaultPersist=random_v7` (PK); `ownerUuid: UuidValue`; `name: String`; `hunger:
int`; `energy: int`; `love: int`; `illness: int`; `hatchedAt: DateTime,
default=now`. `indexes:` a **unique** index on `ownerUuid` (one creature per
user). Stats are `int` on a 0–100 scale.

#### 2. Personality model (1:1)

**File**: `tamagotchi_server/lib/src/creature/creature_personality.spy.yaml`

**Intent**: Per-stat decay/regen modifiers, randomized at hatch, inert until S-07.
Stored in its own table 1:1 with the creature.

**Contract**: `class: CreaturePersonality`, `table: creature_personality`. Fields:
`id: UuidValue?, defaultPersist=random_v7`; a 1:1 relation to `Creature`
(`creatureId` FK with a **unique** index); eight `double` modifiers —
`hungerDecayMod, hungerRegenMod, energyDecayMod, energyRegenMod, loveDecayMod,
loveRegenMod, illnessDecayMod, illnessRegenMod`. Modifiers are multipliers around
a `1.0` baseline; the randomization range (default `0.5`–`1.5`) is applied in the
service, not the schema. Interaction modifiers are **out of scope** (added in
S-03/S-04, additively).

#### 3. Journal model + event enum

**File**: `tamagotchi_server/lib/src/creature/journal_entry.spy.yaml`,
`tamagotchi_server/lib/src/creature/journal_event.spy.yaml`

**Intent**: The journal table is defined now (load-bearing) even though only a
non-narrative "hatched" marker is written at S-02. No vector column.

**Contract**: `enum: JournalEvent` with `values: [hatched, feed, pet, cure]`.
`class: JournalEntry`, `table: journal_entry`. Fields: `id` (PK); `creatureId:
UuidValue` (non-unique index — many entries per creature); `ownerUuid: UuidValue`
(direct scoping); `timestamp: DateTime, default=now`; `event: JournalEvent`;
`prose: String, default=''` (empty for the hatched marker); `statDelta:
StatDelta?` (nullable — null for the hatched marker; populated by S-03+). Define a
non-table `class: StatDelta` with `hungerDelta/energyDelta/loveDelta/illnessDelta:
int` for forward use.

#### 4. Mood enum + response DTO

**File**: `tamagotchi_server/lib/src/creature/creature_mood.spy.yaml`,
`tamagotchi_server/lib/src/creature/creature_status.spy.yaml`

**Intent**: Mood is derived-on-read, never stored; the endpoint returns the
creature bundled with its computed mood.

**Contract**: `enum: CreatureMood` with `values: [happy, content, sad, sick]`.
`class: CreatureStatus` (non-table serializable) with fields `creature: Creature`
and `mood: CreatureMood`. This is the hatch/myCreature return type.

#### 5. Codegen + migration

**File**: generated output under `lib/src/generated/creature/**` and a new
`migrations/<timestamp>/` sibling.

**Intent**: Materialize the models and create the first first-party migration.

**Contract**: From `tamagotchi_server/`: `serverpod generate`, then
`serverpod create-migration`, then apply locally with `dart bin/main.dart
--apply-migrations` (Postgres sidecar via `docker compose up -d`). Produces a new
`migration_registry.txt` line. Never hand-edit the migration SQL.

### Success Criteria:

#### Automated Verification:

- `serverpod generate` completes without errors from `tamagotchi_server/`
- `serverpod create-migration` produces a new timestamped migration + registry line
- Migration applies cleanly: `dart bin/main.dart --apply-migrations`
- Server analyzes clean: `dart analyze` in `tamagotchi_server/`

#### Manual Verification:

- New tables `creature`, `creature_personality`, `journal_entry` exist in the local
  Postgres with the expected columns and the two unique indexes
- `migration_registry.txt` lists the new migration after the auth baseline

**Implementation Note**: After automated verification passes, pause for manual
confirmation before Phase 2.

---

## Phase 2: Backend service, endpoint & tests

### Overview

Implement the pure mood function, randomized seeding, the hatch/view endpoint with
one-per-user enforcement and the hatched journal marker; regenerate the RPC
client; cover mood logic and the unique-constraint branch with tests.

### Changes Required:

#### 1. Creature service (pure logic)

**File**: `tamagotchi_server/lib/src/creature/creature_service.dart`

**Intent**: Hold the deterministic, DB-free logic — mood derivation, baseline stat
seeding, and randomized personality-modifier generation — so it is unit-testable
in isolation.

**Contract**: `CreatureMood deriveMood(int hunger, int energy, int love, int
illness)` implementing the illness-priority / worst-stat rule with thresholds
`50/25/55` (see Critical Implementation Details). A baseline-stats constant
(`hunger=0, energy=100, love=50, illness=0`). A modifier generator returning the 8
doubles in `0.5`–`1.5` behind an injectable RNG seam.

#### 2. Creature endpoint

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: The first `requireLogin` first-party endpoint: create-and-view.

**Contract**: `class CreatureEndpoint extends Endpoint` with `bool get
requireLogin => true`.
- `Future<CreatureStatus> hatch(Session session, String name)`: resolve
  `UuidValue.fromString(session.authenticated!.userIdentifier)`; reject blank
  `name`; app pre-check for an existing creature; inside `session.transaction`
  insert creature (baseline stats), personality (random modifiers), and a
  `JournalEntry(event: hatched, prose: '', statDelta: null)`; return
  `CreatureStatus(creature, deriveMood(...))`.
- `Future<CreatureStatus?> myCreature(Session session)`: find the caller's
  creature; return null if none, else `CreatureStatus(creature, deriveMood(...))`.

#### 3. Serializable error

**File**: `tamagotchi_server/lib/src/creature/creature_errors.spy.yaml`

**Intent**: Typed, client-visible failures for the two rejected paths.

**Contract**: `exception: CreatureHatchError` with a `reason: String` (or a small
enum) covering `alreadyHatched` and `emptyName`. Thrown from `hatch`.

#### 4. Regenerate RPC client

**File**: generated `tamagotchi_client/lib/src/protocol/**` and
`lib/src/generated/endpoints.dart`.

**Intent**: Expose `client.creature.hatch/myCreature` to Flutter.

**Contract**: `serverpod generate` from `tamagotchi_server/` regenerates the
client; `client.creature` appears in `protocol/client.dart`.

#### 5. Backend tests

**File**: `tamagotchi_server/test/creature/creature_service_test.dart` (unit),
`tamagotchi_server/test/creature/creature_endpoint_test.dart` (integration).

**Intent**: Pin the mood oracle and the race-safe one-per-user invariant.

**Contract**: Unit — `deriveMood` parameterized cases asserting the agreed spec:
baseline → `content`; `illness ≥ 50` → `sick` (even with otherwise-good stats);
all-good → `happy`; all-bad → `sad`; threshold boundaries at 25/55/50. Assertions
come from the decided rule, **not** from re-deriving the implementation.
Integration (real DB, `serverpod-testing`/`withServerpod`) — `hatch` creates
creature+personality+journal-marker; a second `hatch` by the same user is rejected
(unique-index backstop); `myCreature` returns null then the creature+mood.

### Success Criteria:

#### Automated Verification:

- `serverpod generate` regenerates `client.creature` without errors
- Unit tests pass: `dart test test/creature/creature_service_test.dart`
- Integration tests pass: `dart test test/creature/creature_endpoint_test.dart`
  (local Postgres up)
- Server analyzes clean: `dart analyze` in `tamagotchi_server/`

#### Manual Verification:

- Calling `hatch('Nibbles')` once succeeds and returns mood `content`; a second
  call surfaces `CreatureHatchError(alreadyHatched)`
- A blank name is rejected with `CreatureHatchError(emptyName)`
- The journal has exactly one `hatched` row after a single hatch

**Implementation Note**: After automated verification passes, pause for manual
confirmation before Phase 3.

---

## Phase 3: Flutter provider, hatch action & UI

### Overview

Add the first async-data provider, a hatch action, the creature stats view, and
the name-input/Hatch empty state — wired into the existing `/` home.

### Changes Required:

#### 1. Creature fetch provider

**File**: `tamagotchi_flutter/lib/creature/creature_provider.dart` (+ committed
`.g.dart`)

**Intent**: Establish the project's first async-data provider for the current
creature.

**Contract**: `@Riverpod(keepAlive: true) Future<CreatureStatus?> creature(Ref
ref) async => ref.read(serverpodClientProvider).creature.myCreature();`. Consumed
via `AsyncValue.when`.

#### 2. Hatch action

**File**: `tamagotchi_flutter/lib/creature/hatch_controller.dart` (+ `.g.dart`)

**Intent**: Drive button → loading → result, then surface the new creature.

**Contract**: An async action (riverpod mutation or `AsyncNotifier`) exposing
`Future<void> hatch(String name)` that calls `client.creature.hatch(name)` and, on
success, refreshes/invalidates `creatureProvider` so the stats view renders.
Surfaces `CreatureHatchError` to the UI.

#### 3. Creature stats view + hatch form

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`,
`tamagotchi_flutter/lib/creature/hatch_form.dart`

**Intent**: Render the two states — empty (name input + Hatch button) and present
(name + four raw stats + mood label).

**Contract**: `CreatureView` displays `status.creature.name`, the four stat ints
(0–100, raw numbers per MVP), and `status.mood`. `HatchForm` has a name
`TextField` (non-empty validation), a Hatch button bound to the hatch action, a
loading indicator while pending, and an inline error on `CreatureHatchError`.

#### 4. Home wiring

**File**: `tamagotchi_flutter/lib/home/home_screen.dart`

**Intent**: Replace the static "No creature yet" body with the
provider-driven conditional.

**Contract**: Drop the `const` body; `ref.watch(creatureProvider).when(loading:
spinner, error: message+retry, data: (status) => status == null ? HatchForm() :
CreatureView(status))`. No new route — both states live under `/`.

#### 5. Flutter codegen

**File**: generated `*.g.dart` for the new providers.

**Contract**: `dart run build_runner build --delete-conflicting-outputs` from
`tamagotchi_flutter/`.

### Success Criteria:

#### Automated Verification:

- `dart run build_runner build --delete-conflicting-outputs` succeeds
- Flutter analyzes clean: `dart analyze` in `tamagotchi_flutter/`
- Web build succeeds: `serverpod run flutter_build` from `tamagotchi_server/`

#### Manual Verification:

- Signed-in user with no creature sees the name input + Hatch button
- Entering a name and hatching shows a spinner, then the stats view (name, four
  stats, mood `content`)
- Reload still shows the same creature/mood; the empty state does not reappear
- A blank name is blocked client-side; a duplicate hatch error renders inline

**Implementation Note**: After automated verification passes, pause for manual
confirmation before Phase 4.

---

## Phase 4: Flutter widget tests & S-01 assertion updates

### Overview

Update the S-01 home test for the new Hatch affordance and add creature-view tests
using provider overrides for loading/error/data and the hatch flow.

### Changes Required:

#### 1. Update home test

**File**: `tamagotchi_flutter/test/home/home_screen_test.dart`

**Intent**: The "No creature yet" + no-button assertions (`:93,96`) are now wrong
by design.

**Contract**: With `creatureProvider` overridden to `AsyncData(null)`, assert the
Hatch button and name field are present (replace the `findsNothing` /
"No creature yet" assertions). Reuse the S-01 real-client + in-memory-auth harness.

#### 2. Creature view/flow tests

**File**: `tamagotchi_flutter/test/creature/creature_view_test.dart`

**Intent**: Cover the new async surface with cheap, hermetic overrides rather than
round-tripping the RPC.

**Contract**: Override `creatureProvider` with canned `AsyncValue`s —
`loading` → spinner; `error` → error widget; `data(status)` → name + four stats +
mood label. One hatch-flow test: from `data(null)`, enter a name, tap Hatch, and
assert the stats view appears (stub the hatch action / flip the override). At least
one edge case: blank-name submission is blocked.

#### 3. Cookbook / plan sync

**File**: `context/foundation/test-plan.md` §6 (cookbook), this plan's `## Progress`.

**Intent**: Record the new async-provider-override test recipe and mark progress.

**Contract**: Add a short cookbook note on overriding an async creature provider in
the S-01 harness; tick the Progress checkboxes with commit shas.

### Success Criteria:

#### Automated Verification:

- All Flutter tests pass: `dart test` in `tamagotchi_flutter/`
- Flutter analyzes clean: `dart analyze` in `tamagotchi_flutter/`

#### Manual Verification:

- Test names read as behavioural assertions (mood/state outcomes), not
  implementation mirrors
- The cookbook entry is accurate and reusable for S-03's interactive slice

**Implementation Note**: Final phase — confirm the full slice end-to-end after
tests pass.

---

## Testing Strategy

### Unit Tests:

- `deriveMood`: baseline→content, illness-override→sick, all-good→happy,
  all-bad→sad, threshold boundaries (25/55/50). Oracle = the decided rule.
- Edge: illness override beats otherwise-good stats; exact-threshold values.

### Integration Tests:

- Real-DB hatch creates creature + personality + journal marker in one transaction.
- Second hatch by the same user is rejected (unique-index backstop) — the
  non-atomic check-then-insert branch tested against real DB, not mocked.
- `myCreature` returns null then the creature+mood.

### Manual Testing Steps:

1. Sign in as a fresh user → see name input + Hatch button.
2. Hatch "Nibbles" → spinner → stats view (name, four stats, mood `content`).
3. Reload → same creature persists; empty state gone.
4. Attempt a second hatch (e.g. via API) → rejected.
5. Submit a blank name → blocked.

## Performance Considerations

Trivial scale (one creature per user, three single-row inserts behind one
transaction). No hotspots. Mood is an O(1) pure computation on read.

## Migration Notes

First first-party migration — additive only (three new tables, two unique
indexes). No existing data to migrate. scloud applies at deploy/startup; locally
via `--apply-migrations`. Interaction modifiers and journal narrative content are
**future additive** changes (new fields), never edits to these columns.

## References

- Frame brief: `context/changes/hatch-creature-and-view-stats/frame.md`
- Research: `context/changes/hatch-creature-and-view-stats/research.md`
- Owner-as-scalar precedent: `tamagotchi_server/migrations/20260521163433251/migration.sql:245`
- Endpoint precedent: `tamagotchi_server/lib/src/greetings/greeting_endpoint.dart`
- Home slot: `tamagotchi_flutter/lib/home/home_screen.dart:34-42`
- Test harness: `tamagotchi_flutter/test/home/home_screen_test.dart:13-30,93,96`
- Oracle: `context/foundation/prd.md:39,60,66,116-117`; `context/foundation/roadmap.md:107-118`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Backend data model & migration

#### Automated

- [x] 1.1 `serverpod generate` completes without errors — d49a77b
- [x] 1.2 `serverpod create-migration` produces a new migration + registry line — d49a77b
- [x] 1.3 Migration applies cleanly via `--apply-migrations` — d49a77b
- [x] 1.4 Server analyzes clean (`dart analyze`) — d49a77b

#### Manual

- [x] 1.5 Three tables exist with expected columns + two unique indexes — d49a77b
- [x] 1.6 `migration_registry.txt` lists the new migration after the auth baseline — d49a77b

### Phase 2: Backend service, endpoint & tests

#### Automated

- [x] 2.1 `serverpod generate` regenerates `client.creature` — f670066
- [x] 2.2 Mood unit tests pass — f670066
- [x] 2.3 Hatch integration tests pass (local Postgres) — f670066
- [x] 2.4 Server analyzes clean — f670066

#### Manual

- [x] 2.5 First hatch succeeds (mood `content`); second rejected with `alreadyHatched` — f670066 (integration test)
- [x] 2.6 Blank name rejected with `emptyName` — f670066 (integration test)
- [x] 2.7 Exactly one `hatched` journal row after a single hatch — f670066 (integration test)

### Phase 3: Flutter provider, hatch action & UI

#### Automated

- [x] 3.1 `build_runner build` succeeds — d5ecf87
- [x] 3.2 Flutter analyzes clean — d5ecf87
- [x] 3.3 Web build succeeds (`flutter_build`) — d5ecf87

#### Manual

- [x] 3.4 Empty state shows name input + Hatch button — d5ecf87
- [x] 3.5 Hatch flow: spinner → stats view (name, four stats, mood `content`) — d5ecf87
- [x] 3.6 Reload persists creature; empty state gone — d5ecf87
- [x] 3.7 Blank name blocked client-side; duplicate-hatch error renders inline — d5ecf87

### Phase 4: Flutter widget tests & S-01 assertion updates

#### Automated

- [x] 4.1 All Flutter tests pass (`dart test`)
- [x] 4.2 Flutter analyzes clean

#### Manual

- [x] 4.3 Test names read as behavioural assertions, not implementation mirrors
- [x] 4.4 Cookbook entry accurate and reusable for S-03
