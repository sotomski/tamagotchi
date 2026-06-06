# Feed Determinism and Accept/Refuse Gate Tests

## Overview

Add three targeted unit tests that lock the S-03 Feed slice's determinism contract and gate monotonicity (Risks #1 and #2, `context/foundation/test-plan.md §3 Phase 1`), then validate assertion strength with a scoped `mutation_test` pass against `feed_service.dart`. No endpoint, schema, or Flutter changes.

## Current State Analysis

`evaluateFeed()` (`feed_service.dart:58-100`) is a pure top-level function already exercised by `feed_service_test.dart` (8 test cases across 4 groups). The existing suite is clean — no oracle mirrors found. Three gaps remain:

1. No test asserts `hunger=1` is NOT treated as full. The `hunger == 0` exact-equality threshold has no "just-above" assertion; a mutation changing it to `< 10` would survive all existing tests.
2. No `Random(seed)` reproducibility test proves determinism under a real seeded PRNG. The `_ScriptedRandom` approach pins draw order but does not prove freedom from non-deterministic leakage.
3. No test exercises opposite `hungerDecayMod` extremes over identical conditions to prove the "measurably different end states" clause of Risk #1.

`mutation_test` is not in dev_dependencies and no config file exists. `_ScriptedRandom` is copy-pasted identically in `feed_service_test.dart:12-30` and `feed_endpoint_test.dart:17-35`.

## Desired End State

`dart test test/unit/` passes with 3 new tests. A scoped `mutation_test` run against `feed_service.dart` reports 0 unaddressed business-impactful survivors. `test-plan.md §6.1` carries the cookbook pattern for this module.

### Key Discoveries

- `evaluateFeed()` at `feed_service.dart:58-100` is pure — no seam required for unit tests; call directly.
- Full-creature threshold is **exact equality** `hunger == 0` (`feed_service.dart:70-72`), not `<= 0`.
- `pickyFactor = 1.5 - hungerDecayMod` (`feed_service.dart:28`); range `(0.0, 1.0]` for `hungerDecayMod ∈ [0.5, 1.5)`.
- `rejectProbability = picky * (1 - hunger/100) * (1 - tastiness)` (`feed_service.dart:33-37`).
- RNG draw order is documented as load-bearing at `feed_service.dart:50-53`: tastiness first, reject roll second, zero draws for full path.
- `deriveMood()` is RNG-free (`creature_service.dart:30-45`). The existing 9 boundary tests cover all threshold edges; no post-feed mood test needed.
- `mutation_test` XML format: root element `<mutations version="1.2">` with `<files>` and `<commands>` children (confirmed from pub.dev docs).

## What We're NOT Doing

- No endpoint, Flutter, or schema changes.
- No post-feed mood unit test — 9 existing boundary cases bracket all thresholds; integration test covers mood E2E.
- No CI gate for `mutation_test` — ad-hoc local only per `test-plan.md §4`.
- No changes to integration tests in this phase.
- `dart_test.yaml` stays as-is.

## Implementation Approach

Four sub-phases in order: infrastructure (dependency + config) → tests (helper extraction + 3 new tests) → gate (run mutation_test, triage) → cookbook. Each is independently verifiable. All changes are confined to `tamagotchi_server/` and `context/`.

## Critical Implementation Details

**mutation_test runs from `tamagotchi_server/` only.** The `<command>` in the XML uses `dart test test/unit/ --no-color`. This must never reference the integration tag or boot Postgres. Set `timeout` to at least 60 seconds.

**`Random(seed)` in Dart guarantees sequence determinism for the same seed.** Two independent `Random(42)` instances produce bit-identical `nextDouble()` streams on the Dart VM. The reproducibility test's oracle is equality between the two calls, not any specific value.

---

## Phase 1: mutation_test infrastructure

### Overview

Add `mutation_test` as a dev dependency and create the scoped XML config. No test code is touched in this phase.

### Changes Required

#### 1. Add dev dependency

**File:** `tamagotchi_server/pubspec.yaml`

**Intent:** Add `mutation_test` to dev_dependencies so `dart run mutation_test` resolves in this package.

**Contract:** Under `dev_dependencies:`, add `mutation_test: ^1.8.0`. Run `dart pub get` from `tamagotchi_server/` to verify the dependency graph resolves cleanly.

#### 2. Create XML config

**File:** `tamagotchi_server/mutation_test.xml`

**Intent:** Scope the mutation run to `feed_service.dart` and restrict the test command to the unit suite so Postgres is never booted.

**Contract:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mutations version="1.2">
  <files>
    <file>lib/src/creature/feed_service.dart</file>
  </files>
  <commands>
    <command group="unit" expected-return="0" timeout="60">
      dart test test/unit/ --no-color
    </command>
  </commands>
</mutations>
```

#### 3. Add mutation_out/ to .gitignore

**File:** `tamagotchi_server/.gitignore` (create if absent; otherwise add to root `.gitignore` under a `# mutation_test output` comment)

**Intent:** Prevent the HTML report directory from being committed.

**Contract:** Add the line `mutation_out/`.

### Success Criteria

#### Automated Verification

- `dart pub get` succeeds in `tamagotchi_server/` with no version conflicts.
- `dart run mutation_test --dry mutation_test.xml` completes and lists mutations for `feed_service.dart` without running any tests.

#### Manual Verification

- The dry-run output lists mutations in `evaluateFeed`, `pickyFactor`, `rejectProbability`, and `clampStat` — confirming the XML file scope is correct.

---

## Phase 2: Helper extraction and three new unit tests

### Overview

Extract `_ScriptedRandom` to a shared helper, update both existing test files, then add the three tests that close the identified gaps.

### Changes Required

#### 1. Extract ScriptedRandom to a shared helper

**File:** `tamagotchi_server/test/helpers/scripted_random.dart` (new file)

**Intent:** Eliminate the copy-pasted private class. Both test files currently define an identical `_ScriptedRandom`; extract it as the public `ScriptedRandom` so future test phases can import it directly.

**Contract:** `class ScriptedRandom implements Random`. Constructor takes `List<double> doubles`. `nextDouble()` pops the next entry and throws `StateError('ScriptedRandom: nextDouble() called more times than scripted')` when exhausted. `nextInt(int max)` returns `0` (sufficient for `fullRefusalLine()` pick). `nextBool()` throws `UnimplementedError`. All other `Random` interface members throw `UnimplementedError`.

#### 2. Update feed_service_test.dart

**File:** `tamagotchi_server/test/unit/feed_service_test.dart`

**Intent:** Remove the local `_ScriptedRandom` class and replace all references with the shared import; then add three new test cases inside the existing `evaluateFeed` group.

**Contract — import and rename:** Add `import '../helpers/scripted_random.dart';`. Remove lines 12-30 (the `_ScriptedRandom` class). Replace every `_ScriptedRandom(` call site with `ScriptedRandom(`.

**Contract — Test A: `hunger=1 is NOT treated as full`:**
Oracle from FR-004: the full-creature gate fires only at `hunger == 0`; any positive hunger must proceed to the random gate. Use `_creature(hunger: 1)`, `_personality(hungerDecayMod: 1.0)`, `ScriptedRandom([0.5, 0.99])`. At `hunger=1, pickyFactor=0.5, tastiness=0.5`: `rejectProbability ≈ 0.2475`; roll `0.99 > 0.2475` → accepted. Assert `result.full == false` (primary oracle), `result.accepted == true`, `result.delta.hungerDelta == -1` (clamp: `max(0, 1-30) - 1 = -1`), `result.delta.energyDelta == -10`.

**Contract — Test B: `same Random(seed) → identical FeedDecision`:**
Oracle from PRD §Success Criteria: same seed + same inputs → identical outputs. Call `evaluateFeed()` twice with two independent `Random(42)` instances, `_creature(hunger: 60)`, `_personality(hungerDecayMod: 1.0)`. Assert all fields equal: `result1.accepted == result2.accepted`, `result1.full == result2.full`, `result1.tastiness == result2.tastiness`, all four delta fields pairwise equal. Do not assert specific values — the oracle is equality, not a particular outcome.

**Contract — Test C: `opposite hungerDecayMod → different accept outcome`:**
Oracle from FR-004 and PRD §Success Criteria: opposite-trait creatures must produce measurably different outcomes under identical conditions. Use `_creature(hunger: 60)`. For max-picky: `_personality(hungerDecayMod: 0.5)` + `ScriptedRandom([0.5, 0.1])` → `pickyFactor=1.0`, `rejectProbability = 1.0 * 0.4 * 0.5 = 0.2`, roll `0.1 < 0.2` → rejected. For min-picky: `_personality(hungerDecayMod: 1.5)` + `ScriptedRandom([0.5, 0.1])` (a fresh instance) → `pickyFactor=0.0`, `rejectProbability = 0.0`, roll `0.1 < 0.0` → accepted. Assert `maxPickyResult.accepted == false`, `minPickyResult.accepted == true`.

#### 3. Update feed_endpoint_test.dart

**File:** `tamagotchi_server/test/integration/feed_endpoint_test.dart`

**Intent:** Remove the local `_ScriptedRandom` class (lines 17-35) and import the shared helper.

**Contract:** Add `import '../helpers/scripted_random.dart';`. Remove lines 17-35. Replace every `_ScriptedRandom(` with `ScriptedRandom(`.

### Success Criteria

#### Automated Verification

- `dart analyze --fatal-infos` passes in `tamagotchi_server/`.
- `dart format --set-exit-if-changed .` exits 0 in `tamagotchi_server/`.
- `dart test test/unit/ --no-color` exits 0; all existing + 3 new tests pass.
- `dart test test/ --no-color` exits 0 (integration regression check — requires Postgres sidecar; confirm `feed_endpoint_test.dart` still passes after the import change).

#### Manual Verification

- All three new test names appear with `pass` in `dart test test/unit/ --reporter=expanded` output.

---

## Phase 3: Mutation gate

### Overview

Run `mutation_test` scoped to `feed_service.dart`, inspect the HTML report, and add targeted assertions for any survived mutants that represent real regressions. Document equivalent mutants.

### Changes Required

#### 1. Run the mutation gate

**Not a code change.** From `tamagotchi_server/`:

```
dart run mutation_test -f html -o mutation_out mutation_test.xml
```

Open `mutation_out/index.html` in a browser.

#### 2. Triage survived mutants

**File:** `tamagotchi_server/test/unit/feed_service_test.dart` (conditional — only if survivors require new assertions)

**Intent:** For each survived mutant, decide: business-impactful → add the minimal assertion that kills it; equivalent → document and skip.

**Triage guidance by location:**

- `clampStat` boundary constants (0/100): covered by clamped-underflow test; likely killed.
- `feedHungerDrop`/`feedEnergyCost` constants: covered by exact-delta assertions; likely killed.
- `pickyFactor` sign/coefficient: covered by individual value tests; likely killed.
- `rejectProbability` operator mutations (`*` → `+`): monotonicity + composition tests should kill; verify.
- `hunger == 0` → `<= 0`: **equivalent mutant** (hunger is always non-negative after `clampStat`); consciously skip.
- `hunger == 0` → `< 10`: **business-impactful** — the Test A added in Phase 2 should kill this mutation; verify.
- `rng.nextDouble() < rejectProbability` → `>`: Test C should kill this; verify.

#### 3. Document equivalent mutants in XML

**File:** `tamagotchi_server/mutation_test.xml` (conditional — only for confirmed equivalent mutants)

**Intent:** Suppress equivalent mutants from future reports without requiring manual dismissal each run.

**Contract:** Add an `<exclude>` section. For the `hunger <= 0` equivalent mutant:

```xml
<exclude>
  <!-- hunger <= 0 is equivalent to hunger == 0: clampStat guarantees hunger >= 0 -->
  <lines begin="70" end="72"/>
</exclude>
```

Only add exclusions for verified equivalent mutants.

### Success Criteria

#### Automated Verification

- `dart run mutation_test -f html -o mutation_out mutation_test.xml` completes without error.
- `dart test test/unit/ --no-color` exits 0 after any assertions added during triage.

#### Manual Verification

- `mutation_out/index.html`: all mutations in `evaluateFeed`, `pickyFactor`, `rejectProbability`, and `clampStat` are either killed or documented as equivalent with a rationale in the XML exclusion.

---

## Phase 4: Cookbook update and rollout close

### Overview

Fill `test-plan.md §6.1` with the cookbook pattern discovered in this phase, add a §6.6 phase note, and mark the change complete.

### Changes Required

#### 1. Fill §6.1 in test-plan.md

**File:** `context/foundation/test-plan.md`

**Intent:** Replace the TBD placeholder in §6.1 with concrete guidance so future contributors can add tests against `feed_service.dart` without re-researching the seam, oracle source, and mutation gate workflow.

**Contract:** The §6.1 body should document:
- Test file: `tamagotchi_server/test/unit/feed_service_test.dart`.
- Helper: `test/helpers/scripted_random.dart` (`ScriptedRandom`) for scripted draw queues; `Random(seed)` for reproducibility assertions.
- Call `evaluateFeed()` directly (no seam needed for unit tests).
- Oracle source: FR-004 domain rules and the named constants `feedHungerDrop` / `feedEnergyCost` — never derive the expected value from the function under test.
- Anti-pattern to avoid: asserting specific `tastiness` doubles from a seeded PRNG call — the reproducibility oracle is *equality between two calls*, not a particular value.
- Mutation gate: `dart run mutation_test -f html -o mutation_out mutation_test.xml` from `tamagotchi_server/`. Triage the HTML report; add assertions only for business-impactful survivors. Document equivalent mutants in the XML `<exclude>` block.

#### 2. Add §6.6 phase note

**File:** `context/foundation/test-plan.md`

**Intent:** Capture anything surprising from this rollout phase as a 2-3 line note under §6.6.

**Contract:** Append under §6.6: note the `_ScriptedRandom` → shared helper extraction, the `hunger <= 0` equivalent mutant finding, and the count of business-impactful survived mutants after Phase 3 triage.

#### 3. Mark change complete

**File:** `context/changes/testing-feed-determinism-gate/change.md`

**Intent:** Close out the change artifact.

**Contract:** Set `status: complete`, `updated: <today's date>`.

### Success Criteria

#### Automated Verification

- `dart analyze --fatal-infos` passes in `tamagotchi_server/` (no accidental Dart file edits).

#### Manual Verification

- `test-plan.md §6.1` no longer reads "TBD — see §3 Phase 1."
- `test-plan.md §6.6` has a 2-3 line Phase 1 note.
- `change.md` shows `status: complete`.

---

## Testing Strategy

### Unit Tests

All new tests call `evaluateFeed()` directly — pure function, no seam or session required.

- **Test A — `hunger=1` edge case:** oracle from FR-004 ("full = zero hunger"); asserts `full=false` + expected clamped delta.
- **Test B — `Random(seed)` reproducibility:** oracle from PRD §Success Criteria (determinism guarantee); asserts pairwise equality between two seeded calls — no specific value asserted.
- **Test C — opposite-trait differentiation:** oracle from FR-004 + PRD ("picky creature won't always accept; non-picky accepts"); asserts `accepted=false` for max-picky, `accepted=true` for min-picky under identical scripted rolls.

### Integration Tests

No new integration tests in this phase. The `_ScriptedRandom` → `ScriptedRandom` import refactor in `feed_endpoint_test.dart` must not break the existing 6 integration tests — verify with `dart test test/ --no-color` (Phase 2.4).

### Manual Testing Steps

1. Phase 1: `dart run mutation_test --dry mutation_test.xml` — confirm scope matches `feed_service.dart` functions.
2. Phase 2: `dart test test/unit/ --reporter=expanded` — confirm all three new test names appear as `pass`.
3. Phase 3: `mutation_out/index.html` — review each survivor and classify kill or equivalent.
4. Phase 4: read `test-plan.md §6.1` in a fresh context — confirm it is actionable without prior knowledge.

## References

- Research: `context/changes/testing-feed-determinism-gate/research.md`
- Test plan: `context/foundation/test-plan.md §3 Phase 1`
- Lessons: `context/foundation/lessons.md` (`dart format` rule, seam pattern)
- File under test: `tamagotchi_server/lib/src/creature/feed_service.dart`
- Tests extended: `tamagotchi_server/test/unit/feed_service_test.dart`
- New helper: `tamagotchi_server/test/helpers/scripted_random.dart`
- Integration tests updated (import only): `tamagotchi_server/test/integration/feed_endpoint_test.dart`

---

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: mutation_test infrastructure

#### Automated

- [ ] 1.1 `dart pub get` succeeds in `tamagotchi_server/` with `mutation_test: ^1.8.0` added
- [ ] 1.2 `dart run mutation_test --dry mutation_test.xml` lists mutations for `feed_service.dart`

#### Manual

- [ ] 1.3 Dry-run output lists mutations in `evaluateFeed`, `pickyFactor`, `rejectProbability`, `clampStat`

### Phase 2: Helper extraction and three new unit tests

#### Automated

- [ ] 2.1 `dart analyze --fatal-infos` passes in `tamagotchi_server/`
- [ ] 2.2 `dart format --set-exit-if-changed .` exits 0 in `tamagotchi_server/`
- [ ] 2.3 `dart test test/unit/ --no-color` exits 0 (all existing + 3 new tests pass)
- [ ] 2.4 `dart test test/ --no-color` exits 0 (integration regression check; requires Postgres sidecar)

#### Manual

- [ ] 2.5 All three new test names appear with `pass` in `--reporter=expanded` output

### Phase 3: Mutation gate

#### Automated

- [ ] 3.1 `dart run mutation_test -f html -o mutation_out mutation_test.xml` completes without error
- [ ] 3.2 `dart test test/unit/ --no-color` exits 0 after any triage assertions added

#### Manual

- [ ] 3.3 HTML report reviewed: all survivors classified as killed or documented equivalent in XML

### Phase 4: Cookbook update and rollout close

#### Automated

- [ ] 4.1 `dart analyze --fatal-infos` passes in `tamagotchi_server/`

#### Manual

- [ ] 4.2 `test-plan.md §6.1` contains the cookbook pattern (no longer reads "TBD")
- [ ] 4.3 `test-plan.md §6.6` has a Phase 1 note
- [ ] 4.4 `change.md` shows `status: complete`
