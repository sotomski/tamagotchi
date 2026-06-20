# Pet the creature and receive a personality-driven response + journal entry (S-04) — Implementation Plan

## Overview

S-04 adds the **Pet** interaction: a logged-in user pets their creature and receives a personality-shaped, in-character AI response; the journal gains a coherent narrative prose entry produced in the same LLM call; love rises and energy falls **deterministically**. Unlike Feed, Pet has **no random accept/refuse gate** — `prd.md:39` mandates "Pet/Cure remain entirely deterministic." FR-005's personality modifier is the **introvert↔extravert axis**: an extravert gains more love from petting, an introvert gains less *and* tires more (loses more energy). This slice reuses S-03's validated `LlmService` + Mistral + key-presence surface untouched, and establishes `loveRegenMod` as the single introvert↔extravert dial by **removing the now-redundant `loveDecayMod`**.

## Current State Analysis

S-03 (Feed, PR #9, merged) left a directly-reusable, anticipated-for-this-slice foundation (verified against the code):

- **`JournalEvent.pet` already exists** (`journal_event.spy.yaml:7`) — no enum change.
- **`InteractionRequest` is interaction-typed** (`llm_service.dart:43`: "typed for reuse by Pet/Cure"). It carries `personality`, the four stats, `mood`, `interactionType`, `accepted`, `tastiness`, `recentEntries`. For Pet: `accepted` is always `true`; `tastiness` is feed-only and ignored by the pet prompt branch.
- **The LLM surface is interaction-agnostic and needs no change.** `LlmService` (`llm_service.dart:62`), `MistralLlmService` (calls `buildInteractionMessages` + parses two fields), the key-presence selection seam (`llmServiceFor` / `llmServiceForKey`), and the secret wiring are all generic. Only the **prompt builder** (`creature_prompt.dart`, entirely food-flavoured) and the **stub** (`stub_llm_service.dart`, returns feed copy) are interaction-specific and need pet branches.
- **The Feed slice is the structural template.** The `feed()` endpoint (`creature_endpoint.dart:140-240`) does owner-scoped load → decision → last-10 memory fetch → LLM call (degrade on failure) → one `session.db.transaction` (stat update + journal insert) → result. `FeedResult` (`feed_result.spy.yaml`), `CreatureFeedError{noCreature}`, the `feedServiceFactory` injection seam (lesson #3), and the test patterns (`feed_endpoint_test.dart` `withServerpod` + injected stub/throwing LLM; `creature_view_test.dart` provider overrides, lesson #2) all have direct Pet analogues.
- **Pure domain layer to mirror.** `feed_service.dart` holds `clampStat`, the magnitude constants, the derived `pickyFactor(hungerDecayMod)`, and `evaluateFeed` under an injectable `Random`. Pet's math is simpler (no RNG): two derived magnitudes from `loveRegenMod`.
- **Flutter wiring to mirror.** `FeedController` (`feed_controller.dart`) drives idle→loading→result and `ref.invalidate(creatureProvider)`. `CreatureView` (`creature_view.dart`) is already a `ConsumerWidget` hosting the Feed button, `_FeedingIndicator`, and `_FeedResponse`. `CreatureView` is used only in `home_screen.dart:50`.

**The `loveDecayMod` incoherence (the design problem this slice resolves):** `CreaturePersonality` rolls `loveDecayMod` and `loveRegenMod` independently at hatch (`creature_service.dart:50-62`). FR-005's introvert/extravert behaviour is a *single* axis, but two independent rolls can't represent one axis (a creature could roll "introvert decay" + "extravert regen"). Resolution (user decision): make `loveRegenMod` the sole love-personality dial and **remove `loveDecayMod`**. `loveDecayMod` is currently inert (set at hatch, read nowhere except the prompt summary; S-07 decay isn't built). Touch-points: `creature_personality.spy.yaml:17`, `creature_service.dart:24,57`, `creature_endpoint.dart:68`, `creature_prompt.dart:80`, plus 4 test fixtures (`feed_service_test.dart:38`, `creature_prompt_test.dart:15`, `feed_endpoint_test.dart:80`, `creature_service_test.dart:154`).

## Desired End State

A signed-in user on `/` sees **Feed** and **Pet** buttons on their creature. Pressing **Pet** shows a continuous "Petting…" animation, then within ~5s renders an in-character response coloured by the creature's sociability. Love rises by a personality-scaled amount (extravert more, introvert less), energy falls (introvert more), both clamped to 0–100; the journal gains one coherent `pet` entry with prose + the actual `StatDelta`. A fully-loved creature (love=100) is still petted — love holds at 100, energy still costs, a journal entry is still written, and the model still responds. A flaky/unreachable model degrades gracefully (stats still change, canned in-character copy is produced) rather than hard-failing. Feed and Pet share one response area showing whichever ran most recently.

**Verification:** `serverpod generate` produces `client.creature.pet()` returning `PetResult`; hermetic unit tests pin the love/energy magnitudes and their monotonic dependence on `loveRegenMod`; `withServerpod` integration tests prove the stat+journal pair, the introvert-vs-extravert magnitude difference, max-love, and the degrade/no-creature/owner-scoping branches; Flutter widget tests (provider overrides) prove the Pet button, loading state, shared response render, and stats refresh. `loveDecayMod` no longer exists in the schema or code.

### Key Discoveries

- `prd.md:39` — randomness is permitted **only** in Feed's accept/refuse gate; **Pet is fully deterministic** (no RNG, no `petServiceFactory` randomness, no full-refusal pool).
- `prd.md:74` (FR-005) — "an introvert responds less to intense petting than an extravert" → the single axis governs love gain (↑ extravert) and energy cost (↑ introvert).
- `journal_event.spy.yaml:7` — `JournalEvent.pet` already present.
- `llm_service.dart:43` — `InteractionRequest` is pre-typed for Pet reuse; `accepted: true`, `tastiness` unused for Pet.
- `creature_endpoint.dart:209-233` — the one-transaction stat-update + journal-insert pattern Pet mirrors.
- `feed_service.dart:159-167` — the `feedServiceFactory` injection seam (lesson #3) Pet copies as `petServiceFactory`.
- Lesson #1 — apply the migration via `serverpod run start`, **not** `--apply-migrations`.
- Lesson #2 — provider-override widget tests; `StateProvider` lives in `package:flutter_riverpod/legacy.dart` (Riverpod 3.x).
- Lesson #3 — inject the impure collaborator (LLM) through one production-default factory seam, never `@visibleForTesting`.
- Lesson #5 — run `dart format .` in both packages before each phase commit (the Format CI gate is `--set-exit-if-changed`).

## What We're NOT Doing

- **No random gate for Pet.** No accept/refuse roll, no `Random` seam, no `tastiness`, no full-refusal line pool — Pet is deterministic (`prd.md:39`).
- **No max-love gate.** A love=100 pet still calls the LLM, still costs energy, still writes a journal entry (love just clamps to 0 delta). Petting a beloved creature is always valid, unlike force-feeding a full one.
- **No FR-007 energy gate** (`energy==0` block + exhausted lines). That is slice **S-06**, which covers Feed *and* Pet. S-04 assumes `energy > 0`; energy clamps at floor 0, so petting an exhausted creature is harmless but not blocked.
- **No new `extraversion` field.** The axis is the *existing* `loveRegenMod`; coherence is achieved by removing `loveDecayMod`, not adding a field.
- **No change to the other stats' personality mods.** Only love unifies to one dial (it *is* the personality axis); hunger/energy/illness keep both decay+regen mods for S-07.
- **No S-07 love-decay logic.** This slice only establishes that `loveRegenMod` is the axis; applying it to decay-over-time is S-07.
- **No token streaming, no patrol e2e, no journal screen** (S-08). Single-block response + loading animation; tests are unit + integration + widget only.
- **No change to the LLM client, selection seam, or secret wiring.** Reused as-is.

## Implementation Approach

Build bottom-up, mirroring S-03 so each layer is testable before the next depends on it. Phase 1 first unifies the personality axis (a self-contained schema cleanup with its own green-bar verification) so every later layer reads a model with one love dial. Phase 2 adds the pure pet math + the pet branches of the (existing) prompt builder and stub, with hermetic unit tests. Phase 3 composes them in the `pet` endpoint with `PetResult` + graceful degradation, regenerates the client, and proves behaviour with `withServerpod` integration tests. Phase 4 wires the Flutter `PetController` + the shared two-interaction UI with provider-override widget tests.

The LLM is injected through one production-default seam (`petServiceFactory`, lesson #3) so the degrade path and stub are testable without a live model; there is **no** randomness seam because Pet has no random behaviour.

## Critical Implementation Details

- **Pet is deterministic — no RNG anywhere.** The only impure collaborator is the LLM. `PetService` wraps just the model call + degrade; `petServiceFactory(session)` is the single injection seam. Do not add a `Random` seam.
- **The extraversion axis is `loveRegenMod` (range `[0.5, 1.5)`).** Love gain rises with it; energy cost falls with it. After this slice, `loveDecayMod` no longer exists — S-07 must derive love decay from `loveRegenMod` too (extravert decays faster), keeping one coherent axis.
- **Coherent-pair atomicity (mirrors Feed).** The LLM call happens *before* the `session.db.transaction`; on LLM failure the canned degrade copy is substituted and the transaction still commits, so a stat change never lands without its journal entry. Pet **always** updates the creature (energy always changes) and always writes one `pet` entry.
- **Shared response area needs a tiny coordination seam.** `FeedResult` and `PetResult` are different types; the shared UI renders a common `({String userResponse, bool accepted})`. A `lastInteractionProvider` holds the most-recent outcome; both controllers write to it on success (Feed passes its `accepted`; Pet passes `true`). The view reads it for the response box and reads each controller for loading/error.

## Phase 1: Unify the love personality axis (remove `loveDecayMod`)

### Overview

Make `loveRegenMod` the single introvert↔extravert dial by removing the redundant `loveDecayMod` field and every reference, then regenerate + migrate. Self-contained refactor; existing behaviour (hatch, feed) is otherwise unchanged.

> **Read first:** `.claude/skills/serverpod-models/SKILL.md` (field removal), `.claude/skills/serverpod-cli/SKILL.md` (`serverpod generate`, `create-migration`), `.claude/skills/serverpod-database/SKILL.md` (migrations). Lesson #1: apply via `serverpod run start`, never `--apply-migrations`.

### Changes Required

#### 1. Remove the field from the model

**File**: `tamagotchi_server/lib/src/creature/creature_personality.spy.yaml`

**Intent**: Drop `loveDecayMod` so love has one personality dial.

**Contract**: Remove the `loveDecayMod: double` field (line 17). Update the file's header comment noting love is now a single-dial axis (introvert↔extravert via `loveRegenMod`) while other stats keep decay+regen.

#### 2. Remove from the hatch roll

**File**: `tamagotchi_server/lib/src/creature/creature_service.dart`

**Intent**: Stop rolling/returning the removed modifier.

**Contract**: Remove `loveDecayMod` from the `PersonalityModifiers` typedef (`:24`) and from the record returned by `randomPersonalityModifiers` (`:57`). The remaining seven mods are unchanged.

#### 3. Remove from the hatch endpoint

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Stop persisting the removed field.

**Contract**: Remove the `loveDecayMod: mods.loveDecayMod,` assignment in `hatch()`'s `CreaturePersonality` insert (`:68`).

#### 4. Remove from the prompt summary

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: The personality summary fed to the model now shows love as regen-only.

**Contract**: In `_personalitySummary` (`:80`), change the love line to print only `loveRegenMod` (e.g. `- love (sociability): regen <v>`), so the model reads `loveRegenMod` as the sociability signal. Other stat lines unchanged.

#### 5. Update test fixtures

**File**: `tamagotchi_server/test/unit/feed_service_test.dart`, `tamagotchi_server/test/llm/creature_prompt_test.dart`, `tamagotchi_server/test/integration/feed_endpoint_test.dart`, `tamagotchi_server/test/creature/creature_service_test.dart`

**Intent**: Keep the suite compiling and green after the field removal.

**Contract**: Remove `loveDecayMod:` from the `CreaturePersonality` fixtures (`feed_service_test.dart:38`, `creature_prompt_test.dart:15`, `feed_endpoint_test.dart:80`) and the assertion referencing `mods.loveDecayMod` (`creature_service_test.dart:154`). If `creature_prompt_test.dart` asserts the old love-summary string, update it to the regen-only form.

#### 6. Regenerate + migrate

**File**: generated trees + `tamagotchi_server/migrations/`

**Intent**: Sync the client and drop the column from the schema.

**Contract**: `serverpod generate`, then `serverpod create-migration` (diffs out the `love_decay_mod` column), then apply via `serverpod run start`. Do not hand-edit generated files or the migration.

### Success Criteria

#### Automated Verification

- Server analyzes cleanly: `dart analyze` in `tamagotchi_server/` (excl. generated)
- `serverpod generate` succeeds; `loveDecayMod` is absent from the generated `CreaturePersonality`
- A migration is created that drops `love_decay_mod`; `serverpod run start` applies it cleanly
- Existing server tests still pass: `dart test` (unit + integration) in `tamagotchi_server/`
- `dart format --set-exit-if-changed .` passes in `tamagotchi_server/`

#### Manual Verification

- Hatch a creature and confirm it still persists + renders (seven personality mods, no `loveDecayMod`)
- Confirm no stray `loveDecayMod` reference remains: `grep -rn loveDecayMod` (excl. generated) returns nothing

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Pet domain math + pet LLM surface + hermetic unit tests

### Overview

Add the pure, deterministic pet math (love gain + energy cost derived from `loveRegenMod`), the `PetService` degrade wrapper + `petServiceFactory` seam, and the pet branches of the existing prompt builder and stub, plus the pet copy module. Highest-signal test surface; depends on nothing external.

> **Read first:** the existing `feed_service.dart` (mirror its style — pure functions, derived modifiers, one factory seam) and `creature_prompt.dart` / `stub_llm_service.dart` / `feed_copy.dart` (the surfaces growing a pet branch). Lesson #3 (one production-default factory seam).

### Changes Required

#### 1. Pet math + service

**File**: `tamagotchi_server/lib/src/creature/pet_service.dart` (new)

**Intent**: Encode the deterministic pet rules as small pure functions plus the LLM degrade wrapper behind one seam.

**Contract**:
- `const basePetLove = 15; const basePetEnergy = 4;` (tunable magnitudes).
- `int petLoveGain(double loveRegenMod) => (basePetLove * loveRegenMod).round();` — range ≈ 8 (introvert, `0.5`) → 22 (extravert, `~1.5`); monotonic ↑.
- `int petEnergyCost(double loveRegenMod) => (basePetEnergy * (2 - loveRegenMod)).round();` — range ≈ 6 (introvert) → 2 (extravert); monotonic ↓ (introvert pays more).
- `StatDelta petDelta(Creature c, CreaturePersonality p)` → `loveDelta = clampStat(c.love + petLoveGain(p.loveRegenMod)) - c.love`, `energyDelta = clampStat(c.energy - petEnergyCost(p.loveRegenMod)) - c.energy`, `hungerDelta: 0`, `illnessDelta: 0`. (Delta encodes the clamp so adding it lands the clamped target.)
- `class PetService { PetService({required LlmService llm}); Future<({String userResponse, String journalNarrative})> interaction(Session session, InteractionRequest request); }` — calls `_llm.generateInteraction`; on throw, `session.log(... warning)` and return `(degradeUserResponse, degradeJournalNarrative)` from `pet_copy.dart`. Mirrors `FeedService.interaction` (`feed_service.dart:134-152`) minus the rng/decide/fullRefusalLine members.
- `PetService petServiceFor(Session session) => PetService(llm: llmServiceFor(session));` and the seam `PetService Function(Session) petServiceFactory = petServiceFor;` (lesson #3 — default *is* production; tests reassign).

#### 2. Hoist `clampStat` to the shared domain module

**File**: `tamagotchi_server/lib/src/creature/creature_service.dart` (+ `feed_service.dart`)

**Intent**: `clampStat` is now shared by Feed and Pet — move it to the shared pure-domain home.

**Contract**: Move `int clampStat(int v) => v.clamp(0, 100);` from `feed_service.dart:15` into `creature_service.dart`; `feed_service.dart` and `pet_service.dart` reference it from there. No behaviour change.

#### 3. Pet prompt branch

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: Produce a pet-flavoured `messages` array when `interactionType == JournalEvent.pet`, leaving the feed path intact.

**Contract**: Branch `buildInteractionMessages` on `req.interactionType`. The pet system prompt keeps the same in-character/no-chatbot guardrails but is about *being petted* (no food, no tastiness): it instructs the creature to react to affection coloured by its **sociability** — an extravert (high `loveRegenMod`) basks in and craves the attention; an introvert (low) enjoys it more quietly and finds it a little tiring. Two output fields unchanged (`userResponse`, `journalNarrative`). The pet user message carries stats, mood, the personality summary, and the recent-memory window; it does **not** reference `tastiness` or `accepted`.

#### 4. Pet copy module

**File**: `tamagotchi_server/lib/src/llm/pet_copy.dart` (new)

**Intent**: Non-LLM copy for Pet — the degrade fallback and the stub's deterministic strings. No full-refusal pool (Pet never refuses).

**Contract**: `const String degradeUserResponse` / `degradeJournalNarrative` (LLM-failure fallback, pet-flavoured, in-character) and `const String stubUserResponse` / `stubJournalNarrative` (the stub's pet strings, distinct from feed's so tests can tell paths apart). All non-empty.

#### 5. Stub pet branch

**File**: `tamagotchi_server/lib/src/llm/stub_llm_service.dart`

**Intent**: Return pet copy for pet interactions so key-less/integration tests assert pet-specific text.

**Contract**: Branch `generateInteraction` on `request.interactionType` first: `pet` → the `pet_copy.dart` stub strings; otherwise the existing feed accept/refuse branch. Never throws.

#### 6. Unit tests

**File**: `tamagotchi_server/test/unit/pet_service_test.dart` (new) + extend `tamagotchi_server/test/llm/creature_prompt_test.dart`

**Intent**: Assert the pet oracle against FR-005/domain values and the pet prompt content.

**Contract**: Pet math: `petLoveGain` at `loveRegenMod` 0.5 → 8, ~1.0 → 15, ~1.49 → 22 (extravert > introvert); `petEnergyCost` introvert > extravert; `petDelta` clamps love at 100 (zero `loveDelta` at love=100) and energy at 0; `hungerDelta == 0 && illnessDelta == 0`. Prompt: pet branch includes the persona/guardrails, the sociability framing, stats, mood, and memory, and contains **no** food/tastiness wording. `pet_copy` invariants: all four strings non-empty and distinct from feed's stub strings.

### Success Criteria

#### Automated Verification

- Unit tests pass: `dart test test/unit/pet_service_test.dart test/llm/creature_prompt_test.dart` in `tamagotchi_server/`
- `dart analyze` clean (excl. generated)
- `dart format --set-exit-if-changed .` passes in `tamagotchi_server/`

#### Manual Verification

- Eyeball a few `loveRegenMod` values and confirm `petLoveGain`/`petEnergyCost` match intuition (extravert: more love, less energy spent; introvert: the inverse)

**Implementation Note**: Pause for manual confirmation before Phase 3.

---

## Phase 3: Pet endpoint + PetResult + PetError + journal pair + integration tests

### Overview

Add the `PetResult` model, the `CreaturePetError`, and the `pet` endpoint composing Phases 1–2 into one transaction with graceful degradation; regenerate the client; prove behaviour with `withServerpod` integration tests (real DB, stubbed LLM).

> **Read first:** `.claude/skills/serverpod-endpoints/SKILL.md`, `.claude/skills/serverpod-models/SKILL.md`, `.claude/skills/serverpod-database/SKILL.md`, `.claude/skills/serverpod-testing/SKILL.md` (`withServerpod`, `sessionBuilder.copyWith` auth, rollback). Bring up Postgres: `docker compose up -d` in `tamagotchi_server/`. Mirror `feed()` (`creature_endpoint.dart:140-240`) and `feed_endpoint_test.dart`.

### Changes Required

#### 1. PetResult model

**File**: `tamagotchi_server/lib/src/creature/pet_result.spy.yaml` (new, non-table)

**Intent**: Carry the pet outcome to the client without a second fetch.

**Contract**: `class: PetResult` with `userResponse: String` and `status: CreatureStatus`. **No `accepted` field** — Pet always succeeds (the shared UI supplies `accepted: true` for Pet). No `table:`.

#### 2. Typed pet error

**File**: `tamagotchi_server/lib/src/creature/creature_pet_error.spy.yaml` + `creature_pet_error_reason.spy.yaml` (new)

**Intent**: Surface the only genuine error path (petting with no creature), mirroring `CreatureFeedError` for client-switch parity.

**Contract**: `exception: CreaturePetError { reason: CreaturePetErrorReason }` with a single reason `noCreature`. Behind the UI this never fires.

#### 3. Pet endpoint

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Compose the deterministic delta, the LLM call, and the journal-pair write behind `requireLogin`, owner-scoped.

**Contract**: `Future<PetResult> pet(Session session)`:
1. Resolve `ownerUuid`; load the owner's `Creature` (throw `CreaturePetError(noCreature)` if none); load its `CreaturePersonality` (`StateError` if absent — data-integrity bug, as in `feed`).
2. `final delta = petDelta(creature, personality);` (deterministic; no rng).
3. Fetch the last-10 journal entries (same query as `feed`, `creature_endpoint.dart:178-188`), map to non-empty prose.
4. Build `InteractionRequest(interactionType: JournalEvent.pet, accepted: true, tastiness: 0, ...stats/mood/personality/recentEntries)`; call `petServiceFactory(session).interaction(...)` (degrades to `pet_copy` on failure).
5. In one `session.db.transaction`: update the creature by `delta` (always — energy always changes) and insert `JournalEntry(event: JournalEvent.pet, prose: journalNarrative, statDelta: delta)`.
6. Return `PetResult(userResponse, status: CreatureStatus(creature: updated, mood: deriveMood(...)))`.

#### 4. Regenerate client

**File**: generated trees

**Intent**: Expose `client.creature.pet()` + `PetResult`/`CreaturePetError`.

**Contract**: `serverpod generate` in `tamagotchi_server/`. No migration expected (all new types are non-table). Do not hand-edit generated files; if a spurious migration is emitted, do not apply it.

#### 5. Integration tests

**File**: `tamagotchi_server/test/integration/pet_endpoint_test.dart` (new)

**Intent**: Prove the composed behaviour end-to-end against a real DB with the LLM stubbed.

**Contract**: Reassign `petServiceFactory` → a `PetService` with the `StubLlmService` (and, in one case, a throwing stub), `addTearDown` restoring `petServiceFor` (mirror `feed_endpoint_test.dart:25-39`). Authenticated `sessionBuilder.copyWith(...)`. Cases:
- Accepted pet: love +`petLoveGain` / energy −`petEnergyCost` (clamped), hunger/illness unchanged, exactly **one** `pet` journal entry with the matching `StatDelta` + non-empty prose, mood re-derived.
- Introvert vs extravert: a low-`loveRegenMod` creature gains less love and loses more energy than a high-`loveRegenMod` creature (assert the FR-005 modifier direction).
- Max-love (`love == 100`): `loveDelta == 0`, energy still costs, a `pet` entry **is** written, the LLM **is** called (no gate).
- Degrade (stub throws): stats still change, a `pet` entry with the degrade prose is written, `pet()` does not throw.
- No creature: `pet()` throws `CreaturePetError(noCreature)`.
- Owner-scoping: a second user's `pet()` never touches the first user's creature.

### Success Criteria

#### Automated Verification

- `serverpod generate` succeeds; `client.creature.pet()`, `PetResult`, `CreaturePetError` exist in the generated client
- Integration tests pass: `docker compose up -d` then `dart test test/integration/pet_endpoint_test.dart` in `tamagotchi_server/` (with `SERVERPOD_PASSWORD_database` for the test container)
- Full server suite stays green: `dart test` in `tamagotchi_server/`
- `dart analyze` clean (excl. generated); `dart format --set-exit-if-changed .` passes

#### Manual Verification

- With a dev `mistralApiKey`, call `pet` via the running server and confirm a real, in-character response coloured by sociability + a coherent journal entry
- Pet an extravert and an introvert creature and confirm the love/energy magnitudes differ in the expected direction

**Implementation Note**: Pause for manual confirmation before Phase 4.

---

## Phase 4: Flutter wiring + widget tests

### Overview

Add the `PetController`, a shared `lastInteractionProvider`, the Pet button + shared loading/response UI on `CreatureView` (generalising the existing Feed response widget), and provider-override widget tests. Stats refresh via the existing `ref.invalidate(creatureProvider)` idiom.

> **Read first:** `.claude/skills/riverpod-providers/SKILL.md`, `.claude/skills/riverpod-codegen-and-hooks/SKILL.md`, `.claude/skills/riverpod-consumers/SKILL.md`, `.claude/skills/riverpod-refs/SKILL.md`, `.claude/skills/riverpod-testing/SKILL.md` + `.claude/skills/riverpod-overrides/SKILL.md`, `.claude/skills/riverpod-3-0-migration/SKILL.md` (`StateProvider` in `package:flutter_riverpod/legacy.dart`), `.claude/skills/flutter-add-widget-test/SKILL.md`, `.claude/skills/flutter-fix-layout-issues/SKILL.md`. Mirror `feed_controller.dart` + `creature_view.dart`; follow lesson #2.

### Changes Required

#### 1. Pet controller

**File**: `tamagotchi_flutter/lib/creature/pet_controller.dart` (new)

**Intent**: Drive the Pet button idle → loading → result and refresh the creature.

**Contract**: `@riverpod class PetController extends _$PetController { FutureOr<PetResult?> build() => null; Future<void> pet() async { state = const AsyncLoading(); state = await AsyncValue.guard(() async { final r = await ref.read(serverpodClientProvider).creature.pet(); ref.invalidate(creatureProvider); ref.read(lastInteractionProvider.notifier).set(userResponse: r.userResponse, accepted: true); return r; }); } }`. Run `dart run build_runner build` for the `.g.dart`. Mirror `feed_controller.dart`.

#### 2. Shared last-interaction seam

**File**: `tamagotchi_flutter/lib/creature/last_interaction.dart` (new)

**Intent**: Hold the most-recent interaction outcome so Feed and Pet share one response area.

**Contract**: A small `@riverpod` notifier (or `NotifierProvider`) `lastInteractionProvider` holding `InteractionOutcome?` where `InteractionOutcome = ({String userResponse, bool accepted})`, with a `set({required String userResponse, required bool accepted})` method. Feed's controller writes it on success (passing `result.accepted`); Pet's writes it (`accepted: true`).

#### 3. Feed controller writes the shared seam

**File**: `tamagotchi_flutter/lib/creature/feed_controller.dart`

**Intent**: Route Feed's outcome through the shared area too.

**Contract**: After a successful `feed()`, call `ref.read(lastInteractionProvider.notifier).set(userResponse: result.userResponse, accepted: result.accepted)`. No other change.

#### 4. Pet button + shared response UI

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`

**Intent**: Host both interactions; render the most-recent response in one shared area; show continuous progress during either wait.

**Contract**: Watch `feedControllerProvider`, `petControllerProvider`, and `lastInteractionProvider`. Replace the single Feed button with a Row of **Feed** + **Pet** buttons (`Key('feedButton')`, `Key('petButton')`). While *either* controller `isLoading`, replace the Row with the active indicator (the existing `_FeedingIndicator` generalised to a labelled indicator — "Feeding…" / "Petting…", `Key('feedingIndicator')` / `Key('pettingIndicator')`). Generalise `_FeedResponse` → `_InteractionResponse` taking `({String userResponse, bool accepted})` from `lastInteractionProvider` (accepted → `primaryContainer`; not-accepted → muted/italic, for Feed refusals; Pet is always accepted → normal styling), `Key('interactionResponse')`. Show the generic error line if *either* controller `hasError`. Keep the four `_StatRow`s.

#### 5. Widget tests

**File**: `tamagotchi_flutter/test/creature/creature_view_test.dart` (extend) + a `_FakePetController`

**Intent**: Prove the two-interaction UI without a server.

**Contract**: Override `creatureProvider` with canned `AsyncValue`s, `petControllerProvider.overrideWith(_FakePetController.new)` (the fake flips a `StateProvider` seam + writes `lastInteractionProvider` instead of calling the server, mirroring `_FakeFeedController`), and seed `lastInteractionProvider` where needed. Assert: both Feed and Pet buttons render for a present creature; tapping Pet calls the controller; the petting indicator shows after a single `pump()` (loading via a never-completing future); a pet response renders in the shared `interactionResponse` area; a subsequent feed response replaces it (most-recent wins); updated stats render after the (fake) refresh; the existing Feed-refusal styling still holds.

### Success Criteria

#### Automated Verification

- `dart run build_runner build` succeeds (pet controller + last-interaction `.g.dart` generated)
- Widget tests pass: `flutter test test/creature/creature_view_test.dart` in `tamagotchi_flutter/`
- `flutter analyze` clean; `dart format --set-exit-if-changed .` passes in `tamagotchi_flutter/`
- `serverpod run flutter_build` (in `tamagotchi_server/`) builds the web app without error

#### Manual Verification

- In the running web app, Pet shows a continuous "Petting…" animation then the in-character response within ~5s; love + energy update; the journal reflects the entry
- Feed and Pet share one response area (the most-recent interaction shows); switching between them swaps the response cleanly
- An extravert visibly gains more love (and spends less energy) per pet than an introvert
- No `RenderFlex`/overflow when a long AI response renders, with two buttons in the Row

**Implementation Note**: Final phase — pause for manual confirmation; the demo (a personality-distinct pet response + journal entry) is the acceptance bar.

---

## Testing Strategy

### Unit Tests (hermetic, Phase 2)
- Pet math: love gain (8→22, extravert > introvert), energy cost (introvert > extravert), clamping (love at 100, energy at 0), zero hunger/illness deltas.
- Prompt builder pet branch content; `pet_copy` invariants.

### Integration Tests (`withServerpod`, real DB, stubbed LLM, Phase 3)
- Accepted pet stat+journal pair; introvert-vs-extravert magnitude direction; max-love (zero love delta, energy still costs, entry written, LLM called); degrade path; no-creature error; owner-scoping.

### Widget Tests (provider overrides, Phase 4)
- Both buttons render; tap-calls-controller; petting loading animation; shared response render + most-recent-wins; stats refresh; Feed-refusal styling preserved.

### Manual Testing Steps
1. With a dev key, hatch then Pet; confirm an in-character, sociability-coloured response + coherent journal entry within ~5s.
2. Pet repeatedly toward love=100; confirm it keeps responding (no gate) and love holds at 100 while energy drains.
3. Compare an extravert and an introvert creature; confirm the love/energy magnitudes differ as expected.
4. Temporarily set an invalid key; confirm the degrade path (stats change, canned line, no crash).

## Performance Considerations

One external call per pet on the hot path; `mistral-small-2603` is low-latency and cheap, well within NFR-1's 5s with a loading animation. Last-10 prose entries bound prompt size. No full-love gate means a love=100 pet still calls the model — negligible cost, and the response keeps the creature feeling alive.

## Migration Notes

One migration this slice: it **drops** the `love_decay_mod` column from `creature_personality`. The column is inert today (set at hatch, read nowhere), so no data logic breaks; existing rows lose an unused value. Apply via `serverpod run start` (lesson #1), never `--apply-migrations`. The Pet models (`PetResult`, `CreaturePetError`) are non-table and add no migration.

## References

- Change brief: `context/changes/pet-with-personality-response/change.md`
- Roadmap S-04: `context/foundation/roadmap.md`; PRD FR-005 (`prd.md:74`), determinism guardrail (`prd.md:39`)
- Feed slice template: `context/changes/feed-with-personality-response/plan.md`
- Feed endpoint to mirror: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:140-240`
- Feed service / factory seam: `tamagotchi_server/lib/src/creature/feed_service.dart:111-167`
- Integration-test pattern: `tamagotchi_server/test/integration/feed_endpoint_test.dart`
- Flutter controller / view: `tamagotchi_flutter/lib/creature/feed_controller.dart`, `creature_view.dart`
- Widget-test pattern + lesson #2: `tamagotchi_flutter/test/creature/creature_view_test.dart`; `context/foundation/lessons.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Unify the love personality axis (remove `loveDecayMod`)

#### Automated
- [x] 1.1 `dart analyze` clean (excl. generated) — 90410bf
- [x] 1.2 `serverpod generate` succeeds; `loveDecayMod` absent from generated `CreaturePersonality` — 90410bf
- [x] 1.3 Migration created dropping `love_decay_mod`; `serverpod run start` applies it cleanly — 90410bf
- [x] 1.4 Existing server tests pass (`dart test`, unit + integration) — 90410bf
- [x] 1.5 `dart format --set-exit-if-changed .` passes in `tamagotchi_server/` — 90410bf

#### Manual
- [x] 1.6 Hatch still persists/renders (seven mods, no `loveDecayMod`) — 90410bf
- [x] 1.7 No stray `loveDecayMod` reference remains (grep, excl. generated) — 90410bf

### Phase 2: Pet domain math + pet LLM surface + hermetic unit tests

#### Automated
- [x] 2.1 Unit tests pass (`dart test test/unit/pet_service_test.dart test/llm/creature_prompt_test.dart`) — becb4cf
- [x] 2.2 `dart analyze` clean (excl. generated) — becb4cf
- [x] 2.3 `dart format --set-exit-if-changed .` passes in `tamagotchi_server/` — becb4cf

#### Manual
- [x] 2.4 `petLoveGain`/`petEnergyCost` across `loveRegenMod` values match intuition — becb4cf

### Phase 3: Pet endpoint + PetResult + PetError + journal pair + integration tests

#### Automated
- [x] 3.1 `serverpod generate` succeeds; `client.creature.pet()` + `PetResult` + `CreaturePetError` exist
- [x] 3.2 Integration tests pass (`dart test test/integration/pet_endpoint_test.dart`)
- [x] 3.3 Full server suite green (`dart test`)
- [x] 3.4 `dart analyze` clean (excl. generated); `dart format --set-exit-if-changed .` passes

#### Manual
- [ ] 3.5 Real `pet` call returns an in-character, sociability-coloured response + coherent journal entry
- [ ] 3.6 Extravert vs introvert love/energy magnitudes differ in the expected direction

### Phase 4: Flutter wiring + widget tests

#### Automated
- [ ] 4.1 `build_runner build` succeeds (pet controller + last-interaction `.g.dart`)
- [ ] 4.2 Widget tests pass (`flutter test test/creature/creature_view_test.dart`)
- [ ] 4.3 `flutter analyze` clean; `dart format --set-exit-if-changed .` passes in `tamagotchi_flutter/`
- [ ] 4.4 `serverpod run flutter_build` builds the web app

#### Manual
- [ ] 4.5 Pet shows loading animation then response within ~5s; love + energy + journal update
- [ ] 4.6 Feed and Pet share one response area (most-recent wins); swaps cleanly
- [ ] 4.7 Extravert gains more love / spends less energy per pet than an introvert
- [ ] 4.8 No overflow when a long response renders with two buttons in the Row
