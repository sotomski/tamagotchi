---
date: 2026-06-06T00:00:00+00:00
researcher: Claude Sonnet 4.6
git_commit: 0617265d6efad0ac0a5d6c880aa5672b27326e12
branch: testing-feed-determinism-gate
repository: nabrudno
topic: "Feed determinism contract and accept/refuse gate — Phase 1 code grounding"
tags: [research, codebase, feed-service, determinism, accept-refuse-gate, mutation-test]
status: complete
last_updated: 2026-06-06
last_updated_by: Claude Sonnet 4.6
---

# Research: Feed determinism contract and accept/refuse gate — Phase 1 code grounding

**Date**: 2026-06-06
**Researcher**: Claude Sonnet 4.6
**Git Commit**: 0617265d6efad0ac0a5d6c880aa5672b27326e12
**Branch**: testing-feed-determinism-gate
**Repository**: nabrudno

## Research Question

Ground §3 Phase 1 of `context/foundation/test-plan.md`. Verify the code anchors, oracles, and cheapest test layer for:
- **Risk #1** — Feed determinism contract: same seed + same inputs → identical stat/mood magnitudes; two opposite-trait creatures over the same care sequence → measurably different end states.
- **Risk #2** — Accept/refuse gate: gate is monotone (hungrier → less likely to refuse, pickier → more likely); full creature always rejected; same seed → same outcome.

Also surface what tests already exist, what `mutation_test` setup is needed, and whether any anti-patterns are present in the existing suite.

---

## Summary

The implementation is clean and well-separated. The core stat math and gate logic live in pure functions in `feed_service.dart`. An injectable `feedServiceFactory` seam already exists and existing tests use a `_ScriptedRandom` stub to pin draw order. Tests covering most basic scenarios already ship with S-03.

**Phase 1 genuinely adds:**
1. `mutation_test: ^1.8.0` to dev_dependencies + a scoped config that targets `feed_service.dart` and runs only the fast unit suite (never boots Postgres).
2. A "near-full but not full" edge case: `hunger=1` must NOT trigger the full-creature short-circuit — no existing test asserts this boundary from the non-full side.
3. A seeded-`Random` reproducibility test: the same `Random(seed)` injected twice with identical creature+personality inputs must produce identical `FeedDecision` — this is the actual determinism oracle, not implied by `_ScriptedRandom`.
4. An opposite-trait differentiation test: max-picky vs min-picky creature, same hunger, same scripted tastiness roll → different accept/refuse outcomes — proves Risk #1's "measurably different end states."
5. Verify mood-derivation coverage against post-feed stat states (may already be covered; see Open Questions).

Anti-pattern audit of the existing suite: **no mirrors found**. The `-30`/`-10` assertions reference the named constants (PRD-grounded magnitudes), not a re-derived formula. The `0.3` composition assertion is hand-computed. The monotonicity assertions state the domain rule directly.

---

## Detailed Findings

### 1. FeedService location and structure

**File:** `tamagotchi_server/lib/src/creature/feed_service.dart`

```
Line 14-15:  int clampStat(int v) => v.clamp(0, 100)
Line 19:     const feedHungerDrop = 30;
Line 22:     const feedEnergyCost = 10;
Line 28:     double pickyFactor(double hungerDecayMod) => 1.5 - hungerDecayMod;
Line 33-37:  double rejectProbability({picky, hunger, tastiness}) =>
               picky * (1 - hunger / 100) * (1 - tastiness);
Line 43-48:  typedef FeedDecision = ({bool full, bool accepted, double tastiness, StatDelta delta});
Line 58-100: FeedDecision evaluateFeed({creature, personality, rng})  ← pure gate
Line 111-153: class FeedService  ← Injectable wrapper (RNG + LLM)
Line 159-160: FeedService feedServiceFor(Session session) => FeedService(rng: Random(), llm: …)
Line 167:    FeedService Function(Session session) feedServiceFactory = feedServiceFor;
```

The gate function `evaluateFeed()` at lines 58-100 is pure — no I/O, no global state, fully deterministic given the same `rng`, `creature`, and `personality`.

---

### 2. Stat formula — Risk #1 code anchor

**Stats mutated by a feed: hunger and energy only. Love and illness are never touched.**

```dart
// feed_service.dart:93-99
final delta = StatDelta(
  hungerDelta: clampStat(creature.hunger - feedHungerDrop) - creature.hunger,
  energyDelta: clampStat(creature.energy - feedEnergyCost) - creature.energy,
  loveDelta: 0,
  illnessDelta: 0,
);
```

- `feedHungerDrop = 30` — fixed; defined as a named constant, not inline magic.
- `feedEnergyCost = 10` — fixed; same.
- `clampStat` enforces `[0, 100]` bounds: `(creature.hunger - 30).clamp(0, 100)`.
- **Trait modifiers (hungerDecayMod, etc.) do not affect deltas.** Comment at lines 55-57 is explicit: "accepted-feed magnitudes are the fixed, clamped [feedHungerDrop] / [feedEnergyCost] — tastiness shapes only the accept gate, never the deltas."

**Risk #1 oracle for stat assertions (from FR-004 domain rules, not re-derived from code):**
- Accepted feed on a creature with `hunger ≥ 30`: hunger drops by exactly **30**, energy by exactly **10**.
- Accepted feed with `hunger < 30`: hunger drops to **0** (clamped), energy delta is still **−10** unless `energy < 10`.
- Refused feed (any reason): all deltas are **0**.

---

### 3. Mood derivation — Risk #1 code anchor

**File:** `tamagotchi_server/lib/src/creature/creature_service.dart:30-45`

```dart
CreatureMood deriveMood(int hunger, int energy, int love, int illness) {
  if (illness >= 50) return CreatureMood.sick;
  final worst = [hunger, 100 - energy, 100 - love].reduce(max);
  if (worst < 25) return CreatureMood.happy;
  if (worst < 55) return CreatureMood.content;
  return CreatureMood.sad;
}
```

**Mood is never stored and never RNG-driven.** The comment at lines 30-31 states this explicitly. The endpoint calls `deriveMood` at `creature_endpoint.dart:242-243` after applying the delta, then returns the result — every read re-derives mood from the current stat values.

**Risk #1 oracle for mood assertions (from PRD/domain rules):**

| Illness | Worst distress | Mood |
|---------|---------------|------|
| ≥ 50    | (any)         | sick |
| < 50    | < 25          | happy |
| < 50    | 25–54         | content |
| < 50    | ≥ 55          | sad |

Distress = `max(hunger, 100−energy, 100−love)`. After a typical accepted feed from `(hunger=60, energy=100, love=50, illness=0)`: new stats `(hunger=30, energy=90, love=50, illness=0)` → distress = `max(30, 10, 50) = 50` → **content**. This can be computed independently from the rules without reading the implementation body.

**Critical: deriveMood is independent of RNG.** The determinism contract for mood holds automatically once the stat deltas are deterministic.

---

### 4. RNG seed plumbing — Risk #1/#2 code anchor

**Production factory (feed_service.dart:159-160):**
```dart
FeedService feedServiceFor(Session session) =>
    FeedService(rng: Random(), llm: llmServiceFor(session));
```
`Random()` with no argument = system entropy. Production is intentionally non-deterministic.

**Test injection (feed_service.dart:167):**
```dart
FeedService Function(Session session) feedServiceFactory = feedServiceFor;
```
Tests reassign this seam and restore with `addTearDown`. The pattern from `feed_endpoint_test.dart:51-65`:
```dart
void _injectFeedService(List<double> doubles, {LlmService llm = …}) {
  feedServiceFactory = (_) => FeedService(rng: _ScriptedRandom(doubles), llm: llm);
  addTearDown(() => feedServiceFactory = feedServiceFor);
}
```

**RNG draw order within `evaluateFeed()` (feed_service.dart:70-82) — load-bearing contract:**
1. Full-creature short-circuit (`hunger == 0`) — **no draws consumed**.
2. Draw 1: `tastiness = rng.nextDouble()` — range `[0.0, 1.0)`.
3. Draw 2: `reject = rng.nextDouble() < rejectProbability(…)`.

This order is documented explicitly at lines 50-53:
> "RNG draw order is part of the contract (seeded tests depend on it): on a non-full creature we draw `tastiness` FIRST, then the reject roll."

The `_ScriptedRandom` class in both `feed_service_test.dart:12-30` and `feed_endpoint_test.dart:17-35` throws `StateError` if drawn past the scripted queue — making "consumed zero draws" assertable for the full-refusal path.

**The determinism oracle for Risk #1** requires a test that injects `Random(seed)` directly (not `_ScriptedRandom`) and calls `evaluateFeed()` twice with identical inputs — both calls must return bit-for-bit identical `FeedDecision`. This specific test does not yet exist. It is the strongest proof that no non-deterministic state leaks into the computation.

---

### 5. Accept/refuse gate — Risk #2 code anchor

**Full-creature short-circuit (feed_service.dart:70-72):**
```dart
if (creature.hunger == 0) {
  return (full: true, accepted: false, tastiness: 0, delta: zeroDelta);
}
```
- Threshold: **exact equality** `hunger == 0`.
- Newborns spawn with `hunger: 0` (baseline at hatch).
- A creature with `hunger = 1` is NOT full and proceeds to the gate.

**pickyFactor formula (feed_service.dart:28):**
```dart
double pickyFactor(double hungerDecayMod) => 1.5 - hungerDecayMod;
```
- `hungerDecayMod` ∈ `[0.5, 1.5)` → `pickyFactor` ∈ `(0.0, 1.0]`.
- **Only `hungerDecayMod` from the personality feeds the gate.** The other 7 personality modifiers (energyDecayMod, loveDecayMod, etc.) are ignored by the feed path entirely.
- `hungerDecayMod = 0.5` (slowest metabolism) → `pickyFactor = 1.0` (maximally picky).
- `hungerDecayMod = 1.5` (fastest metabolism) → `pickyFactor = 0.0` (never rejects).

**rejectProbability formula (feed_service.dart:33-37):**
```dart
double rejectProbability({
  required double picky,
  required int hunger,
  required double tastiness,
}) => picky * (1 - hunger / 100) * (1 - tastiness);
```

**Monotonicity properties (Risk #2 oracle from domain rules, not code):**
- Hungrier creature (higher `hunger`) → lower reject probability → less likely to refuse. (Factor `1 - hunger/100` decreases as hunger falls, i.e. as creature becomes full.)
- Pickier creature (higher `picky`) → higher reject probability → more likely to refuse.
- Tastier food (higher `tastiness`) → lower reject probability → more likely to accept.
- When `hunger = 100` (maximally hungry): `1 - 100/100 = 0` → `rejectProbability = 0` → creature always accepts regardless of picky.
- When `picky = 0.0` (hungerDecayMod = 1.5): `rejectProbability = 0` → creature always accepts.
- When `picky = 1.0, hunger = 0, tastiness = 0`: the full-creature short-circuit fires before any computation.

**Roll order (both draws use the SAME `_rng` instance):**
- The scripted approach in tests locks the sequence: `_ScriptedRandom([<tastiness_value>, <reject_roll>])`.
- The full-creature path uses `_ScriptedRandom([])` — any accidental draw would throw.

---

### 6. What already exists in the test suite

**`tamagotchi_server/test/unit/feed_service_test.dart` (213 lines)**

| Group | Tests | What is asserted |
|-------|-------|-----------------|
| `pickyFactor` | Lines 73-85 | Individual values (0.5→1.0, 1.0→0.5, 1.5→0.0) + monotonicity |
| `rejectProbability` | Lines 93-120 | Starving=0, tastiness=1→0, composition=0.3 (hand-computed), monotonicity |
| `clampStat` | Lines 125-127 | Above 100 clamps to 100, below 0 clamps to 0, in-range unchanged |
| `evaluateFeed` | Lines 131-212 | Full path (no draws, full=true), accepted (draws=[0.5,0.99], hungerDelta=-30, energyDelta=-10), clamped (hunger=10→-10, energy=5→-5), picky-refuse (zero delta, not full) |

**Anti-pattern audit of existing tests:**
- `-30`/`-10` assertions reference `feedHungerDrop`/`feedEnergyCost` (named constants), not a formula. **Not a mirror. ✓**
- `0.3` composition assertion: `0.8 * 0.5 * 0.75 = 0.3` — hand-computed, independent. **Not a mirror. ✓**
- Monotonicity asserted as strict ordering. **Domain rule, not formula re-execution. ✓**
- `_ScriptedRandom` throws on over-draw — makes draw-count assertable. **Good oracle hygiene. ✓**

**`tamagotchi_server/test/integration/feed_endpoint_test.dart` (300 lines)**

| Test | Lines | Scope |
|------|-------|-------|
| Accepted feed persists stats + journal | 124-164 | Real DB; checks `accepted=true`, stats, journal entry delta |
| Full refusal: no LLM, no journal | 167-190 | Real DB; uses empty scripted draws, asserts `isIn(fullRefusalLines)` |
| Picky refusal: zero delta, journal written | 193-230 | Real DB; picky=1.0, asserts `accepted=false`, zero delta but journal entry IS written |
| LLM failure: degrade path | 232-256 | Real DB; `_ThrowingLlmService`, stats still apply, canned copy used |
| No creature: error | 258-275 | Real DB; asserts `CreatureFeedError(noCreature)` |
| Owner scoping (IDOR prevention) | 277-298 | Real DB; two users, B feeds, A's creature unchanged |

**`tamagotchi_server/test/creature/creature_service_test.dart` (215 lines)**
- `deriveMood()`: 9 boundary test cases. Covers illness threshold, happy/content/sad thresholds.

---

### 7. Phase 1 gap analysis

Comparing what exists against what Phase 1 must prove:

| Phase 1 requirement | Already covered? | Gap / what to add |
|---|---|---|
| stat deltas are fixed −30/−10 on accept | ✓ unit + integration | — |
| clamping when hunger < 30 or energy < 10 | ✓ unit (clamped scenario) | — |
| refused feed leaves stats at zero delta | ✓ unit + integration | — |
| full creature (hunger==0) short-circuits before any draw | ✓ unit + integration | — |
| **hunger=1 is NOT treated as full** | **✗ missing** | Add: creature with hunger=1 proceeds to gate, not full-refusal |
| same seed → same output (reproducibility) | **✗ missing** | Add: inject `Random(seed)` directly, call `evaluateFeed()` twice, assert identical outputs |
| opposite-trait creatures → measurably different outcomes | **✗ missing** | Add: hungerDecayMod=0.5 refuses where hungerDecayMod=1.5 accepts, same hunger, same scripted tastiness |
| mood derivation after feed is correct per PRD rules | Partial (unit covers deriveMood in isolation; integration covers it E2E) | Verify creature_service_test covers post-feed stat states; add unit test if not (see Open Questions §1) |
| pickyFactor monotonicity | ✓ unit | — |
| rejectProbability monotonicity | ✓ unit | — |
| `mutation_test` configured and scoped | **✗ missing** | Add dev_dependency + config (see §8 below) |

**Three genuine test additions + mutation_test setup** is the Phase 1 scope.

---

### 8. mutation_test configuration gap

**Current state:** `mutation_test` is **not in `tamagotchi_server/pubspec.yaml`** dev_dependencies. No config file exists anywhere.

**Required per test-plan §4:** `mutation_test: 1.8.0`, ad-hoc local only (not CI), scoped to `feed_service.dart`, running only the unit suite (the tag-filtered test command must exclude the `integration` tag so Postgres is never booted).

**Config format — open question:** The test plan describes "XML config sets the filtered test command." The `mutation_test` package's actual config format (YAML vs XML) at version 1.8.0 must be verified during planning (see Open Questions §2). The key parameters needed regardless of format:
- File(s) to mutate: `lib/src/creature/feed_service.dart`
- Test command to run: `dart test test/unit/ --no-color` (excludes integration tag; unit dir only)
- HTML report output enabled.

---

### 9. Key interactions between Risks #1 and #2

Risks #1 and #2 share the same code path; they are two faces of the same gate function:

- **Risk #1** is about the reproducibility/determinism guarantee: the same physical inputs always produce the same outputs. It is violated if non-deterministic state leaks in (e.g., unseeded global `Random`, current time, external service).
- **Risk #2** is about the monotonicity guarantee: the mathematical relationship between pickiness/hunger/tastiness and the accept/refuse decision is correctly ordered per the PRD's intent. It is violated if the formula is subtly wrong (e.g., wrong direction, wrong factor).

Both risks are anchored in the same `evaluateFeed()` function. A mutation_test run on `feed_service.dart` covers both simultaneously.

The seeded-`Random` reproducibility test (gap item 2 above) covers Risk #1 exclusively; the opposite-trait test (gap item 3) covers Risk #1's "measurably different end states" clause and overlaps with Risk #2's monotonicity.

---

## Code References

- `tamagotchi_server/lib/src/creature/feed_service.dart:19` — `feedHungerDrop = 30`
- `tamagotchi_server/lib/src/creature/feed_service.dart:22` — `feedEnergyCost = 10`
- `tamagotchi_server/lib/src/creature/feed_service.dart:28` — `pickyFactor` formula
- `tamagotchi_server/lib/src/creature/feed_service.dart:33-37` — `rejectProbability` formula
- `tamagotchi_server/lib/src/creature/feed_service.dart:43-48` — `FeedDecision` typedef
- `tamagotchi_server/lib/src/creature/feed_service.dart:50-53` — draw-order contract comment
- `tamagotchi_server/lib/src/creature/feed_service.dart:58-100` — `evaluateFeed()` pure gate
- `tamagotchi_server/lib/src/creature/feed_service.dart:70-72` — full-creature short-circuit
- `tamagotchi_server/lib/src/creature/feed_service.dart:74` — tastiness draw (first)
- `tamagotchi_server/lib/src/creature/feed_service.dart:77` — reject draw (second)
- `tamagotchi_server/lib/src/creature/feed_service.dart:93-99` — accepted-feed delta computation
- `tamagotchi_server/lib/src/creature/feed_service.dart:111-153` — `FeedService` class
- `tamagotchi_server/lib/src/creature/feed_service.dart:159-160` — production factory
- `tamagotchi_server/lib/src/creature/feed_service.dart:167` — `feedServiceFactory` seam
- `tamagotchi_server/lib/src/creature/creature_service.dart:14` — baseline stats constant
- `tamagotchi_server/lib/src/creature/creature_service.dart:30-45` — `deriveMood()` pure function
- `tamagotchi_server/lib/src/creature/creature_service.dart:50-62` — `randomPersonalityModifiers()`
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:140-240` — `feed()` endpoint orchestration
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:242-243` — `_moodOf()` helper
- `tamagotchi_server/test/unit/feed_service_test.dart:12-30` — `_ScriptedRandom` class
- `tamagotchi_server/test/unit/feed_service_test.dart:37-50` — `_creature()` factory
- `tamagotchi_server/test/unit/feed_service_test.dart:54-64` — `_personality()` factory
- `tamagotchi_server/test/unit/feed_service_test.dart:67-212` — all gate unit tests
- `tamagotchi_server/test/integration/feed_endpoint_test.dart:17-35` — `_ScriptedRandom` (integration copy)
- `tamagotchi_server/test/integration/feed_endpoint_test.dart:51-65` — `_injectFeedService()` helper
- `tamagotchi_server/test/creature/creature_service_test.dart` — `deriveMood()` 9 boundary cases
- `tamagotchi_server/dart_test.yaml` — minimal config; defines `integration:` tag only
- `tamagotchi_server/pubspec.yaml:20-23` — dev_dependencies (no `mutation_test` yet)
- `tamagotchi_server/config/test.yaml` — test DB config (postgres_test:5432, redis disabled)

---

## Architecture Insights

**The single-seam design collapses two planned seams into one.** The original plan for this feature described separate `llmServiceFactory` and `feedRandomFactory` seams. The implementation merged both into `feedServiceFactory` — tests inject a `FeedService` with both RNG and LLM controlled at once. This is strictly better: fewer global mutable variables, and the two impure collaborators always travel together.

**`evaluateFeed()` is deliberately not a method on `FeedService`.** It is a standalone top-level function so it can be tested without constructing a `FeedService` object. `FeedService.decide()` is a thin wrapper. This means unit tests can call `evaluateFeed()` directly without touching the seam at all — and the seam is only needed when testing endpoint-level behavior.

**Mood is never stored, which eliminates a whole class of consistency bugs.** If mood were persisted, a feed that changed stats but crashed before updating mood would leave the creature in an inconsistent state. The current design has no such risk.

**The `_ScriptedRandom` approach (scripted draw queue) is stronger than `Random(seed)` injection for contract testing**, because it lets each test control exactly what each draw returns without knowing the seed → output mapping of Dart's PRNG. However, it does NOT test that the production code uses the RNG correctly (it could swap the two draws and `_ScriptedRandom` would catch it only if the expected values are wrong). A `Random(seed)` reproducibility test catches a different bug class: that the RNG instance is not shared with any other goroutine/coroutine accidentally.

---

## Historical Context (from prior changes)

- `context/changes/feed-with-personality-response/plan.md` — The `feedServiceFactory` seam was introduced here as the canonical injection point for both RNG and LLM. The lesson "Inject impure collaborators via one production-default factory seam, never @visibleForTesting" (`context/foundation/lessons.md`) was recorded as a direct outcome of this change.
- `context/foundation/test-plan.md:49` — Impl-review findings F1 (no Mistral HTTP timeout) and F2 (raw upstream body in logs) are noted at Risk #7. Both are Phase 2 work and explicitly out of scope for Phase 1.
- `context/foundation/test-plan.md:90-93` — All four rollout phases are `not started`. The existing tests in `feed_service_test.dart` and `feed_endpoint_test.dart` shipped as S-03 feature tests, not as rollout-phase hardening. Phase 1 hardens them further and adds the mutation gate.

---

## Related Research

- No prior research.md files exist in other change folders that overlap with this topic.

---

## Open Questions

1. **Does `creature_service_test.dart` cover post-feed stat states for mood derivation?** The agent found "9 boundary cases" for `deriveMood()` but did not list the specific stat inputs. Before the plan phase, verify whether any case exercises the realistic post-feed state `(hunger=30, energy=90, love=50, illness=0)` → `content`. If not, add one mood test that uses PRD-grounded inputs. This is low-priority because the integration test already covers mood E2E.

2. **`mutation_test` 1.8.0 config format.** The test plan says "XML config." The actual format (YAML vs XML, key names, test-command filter syntax) needs to be verified against pub.dev documentation before writing the plan. Do not assume the format from training data — it may have changed in 1.8.0.

3. **`_ScriptedRandom` duplication.** The class is copy-pasted between `test/unit/feed_service_test.dart:12-30` and `test/integration/feed_endpoint_test.dart:17-35`. Phase 1 may be a good opportunity to extract it to a shared test helper file (e.g., `test/helpers/scripted_random.dart`). This is a cleanup, not a correctness issue — decide in the plan phase based on cost vs. signal.
