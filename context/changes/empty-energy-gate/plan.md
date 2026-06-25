# Empty Energy Gate (FR-007) Implementation Plan

## Overview

Block Feed and Play when the creature can't afford their energy cost, while keeping Cure always available (FR-006). The server enforces the gate authoritatively and returns one of a small set of pre-written, per-interaction "exhausted" responses (no LLM, no stat change, no journal entry). The Flutter client proactively disables an unaffordable Feed/Play button and shows an "out of energy" hint, and renders the server's exhausted backstop response with distinct styling when a click slips through a stale client state.

This is the "S-06 energy gate" the codebase already anticipates (`creature_endpoint.dart:476-478`).

## Current State Analysis

- **No gate exists.** `feed()` and `play()` spend energy down to 0 via `clampStat` (`feed_service.dart:94`, `play_service.dart:40`); nothing checks affordability first. `cure()` costs 0 energy and must never read energy as a guard (FR-006 invariant, `creature_endpoint.dart:476-478`).
- **Energy reaches 0 only by spending.** Decay *regenerates* energy (`decay_service.dart`); the only downward pressure is interaction cost — Feed `feedEnergyCost = 10` (`feed_service.dart:21`), Play `playEnergyCost(loveRegenMod)` ≈ 2–6 (`play_service.dart:30`). Cure is free.
- **Precedent to mirror: the full-refusal early return** (`creature_endpoint.dart:277-283`). A full creature's Feed returns a canned `fullRefusalLines` pick (`feed_copy.dart:12`) with **no LLM call, no journal entry, no stat change, no persistence** — a plain early `return`. Notably the Feed button is *not* disabled when full; the gate we add is the same shape, keyed on energy.
- **Decay runs before any gate.** `feed()`/`play()` fold decay into `base` first (`creature_endpoint.dart:263-269`, `393-399`); the gate must read `base.energy` (post-decay), because regeneration may have lifted the creature back above the threshold.
- **Client state.** Feed/Play buttons are always enabled; Cure is disabled at `illness == 0` (`creature_view.dart:118`). `FeedResult` carries `accepted` (drives muted/italic refusal styling, `creature_view.dart:221-235`); `PlayResult` has no such flag. The shared `InteractionOutcome` record is `({String userResponse, bool accepted})` (`last_interaction.dart:10`).
- **Cost functions live server-side.** `feedEnergyCost` is a const; `playEnergyCost` is personality-derived (`loveRegenMod`) — the client cannot compute Play affordability on its own, so the server must tell it.
- **The affected result models are non-table** (`CreatureStatus`, `FeedResult`, `PlayResult` have no `table:` key) — adding fields needs codegen but **no database migration**.

## Desired End State

- Feeding a creature with `energy < 10` returns a `FeedResult` with `exhausted: true`, `accepted: false`, a line from `feedExhaustedLines`, the creature unchanged, and **no journal entry** — the LLM is never called.
- Playing with a creature whose `energy < playEnergyCost(loveRegenMod)` returns a `PlayResult` with `exhausted: true`, a line from `playExhaustedLines`, unchanged creature, no journal entry, no LLM call.
- Curing works at any energy, including 0 (unchanged).
- Every `CreatureStatus` carries `canFeed`/`canPlay` booleans reflecting current affordability.
- In the app, an unaffordable Feed/Play button is disabled and an "out of energy" hint is visible; an exhausted response (if the server gate fires) renders with distinct, non-error styling.

Verify: server integration tests for the gate + affordability booleans pass; `serverpod generate` leaves client/server in sync; Flutter widget tests for disabled buttons + hint + exhausted styling pass; manual play-through drains energy and observes the gate.

### Key Discoveries:

- Full-refusal early-return pattern to mirror: `creature_endpoint.dart:277-283`.
- Cure exemption invariant (must not read energy): `creature_endpoint.dart:476-478`.
- Feed cost const `feedEnergyCost = 10`: `feed_service.dart:21`. Play cost fn `playEnergyCost(loveRegenMod)`: `play_service.dart:30-31`.
- RNG line-pick precedent `FeedService.fullRefusalLine()`: `feed_service.dart:124-127`. `PlayService` has **no** RNG today (`play_service.dart:53-55`) — it gains one solely for cosmetic exhausted-line variety.
- All `CreatureStatus` construction sites have personality (hence `loveRegenMod`) in scope: hatch (`:113`, via `mods`), myCreature (`:220`), feed (`:281`, `:351`), play (`:462`), cure (`:583`).
- Client styling seam for non-accepted responses: `creature_view.dart:207-245`; affordability/disable seam: `creature_view.dart:97-126`.

## What We're NOT Doing

- **No database migration** — the three changed models are non-table.
- **No change to interaction costs or the decay/regen rates** — only gating on the existing `energy` value and existing cost functions.
- **No energy gate on Cure** — FR-006 keeps it always available.
- **No LLM-generated or personality-flavored exhausted copy** — exhausted lines are flat, pre-written pools (FR-007).
- **No journal entry for a blocked attempt** — a blocked interaction is a non-event (mirrors full-refusal).
- **No e2e/patrol test in this change** — covered later via `/10x-e2e` if desired.
- **No persistence of decay on the exhausted early-return path** — see Critical Implementation Details.

## Implementation Approach

Backend first (Phase 1): land the model fields + codegen, the per-interaction copy pools and `exhaustedLine()` selectors, a `_statusFor` helper that computes affordability, and the two early-return gates in `feed()`/`play()`. Then the client (Phase 2): regenerated models expose `canFeed`/`canPlay` and `exhausted`, which drive button disabling, the hint, and distinct response styling. Phase 2 depends on Phase 1's codegen.

## Critical Implementation Details

- **Gate reads post-decay `base.energy`, before the feed decision / play delta.** Place the energy check immediately after `final base = decayed.creature;` and before `feedService.decide(...)` / `playDelta(...)`. The exhausted check takes priority over the full-refusal check in `feed()` (a creature too tired to eat shouldn't first be told it's full).
- **Exhausted early-return does not persist decay.** Like the full-refusal path, it is a plain `return` with no transaction. With the `< cost` threshold a decay tick *may* have fired (e.g. energy regenerated 3→5, still `< 10`) leaving `decayed.changed == true`; not persisting is safe because the decay anchor (`lastDecayedAt`) is not advanced, so the same elapsed window is recomputed idempotently on the next poll/interaction — no loss, no double-count. Do **not** add a write here.
- **Play's stat determinism is preserved.** The `Random` added to `PlayService` is used *only* by `exhaustedLine()` to vary cosmetic copy on the blocked path, which never touches stats. `playDelta` remains pure and RNG-free (`prd.md:39`).

## Phase 1: Server — gate, models, copy

### Overview

Add the affordability + exhausted fields to the result models (with codegen), the per-interaction exhausted copy pools and their RNG-backed selectors, a status helper computing affordability, and the two early-return gates. Cure is left untouched. Driver: **`/10x-tdd`** — the gate behavior and affordability booleans are naturally red→green via `serverpod_test` integration tests and pure-function checks; treat the `.spy.yaml` edits + `serverpod generate` as a mechanical prerequisite step done before the first failing test compiles.

### Changes Required:

#### 1. Result/status model fields

**File**: `tamagotchi_server/lib/src/creature/creature_status.spy.yaml`

**Intent**: Expose per-interaction affordability so the client can disable unaffordable buttons without knowing the (personality-derived) costs.

**Contract**: Add two non-nullable bool fields `canFeed` and `canPlay` to `CreatureStatus`. Non-table model — no migration.

**File**: `tamagotchi_server/lib/src/creature/feed_result.spy.yaml`, `tamagotchi_server/lib/src/creature/play_result.spy.yaml`

**Intent**: Distinguish an exhausted (energy-blocked) outcome from a normal/refused one so the client can style it distinctly.

**Contract**: Add a non-nullable bool `exhausted` to both `FeedResult` and `PlayResult`. (`FeedResult` keeps `accepted`; `PlayResult` gains only `exhausted`.)

**Then**: run `serverpod generate` from `tamagotchi_server/` to regenerate `lib/src/generated/` and `../tamagotchi_client/lib/src/protocol/`.

#### 2. Per-interaction exhausted copy pools + selectors

**File**: `tamagotchi_server/lib/src/llm/feed_copy.dart`, `tamagotchi_server/lib/src/llm/play_copy.dart`

**Intent**: Provide the small set of pre-written exhausted responses (FR-007), tailored per interaction.

**Contract**: Add `const List<String> feedExhaustedLines` (~10 food+tired lines) and `const List<String> playExhaustedLines` (~10 play+tired lines), each non-empty, in-character, no chatbot/disclaimer language — mirroring `fullRefusalLines` shape.

**File**: `tamagotchi_server/lib/src/creature/feed_service.dart`

**Intent**: Pick an exhausted line off the same seeded RNG the gate uses (reproducible under seeded tests), mirroring `fullRefusalLine()`.

**Contract**: Add `String exhaustedLine()` returning `feedExhaustedLines[_rng.nextInt(feedExhaustedLines.length)]`.

**File**: `tamagotchi_server/lib/src/creature/play_service.dart`

**Intent**: Give `PlayService` an exhausted-line selector. Play currently has no RNG; add one used *only* for cosmetic line variety.

**Contract**: Add a `Random _rng` constructor field (mirror `FeedService`'s seam); `playServiceFor` supplies `Random()`; add `String exhaustedLine()` returning `playExhaustedLines[_rng.nextInt(playExhaustedLines.length)]`. `playDelta` stays RNG-free.

#### 3. Status helper + gates in the endpoint

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Centralize affordability computation and add the two early-return gates; keep Cure exempt.

**Contract**:
- Add a private helper `CreatureStatus _statusFor(Creature c, double loveRegenMod)` returning `CreatureStatus(creature: c, mood: _moodOf(c), canFeed: c.energy >= feedEnergyCost, canPlay: c.energy >= playEnergyCost(loveRegenMod))`. Replace every `CreatureStatus(creature: …, mood: _moodOf(…))` construction (hatch `:113` with `mods.loveRegenMod`; myCreature `:220`; feed `:281`/`:351`; play `:462`; cure `:583`) with this helper.
- In `feed()`, immediately after `final base = decayed.creature;` and **before** `feedService.decide(...)`, add: if `base.energy < feedEnergyCost`, `return FeedResult(userResponse: feedService.exhaustedLine(), accepted: false, exhausted: true, status: _statusFor(base, personality.loveRegenMod))`. Normal/refusal returns set `exhausted: false`.
- In `play()`, after `final base = decayed.creature;` and **before** `playDelta(...)`, compute `final playCost = playEnergyCost(personality.loveRegenMod);` and: if `base.energy < playCost`, `return PlayResult(userResponse: playServiceFactory(session).exhaustedLine(), exhausted: true, status: _statusFor(base, personality.loveRegenMod))`. Normal play returns set `exhausted: false`.
- `cure()`: no energy check; only swap its `CreatureStatus` construction for `_statusFor`.

### Success Criteria:

#### Automated Verification:

- `serverpod generate` runs clean and leaves no uncommitted drift: `cd tamagotchi_server && serverpod generate`
- Server analyzes clean: `cd tamagotchi_server && dart analyze`
- Integration tests pass: `cd tamagotchi_server && docker compose up -d && dart test`
- New tests cover: Feed at `energy < 10` → `exhausted == true`, `accepted == false`, unchanged stats, **zero** new journal entries, LLM stub not invoked; Play at `energy < playEnergyCost` → `exhausted == true`, unchanged stats, zero new journal entries; Cure at `energy == 0` → succeeds; `canFeed`/`canPlay` correct across an energy sweep (e.g. energy 0, 5, 10, 100); Feed/Play at affordable energy → `exhausted == false`, normal stat change + one journal entry.

#### Manual Verification:

- A seeded run produces varied (not identical) exhausted lines across repeated blocked attempts.

**Implementation Note**: After Phase 1 automated verification passes, pause for human confirmation before starting Phase 2.

---

## Phase 2: Client — disabling, hint, distinct response

### Overview

Consume the regenerated models: disable unaffordable Feed/Play buttons with an "out of energy" hint, and render the exhausted backstop response distinctly. Driver: **`/10x-implement`** — primarily UI wiring + styling (hint placement, distinct visual) that's awkward to write strictly test-first; the behavioral assertions (button disabled when `!canFeed`, hint visible, exhausted response uses its style) are captured as widget tests as verification. (Could be `/10x-tdd` if you prefer to drive the disable/hint behavior red-first.)

### Changes Required:

#### 1. Shared outcome record carries exhausted

**File**: `tamagotchi_flutter/lib/creature/last_interaction.dart`

**Intent**: Let the shared response widget tell an exhausted outcome from a normal/refused one.

**Contract**: Extend `InteractionOutcome` to `({String userResponse, bool accepted, bool exhausted})`; `set(...)` gains a required `bool exhausted`.

#### 2. Controllers thread the flag

**File**: `tamagotchi_flutter/lib/creature/feed_controller.dart`, `play_controller.dart`, `cure_controller.dart`

**Intent**: Publish `exhausted` to the shared seam.

**Contract**: Feed → `set(userResponse: result.userResponse, accepted: result.accepted, exhausted: result.exhausted)`. Play → `set(userResponse: result.userResponse, accepted: !result.exhausted, exhausted: result.exhausted)`. Cure → `set(..., accepted: true, exhausted: false)`.

#### 3. Button disabling + hint + distinct response

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`

**Intent**: Disable unaffordable buttons, surface an "out of energy" hint, and style the exhausted response distinctly (non-error).

**Contract**:
- Feed button `onPressed: status.canFeed ? (…) : null`; Play button `onPressed: status.canPlay ? (…) : null` (mirror Cure's `illness == 0` disable at `:118`).
- When `!status.canFeed || !status.canPlay`, render a hint near the button row (keyed, e.g. `Key('energyHint')`) — short, in-character/explanatory ("Too tired — energy is regenerating"), not styled as an error.
- In `_InteractionResponse`, branch first on `outcome.exhausted` for a distinct visual (e.g. a tired/energy treatment with its own `Key('exhaustedResponse')` or color), falling back to the existing accepted/refused styling otherwise.

### Success Criteria:

#### Automated Verification:

- Client/Flutter analyzes clean: `cd tamagotchi_flutter && flutter analyze` (or `dart analyze`)
- Widget tests pass: `cd tamagotchi_flutter && flutter test`
- New widget tests cover: Feed/Play buttons disabled when `status.canFeed`/`canPlay` is false and enabled when true; energy hint visible only when an interaction is gated; an `exhausted` outcome renders the distinct treatment (not the error text and not the plain accepted style).

#### Manual Verification:

- Drain energy in the running app (accelerate time / repeated Play) until Feed and/or Play disable; confirm the hint appears and Cure stays enabled.
- Confirm the disabled Feed button re-enables once energy regenerates past 10 (and Play past its cost).
- If a click reaches the server gate, the exhausted response reads as in-character flavor, not an error.

**Implementation Note**: After Phase 2 automated verification passes, pause for human confirmation of the manual play-through.

---

## Testing Strategy

### Unit Tests:

- `playEnergyCost` / `feedEnergyCost` affordability boundaries already pure — assert `canFeed`/`canPlay` thresholds at energy 9/10 and around `playEnergyCost(loveRegenMod)`.
- `exhaustedLine()` selectors return a member of the corresponding pool under a seeded RNG.

### Integration Tests:

- Feed blocked at low energy: `exhausted`/`accepted` flags, no stat change, no journal row, stub LLM not called.
- Play blocked at low energy: `exhausted` flag, no stat change, no journal row.
- Cure unaffected at energy 0.
- Affordable Feed/Play still behave as today (one journal entry, stats move).

### Manual Testing Steps:

1. Hatch a creature; Play repeatedly (raise time scale) to drive energy down.
2. Watch Play disable when energy falls below its cost, then Feed disable below 10; confirm the hint appears.
3. Confirm Cure stays enabled throughout (induce illness via decay to see a real cure).
4. Wait/accelerate for energy to regenerate; confirm buttons re-enable.

## Performance Considerations

The exhausted path is cheaper than today's interaction — it skips the LLM round-trip and the DB write entirely. Affordability is two integer comparisons per status build; negligible.

## Migration Notes

None — `CreatureStatus`, `FeedResult`, `PlayResult` are non-table models; only `serverpod generate` is required, no schema migration.

## References

- PRD requirement: `context/foundation/prd.md` FR-007 (and FR-004/FR-006 for the cost/cure model).
- Full-refusal precedent: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:277-283`.
- Cure exemption invariant: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:476-478`.
- Cost functions: `feed_service.dart:21`, `play_service.dart:30-31`.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Server — gate, models, copy

#### Automated

- [ ] 1.1 `serverpod generate` runs clean with no uncommitted drift
- [ ] 1.2 Server analyzes clean (`dart analyze`)
- [ ] 1.3 Integration tests pass (`dart test` with sidecars up)
- [ ] 1.4 New tests: Feed blocked at energy<10 (flags, no stat change, no journal, LLM stub not called)
- [ ] 1.5 New tests: Play blocked at energy<playEnergyCost (flag, no stat change, no journal)
- [ ] 1.6 New test: Cure succeeds at energy==0
- [ ] 1.7 New tests: canFeed/canPlay correct across an energy sweep
- [ ] 1.8 New tests: affordable Feed/Play unchanged (stat change + one journal entry, exhausted==false)

#### Manual

- [ ] 1.9 Seeded run yields varied exhausted lines across repeated blocked attempts

### Phase 2: Client — disabling, hint, distinct response

#### Automated

- [ ] 2.1 Client analyzes clean (`flutter analyze`)
- [ ] 2.2 Widget tests pass (`flutter test`)
- [ ] 2.3 Widget test: Feed/Play buttons disabled when unaffordable, enabled when affordable
- [ ] 2.4 Widget test: energy hint visible only when an interaction is gated
- [ ] 2.5 Widget test: exhausted outcome renders the distinct treatment (not error, not plain accepted)

#### Manual

- [ ] 2.6 Drain energy in-app: Feed/Play disable, hint appears, Cure stays enabled
- [ ] 2.7 Buttons re-enable once energy regenerates past each cost
- [ ] 2.8 A server-gated click renders exhausted flavor, not an error
