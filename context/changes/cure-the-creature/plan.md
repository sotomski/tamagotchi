# Cure the Creature (S-05) Implementation Plan

## Overview

Add **Cure** as the third creature interaction, alongside Feed (S-03) and Pet (the deterministic `play()` endpoint, S-04). The user taps **Cure**, the creature's illness drops by a deterministic amount scaled by its personality, the creature returns an in-character LLM response acknowledging the cure, and a `cure` journal entry is written in the same transaction. Per FR-006, Cure is **always available regardless of energy** and costs **no energy**.

This slice mirrors the Pet template almost exactly: fully deterministic stat math (no RNG seam), one service behind a `cureServiceFactory` seam, reuse of 100% of the existing LLM surface. It adds a `cure` branch to the prompt builder + stub, a `CureService`, a `cure()` endpoint, and a Flutter Cure button.

## Current State Analysis

What already exists (verified):

- **Interaction enum is ready.** `JournalEvent` already contains `cure` (`tamagotchi_server/lib/src/creature/journal_event.spy.yaml`). No enum change, **no schema migration, and no data migration** are required for this slice.
- **LLM surface is generic and reusable.** `LlmService` / `MistralLlmService` / `StubLlmService` (`tamagotchi_server/lib/src/llm/`) take a single `InteractionRequest` whose `interactionType` is a `JournalEvent` and already carries `illness`. The prompt builder `buildInteractionMessages` (`creature_prompt.dart:12`) currently branches feed-vs-play; the stub branches the same way. Cure adds a third branch in both.
- **Stat math + helpers are established.** `creature_service.dart` holds `baselineCreatureStats` (`:14`, `illness: 0`), `deriveMood` (`:44`, `illness >= 50 → sick`), `randomPersonalityModifiers`, and the hoisted `clampStat`. Personality carries `illnessDecayMod` and `illnessRegenMod` (`creature_personality.spy.yaml`), neither used yet.
- **Pet is the closest prior art.** `play_service.dart` computes a deterministic `StatDelta` via `playDelta(creature, personality)` (love scaled by `loveRegenMod`, energy cost, no RNG); the `play()` endpoint (`creature_endpoint.dart` ~`:254–339`) fetches creature+personality, pulls the last-10 journal window, calls `playServiceFactory(session).interaction(...)`, and commits stat update + journal insert in one transaction with degrade-on-LLM-failure. `PlayResult` (`{userResponse, status}`) and `CreaturePlayError{noCreature}` are non-table models.
- **Frontend coordination already supports a third interaction.** `creature_view.dart` renders Feed/Play buttons in one Row (`:72–91`), shows illness already (`:57`), and routes every interaction's response through the shared `lastInteractionProvider` + `_InteractionResponse` widget. `play_controller.dart` is the controller template (`AsyncNotifier`, `AsyncValue.guard`, `invalidate(creatureProvider)`, write to `lastInteractionProvider`).
- **Energy gate (FR-007) does not exist yet.** It is S-06. Nothing currently blocks any interaction at zero energy.

### Key Discoveries:

- `JournalEvent.cure` already defined — `journal_event.spy.yaml`; serialized by name, additive (no migration). See [[reference_serverpod_enum_byname_data_migration]].
- `baselineCreatureStats = (hunger: 0, energy: 100, love: 50, illness: 0)` — `creature_service.dart:14`. Illness stays 0 at hatch (decision below).
- Mood threshold `illness >= 50 → sick` — `creature_service.dart:44`. Relevant only when illness is seeded/decayed; not changed here.
- Pet endpoint + transaction shape — `creature_endpoint.dart` ~`:254–339`; the exact pattern `cure()` copies.
- Injection seam rule (one plain factory, never `@visibleForTesting`) — `context/foundation/lessons.md:24–29`.
- Widget-test-with-overrides rule (Riverpod 3.x; `Completer().future` for loading; `pump()` not `pumpAndSettle()`) — `context/foundation/lessons.md:12–22`.
- `dart format` before every phase commit (separate CI gate from analyze) — `context/foundation/lessons.md:50–55`.

## Desired End State

A signed-in user with a creature that has `illness > 0` sees an enabled **Cure** button. Tapping it reduces illness (deterministically, scaled by `illnessDecayMod`), leaves energy untouched, shows an in-character response in the shared response area, persists a `cure` journal entry, and refreshes the displayed stats. When `illness == 0` the Cure button is disabled. The server applies the cure with **no energy precondition**.

Verify: integration test cures a seeded sick creature and asserts illness dropped + journal entry written; widget test asserts the button is disabled at `illness == 0` and enabled + functional at `illness > 0`; `cure()` works at `energy == 0`.

## What We're NOT Doing

- **Not** bootstrapping illness at hatch — `baselineCreatureStats` stays `illness: 0` (decision). A freshly-hatched creature shows Cure **disabled** until illness rises via S-07 decay or is seeded in tests/fixtures. This is an accepted, documented limitation of this slice.
- **Not** building the FR-007 empty-energy gate (that is S-06). We only ensure Cure carries no energy precondition and leave an invariant note for S-06.
- **Not** charging energy for Cure (`energyDelta` is always 0).
- **Not** adding randomness — Cure is fully deterministic (PRD guardrail `prd.md:39` reserves randomness for Feed's accept/refuse gate only).
- **Not** changing the LLM client, the selection seam, or any migration/schema. No `create-migration` step.
- **Not** adding a new Cure-specific e2e/patrol test — the existing Feed persistence e2e covers the transaction/persistence boundary generically.
- **Not** restyling Cure as a visually distinct action — it joins the existing button Row with consistent styling (plus a healing icon).

## Implementation Approach

Bottom-up, same as Pet: pure domain logic + LLM branch first (Phase 1, TDD), then the endpoint + models + integration tests (Phase 2), then the Flutter controller + button + widget tests (Phase 3). Cure reuses the LLM surface untouched — it only adds a `cure` branch to the prompt builder and the stub. Stat math is a deterministic `cureDelta(creature, personality)` returning a `StatDelta` with only `illnessDelta` non-zero (energy/hunger/love all 0).

**Workflow per phase:** Phase 1 → `/10x-tdd` (pure functions, clear contract, hermetic). Phases 2 and 3 → `/10x-implement` (each gated by codegen — `serverpod generate` / `riverpod_generator` — that must run before test code compiles, so test-first is impractical; tests are written alongside).

## Critical Implementation Details

- **No energy precondition on `cure()`.** Unlike the eventual Feed/Pet gate (S-06), `cure()` must never read energy as a guard. Leave a one-line comment at the top of the endpoint naming the FR-006/S-06 invariant so S-06 explicitly exempts Cure when it adds the gate.
- **Server processes `illness == 0` gracefully.** The disabled-button rule is a **client-side UX guard only**. The endpoint stays free of any illness precondition: at `illness == 0` it computes `illnessDelta == 0` and still calls the LLM + writes the journal entry (mirrors Play's max-love behavior). An integration test pins this so the server never depends on the client guard.
- **`cureServiceFactory` is a plain seam.** Default is production wiring (`cureServiceFor(session)`); tests reassign it and restore via `addTearDown` — never `@visibleForTesting` (lessons.md:24–29).

## Phase 1: Server domain + LLM cure branch  →  `/10x-tdd`

### Overview

Add the deterministic cure math, the canned-copy module, and the `cure` branches in the prompt builder and stub. Pure, hermetic, no DB. Drive it test-first.

### Changes Required:

#### 1. Cure domain service

**File**: `tamagotchi_server/lib/src/creature/cure_service.dart` (new)

**Intent**: Compute the deterministic stat change for a cure and wrap the LLM call with degrade-on-failure, mirroring `play_service.dart`. Illness drops by a base relief scaled by the creature's `illnessDecayMod` (recovery responsiveness); energy/hunger/love untouched.

**Contract**:
- A module constant for the base relief (mirror naming of `basePlayLove`/`feedHungerDrop`), recommended ~`40`, scaled by `illnessDecayMod ∈ [0.5, 1.5)` → relief ~20–60.
- `cureDelta(Creature c, CreaturePersonality p) → StatDelta` where `illnessDelta = clampStat(c.illness - round(baseCureRelief * p.illnessDecayMod)) - c.illness` (≤ 0), and `energyDelta = hungerDelta = loveDelta = 0`.
- A `CureService` class + `CureService cureServiceFor(Session)` factory and a reassignable `cureServiceFactory` seam, matching `play_service.dart`'s `playServiceFactory` shape exactly. The service's `interaction(...)` builds an `InteractionRequest` with `interactionType: JournalEvent.cure`, `accepted: true`, `tastiness: 0`, calls the injected `LlmService`, and degrades to `cure_copy` strings on failure.

#### 2. Cure canned copy

**File**: `tamagotchi_server/lib/src/llm/cure_copy.dart` (new)

**Intent**: Hold the non-LLM strings for Cure — degrade fallback (used when the model errors) and deterministic stub strings (used by the keyless stub in tests). Mirror `play_copy.dart`.

**Contract**: `degradeUserResponse`, `degradeJournalNarrative`, `stubUserResponse`, `stubJournalNarrative` — all referencing recovery/relief, not food or play.

#### 3. Prompt builder cure branch

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: Add a third branch so a `cure` interaction gets a cure-appropriate system + user prompt. The creature reacts to feeling better; tone colored by personality (sociability axis as Pet uses it, plus the illness mods are already surfaced in the personality summary). Do not reference hunger/tastiness/food.

**Contract**: `buildInteractionMessages` selects a `_cureSystemPrompt` / `_cureUserPrompt(req)` when `req.interactionType == JournalEvent.cure`. The user prompt includes illness, mood, and the personality summary; omits the feed-only `Accepted`/`Tastiness` lines (like the play user prompt). Output contract unchanged: JSON `{userResponse, journalNarrative}`.

#### 4. Stub cure branch

**File**: `tamagotchi_server/lib/src/llm/stub_llm_service.dart`

**Intent**: Return deterministic cure strings when `interactionType == JournalEvent.cure`, so integration/widget tests are hermetic.

**Contract**: Add a `cure` case returning `cure_copy.stubUserResponse` / `stubJournalNarrative`.

#### 5. Unit tests

**File**: `tamagotchi_server/test/unit/cure_service_test.dart` (new); extend `tamagotchi_server/test/llm/creature_prompt_test.dart`

**Intent**: Drive Phase 1 test-first. Cover the cure math contract and the prompt branch selection.

**Contract**: Tests assert `cureDelta` direction (illnessDelta ≤ 0), personality scaling (higher `illnessDecayMod` → larger relief), clamping at illness floor 0 (and `illnessDelta == 0` when `illness == 0`), and that hunger/energy/love deltas are 0. Prompt test asserts a `cure` request yields the cure system/user messages (no Accepted/Tastiness lines).

### Success Criteria:

#### Automated Verification:

- Unit tests pass: `dart test test/unit/cure_service_test.dart test/llm/creature_prompt_test.dart` (in `tamagotchi_server/`)
- Analyzer clean: `dart analyze` (in `tamagotchi_server/`)
- Formatting clean: `dart format --set-exit-if-changed .` (in `tamagotchi_server/`)

#### Manual Verification:

- The cure stub/degrade copy and the cure prompt read as recovery-themed and in-character (no food/play language).

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Server endpoint + models  →  `/10x-implement`

### Overview

Add the `CureResult` + error models, the `cure()` endpoint, regenerate the client, and write `withServerpod` integration tests. No migration (no table/schema change).

### Changes Required:

#### 1. Result + error models

**Files**: `tamagotchi_server/lib/src/creature/cure_result.spy.yaml` (new), `tamagotchi_server/lib/src/creature/creature_cure_error.spy.yaml` + `creature_cure_error_reason.spy.yaml` (new)

**Intent**: Mirror `play_result.spy.yaml` and the play error pair. `CureResult` carries the user response + refreshed status (no `accepted` field). The error enum has `noCreature`.

**Contract**: `CureResult { userResponse: String, status: CreatureStatus }` (non-table model). `CreatureCureErrorReason { noCreature }`; `CreatureCureError` wrapping it, matching the play error shape.

#### 2. Cure endpoint

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Add `Future<CureResult> cure(Session session)` mirroring `play()`: fetch the owner's creature (throw `CreatureCureError.noCreature` if absent), fetch personality (fail-loud if missing), compute `cureDelta`, pull the last-10 journal window, call `cureServiceFactory(session).interaction(...)`, and commit stat update + `JournalEvent.cure` journal insert in one transaction with degrade-on-failure. **No energy precondition** — add the FR-006/S-06 invariant comment.

**Contract**: Same signature/return shape as `play()` but returning `CureResult`. Energy is never read as a guard.

#### 3. Regenerate client

**File**: `tamagotchi_client/**` (generated — do not hand-edit)

**Intent**: Expose `client.creature.cure()` and the new models to the Flutter client.

**Contract**: Run `serverpod generate` from `tamagotchi_server/`. No `create-migration` (models are non-table; `JournalEvent.cure` already exists).

#### 4. Integration tests

**File**: `tamagotchi_server/test/integration/cure_endpoint_test.dart` (new)

**Intent**: Mirror `play_endpoint_test.dart`. Seed creatures directly (set `illness`), inject the stub/throwing `LlmService` via `cureServiceFactory`, restore with `addTearDown`.

**Contract**: Cases — (a) sick creature cured: illness drops by `round(baseCureRelief × illnessDecayMod)`, energy/hunger/love unchanged, mood re-derived, exactly one `cure` journal entry with matching `StatDelta`; (b) already-healthy (`illness == 0`): `illnessDelta == 0`, energy unchanged, entry still written, LLM still called; (c) LLM-degrade (throwing stub): stats still apply, canned prose, no throw; (d) no-creature → `CreatureCureError(noCreature)`; (e) owner-scoping; (f) `energy == 0` → cure still succeeds (no energy gate).

### Success Criteria:

#### Automated Verification:

- Client regenerated: `serverpod generate` exits 0 (in `tamagotchi_server/`); `tamagotchi_client` exposes `creature.cure()`
- Integration tests pass: `dart test test/integration/cure_endpoint_test.dart` (in `tamagotchi_server/`, against the compose test Postgres)
- Analyzer clean: `dart analyze` (server + client)
- Formatting clean: `dart format --set-exit-if-changed .` (in `tamagotchi_server/`)

#### Manual Verification:

- With a seeded sick creature, calling `cure()` returns a coherent in-character response and the illness drop feels right relative to personality.
- `cure()` succeeds when the creature's energy is 0.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 3.

---

## Phase 3: Flutter client  →  `/10x-implement`

### Overview

Add the `CureController`, the Cure button (disabled at `illness == 0`), and widget tests. Reuse the shared response/loading plumbing.

### Changes Required:

#### 1. Cure controller

**Files**: `tamagotchi_flutter/lib/creature/cure_controller.dart` (new) + generated `cure_controller.g.dart`

**Intent**: Mirror `play_controller.dart`: an `AsyncNotifier<CureResult?>` whose `cure()` runs the RPC under `AsyncValue.guard`, invalidates `creatureProvider`, and writes the response to `lastInteractionProvider` (`accepted: true`).

**Contract**: `@riverpod class CureController` → `cureControllerProvider`; calls `ref.read(serverpodClientProvider).creature.cure()`. Run `riverpod_generator` (build_runner) for the `.g.dart`.

#### 2. Cure button + disabled state

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`

**Intent**: Add a third `ElevatedButton.icon` (healing icon) in the existing button Row, wired to `cureControllerProvider.notifier.cure()`. Disable it when `creature.illness == 0` (set `onPressed: null`). Fold its loading state into the existing indicator logic, and ensure the in-flight indicator covers cure.

**Contract**: Button key `'cureButton'`; loading indicator key `'curingIndicator'` (label "Curing…"); watch `cureControllerProvider` alongside feed/play for `isLoading`/error. Response renders through the existing `_InteractionResponse` (`'interactionResponse'`). Disabled iff `illness == 0`.

#### 3. Widget tests

**File**: `tamagotchi_flutter/test/creature/creature_view_test.dart` (extend)

**Intent**: Cover the new button per the override pattern (lessons.md:12–22) — fake `CureController`, canned `creatureProvider`/`lastInteractionProvider`.

**Contract**: Tests — (a) Cure disabled when `illness == 0`, not tappable; (b) Cure enabled when `illness > 0`; tap → controller called → response in shared area; (c) cure in flight shows `curingIndicator` (assert after one `pump()`, `Completer().future`); (d) stats refresh after a successful cure (illness drops).

### Success Criteria:

#### Automated Verification:

- Codegen up to date: build_runner produces `cure_controller.g.dart` (in `tamagotchi_flutter/`)
- Widget tests pass: `flutter test test/creature/creature_view_test.dart` (in `tamagotchi_flutter/`)
- Analyzer clean: `flutter analyze` (in `tamagotchi_flutter/`)
- Formatting clean: `dart format --set-exit-if-changed .` (in `tamagotchi_flutter/`)

#### Manual Verification:

- Cure button is greyed out on a fresh creature (`illness == 0`) and enabled once illness is seeded/raised.
- Tapping Cure on a sick creature shows the loading animation, then the in-character response, and the illness stat visibly drops.
- The shared response area shows the most-recent interaction across Feed/Play/Cure.

**Implementation Note**: After automated verification passes, pause for manual confirmation. This completes the slice.

---

## Testing Strategy

### Unit Tests:

- `cureDelta` math: direction (illnessDelta ≤ 0), personality scaling by `illnessDecayMod`, clamp at floor 0, `illnessDelta == 0` at `illness == 0`, zero hunger/energy/love deltas.
- Prompt builder selects the cure branch and omits feed-only fields.

### Integration Tests:

- Endpoint cases (a)–(f) above via `withServerpod`, stub + throwing LLM injected through `cureServiceFactory`, creatures seeded directly with chosen `illness`/personality.

### Manual Testing Steps:

1. Seed (or decay, once S-07 exists) a creature to `illness > 0`; confirm Cure is enabled.
2. Tap Cure; confirm loading indicator → in-character recovery response → illness drops, energy unchanged.
3. Confirm Cure works at `energy == 0`.
4. On a fresh creature (`illness == 0`), confirm Cure is disabled.

## Performance Considerations

None beyond the existing per-interaction LLM call (one network round-trip, degrade-on-failure already established). Cure adds no new hot path.

## Migration Notes

No migration. `JournalEvent.cure` already exists and serializes by name (additive); `CureResult`/`CreatureCureError` are non-table models. Only `serverpod generate` (protocol regen) is needed.

## References

- Change identity: `context/changes/cure-the-creature/change.md`
- Closest prior art (Pet): `context/archive/2026-06-20-pet-with-personality-response/plan.md`
- LLM surface origin (Feed): `context/archive/2026-06-05-feed-with-personality-response/plan.md`
- Lessons: `context/foundation/lessons.md` (#injection-seam, #widget-overrides, #dart-format, #serverpod-run-start)
- PRD: FR-006 (`context/foundation/prd.md:76`), determinism guardrail (`:39`)
- Pet endpoint pattern: `tamagotchi_server/lib/src/creature/creature_endpoint.dart` (~`:254–339`)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Server domain + LLM cure branch

#### Automated

- [x] 1.1 Unit tests pass (`cure_service_test.dart`, `creature_prompt_test.dart`) — 8d98cd2
- [x] 1.2 Analyzer clean (server) — 8d98cd2
- [x] 1.3 Formatting clean (server) — 8d98cd2

#### Manual

- [x] 1.4 Cure copy + prompt read as recovery-themed and in-character — 8d98cd2

### Phase 2: Server endpoint + models

#### Automated

- [x] 2.1 Client regenerated; `creature.cure()` exposed
- [x] 2.2 Integration tests pass (`cure_endpoint_test.dart`)
- [x] 2.3 Analyzer clean (server + client)
- [x] 2.4 Formatting clean (server)

#### Manual

- [ ] 2.5 Seeded sick creature returns coherent in-character cure; illness drop feels right
- [ ] 2.6 `cure()` succeeds at energy 0

### Phase 3: Flutter client

#### Automated

- [ ] 3.1 `cure_controller.g.dart` generated
- [ ] 3.2 Widget tests pass (`creature_view_test.dart`)
- [ ] 3.3 Analyzer clean (flutter)
- [ ] 3.4 Formatting clean (flutter)

#### Manual

- [ ] 3.5 Cure disabled at illness 0, enabled when seeded/raised
- [ ] 3.6 Tap Cure → loading → in-character response → illness drops
- [ ] 3.7 Shared response area shows most-recent interaction across Feed/Play/Cure
