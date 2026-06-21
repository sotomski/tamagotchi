# Feed Determinism and Accept/Refuse Gate Tests — Plan Brief

> Full plan: `context/changes/testing-feed-determinism-gate/plan.md`
> Research: `context/changes/testing-feed-determinism-gate/research.md`

## What & Why

Phase 1 of the `context/foundation/test-plan.md` rollout. The S-03 Feed slice shipped with basic unit and integration tests, but three assertion gaps leave Risks #1 and #2 partially exposed: no test pins the exact `hunger == 0` fullness threshold from the non-full side, no test proves `Random(seed)` determinism, and no test compares opposite personality extremes. Adding these three tests plus a scoped `mutation_test` pass "locks" the determinism contract so future refactors of `feed_service.dart` cannot silently break PRD guarantees.

## Starting Point

`feed_service_test.dart` has 8 unit tests covering `pickyFactor`, `rejectProbability`, `clampStat`, and 4 `evaluateFeed` scenarios — no oracle mirrors found. `mutation_test` is not in dev_dependencies; no config exists. `_ScriptedRandom` is copy-pasted identically in two test files.

## Desired End State

Three new tests pass in `dart test test/unit/`; a scoped mutation gate reports 0 unaddressed business-impactful survivors against `feed_service.dart`; `test-plan.md §6.1` carries the cookbook pattern for this module.

## Key Decisions Made

| Decision | Choice | Why | Source |
|---|---|---|---|
| `_ScriptedRandom` extraction | Extract to `test/helpers/scripted_random.dart` | Eliminates copy-paste before Phases 2/3 add more tests | Plan |
| mutation_test scope | `feed_service.dart` only | Test plan §4 specifies this; `deriveMood` covered separately | Research / Test Plan |
| Post-feed mood unit test | Skip | 9 existing boundary cases bracket all post-feed states; integration covers E2E | Research |
| mutation_test version | `^1.8.0` | Semver conventional for dev dependencies | Plan |
| Config format | XML (`<mutations version="1.2">`) | Confirmed from pub.dev docs | Plan |
| mutation gate in CI | No — ad-hoc local only | Test plan §4 explicit | Test Plan |

## Scope

**In scope:**
- `mutation_test: ^1.8.0` dev dependency + `tamagotchi_server/mutation_test.xml`
- `test/helpers/scripted_random.dart` (new shared helper)
- 3 new tests in `feed_service_test.dart` (hunger=1 edge, Random(seed) reproducibility, opposite-trait)
- Import update in `feed_endpoint_test.dart` (no new tests)
- `test-plan.md §6.1` cookbook entry + `§6.6` phase note
- `mutation_out/` added to `.gitignore`

**Out of scope:** Endpoint changes, Flutter changes, CI mutation gate, Phases 2-4 of rollout.

## Architecture / Approach

All new tests call `evaluateFeed()` directly — pure top-level function, no seam required. The `Random(seed)` reproducibility test injects real Dart seeded PRNGs; the other two tests use `ScriptedRandom` (scripted queue). The mutation gate runs the unit suite only via the XML `<command>` directive; Postgres is never booted.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. mutation_test infrastructure | Dep + config; dry-run verified | XML format mismatch (mitigated — format confirmed from pub.dev) |
| 2. Helper + 3 new tests | All tests pass; integration not broken | Import refactor breaks integration test (mitigated by Phase 2.4 check) |
| 3. Mutation gate | 0 unaddressed survivors; equivalents documented | Unexpected high survivor count requiring many new assertions |
| 4. Cookbook update | §6.1 filled; rollout Phase 1 closed | — |

**Prerequisites:** None (no external deps, no migrations). Phase 2.4 integration regression check requires the Postgres sidecar up.
**Estimated effort:** ~1 session across 4 phases (Phase 3 duration depends on triage findings).

## Open Risks & Assumptions

- The `hunger <= 0` → `hunger == 0` mutation is assumed equivalent (`clampStat` guarantees non-negative hunger); will be confirmed during Phase 3 triage.
- If mutation_test yields >5 business-impactful survivors, Phase 3 expands. Unlikely given the existing suite's quality.

## Success Criteria (Summary)

- `dart test test/unit/` passes with 3 new tests; `dart test test/` passes (no integration regression).
- `mutation_out/index.html` shows 0 unaddressed business-impactful survivors.
- `test-plan.md §6.1` is actionable to a reader who wasn't part of this session.
