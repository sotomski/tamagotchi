# Test Plan

> Phased test rollout for this project. Strategy is frozen at the top
> (§1–§5); cookbook patterns at the bottom (§6) fill in as phases ship.
> Read before writing any new test.
>
> Refresh: re-run `/10x-test-plan --refresh` when stale (see §8).
>
> Last updated: 2026-06-05

## 1. Strategy

Tests follow three non-negotiable principles for this project:

1. **Cost × signal.** The cheapest test that gives a real signal for the
   risk wins. Do not promote to an integration/endpoint test because it
   "feels safer." Do not put a live LLM call inside a test that a seeded
   stub + deterministic assertion already covers.
2. **User concerns are first-class evidence.** Risks anchored in "the
   maker is worried about X, and the failure would surface somewhere in
   `<area>`" carry the same weight as PRD lines or hot-spot data.
3. **Risks are scenarios, not code locations.** This plan documents *what
   could fail* and *why we believe it's likely* — drawn from documents,
   interview, and codebase *signal* (churn, structure, test base). It does
   NOT claim to know which line owns the failure. That knowledge is
   produced by `/10x-research` during each rollout phase. If the plan and
   research disagree about where the failure lives, research is the
   ground truth.

Hot-spot scope used for likelihood weighting: `tamagotchi_server/lib/src`,
`tamagotchi_flutter/lib` (excluding `generated/` and `protocol/` codegen).

## 2. Risk Map

The top failure scenarios this project must protect against, ordered by
risk = impact × likelihood. Risks are failure scenarios in user / business
terms, not test names. The Source column cites the *evidence that surfaced
this risk* — never a specific file as "where the failure lives" (that is
research's job, see §1 principle #3).

| # | Risk (failure scenario) | Impact | Likelihood | Source (evidence — not anchor) |
|---|-------------------------|--------|------------|--------------------------------|
| 1 | Feed **determinism contract** breaks: the same personality traits + same care sequence + same seed produce different stat/mood magnitudes, so "two opposite-trait creatures end measurably different" stops being reproducible. | High | High | PRD §Success Criteria + §Guardrails ("stats are deterministic given inputs"); FR-004; interview Q3; hot-spot dir `tamagotchi_server/lib/src/creature/` (18 commits/30d) |
| 2 | **Accept/refuse gate** stops varying by pickiness/hunger (a picky creature always accepts or always refuses), a full creature is fed anyway, or the seeded roll order changes and breaks reproducibility. | High | High | PRD FR-004 ("a picky creature won't always accept food") + §Success Criteria ("character genuinely affects gameplay"); interview Q3; hot-spot dir `tamagotchi_server/lib/src/creature/` (18 commits/30d) |
| 3 | **Non-atomic Feed save**: the stat update commits but the journal insert fails (or the reverse), leaving a creature with mutated stats and no journal entry — violating FR-009's "coherent pair." | High | Medium | interview Q4; FR-009 |
| 4 | **Stub-vs-real divergence**: the deterministic layer is green against stubs while the real endpoint + generated-client + DB write path is broken (serialization, auth, or constraint). | High | Medium | interview Q2 (lived incident: "a mock lied vs the real RPC"); `context/foundation/lessons.md` (provider-override widget-test pattern) |
| 5 | **Ownership / IDOR**: the Feed / creature / journal surface authorizes "is logged in" but not "this creature is yours," so one user can read or mutate another user's creature or journal. | High | Medium | PRD §Access Control ("can only see and interact with their own"); abuse lens |
| 6 | **Personality / guardrail breach**: the creature emits a generic-chatbot or safety-disclaimer reply, or responses don't reflect traits — two creatures feel identical and the core hypothesis silently fails. | High | Medium | PRD §Success Criteria + §Guardrails ("never breaks character"); interview Q1 ("interaction isn't engaging/fun"); FR-009 |
| 7 | **LLM failure unhandled + leakage**: a Mistral timeout/error hangs the Feed (no bounded HTTP timeout) or surfaces a raw 5xx; the raw upstream body (potentially key context / PII) lands in logs. | High | Medium | impl-review findings F1 (no Mistral HTTP timeout) + F2 (raw upstream body in logs), recorded in roadmap S-03 status; interview Q1; abuse lens (secret/PII leakage + resource abuse) |

**Impact × Likelihood rubric.** Score both axes on a coarse High / Medium /
Low scale so two readers agree on the same row.

| Rating | Impact | Likelihood |
|--------|--------|------------|
| High   | user loses access, data, or money; failure is publicly visible | area changes weekly, or we have already been burned here |
| Medium | feature degrades, a workaround exists, only some users affected | touched occasionally, has been a source of bugs |
| Low    | cosmetic, easily reverted, no data effect | stable code, rarely touched |

Order is by impact × likelihood: R1/R2 (H×H) first, then R3–R7 (H×M).
A note on the deferred concern in interview Q1 ("the interaction isn't
engaging/fun"): "fun" itself is not unit-testable. Its testable *faces* are
captured by R6 (in-character + visible personality variety) and R7 (a
hanging/erroring Feed is not fun); the subjective judgment stays a manual /
AI-native eval (see §3 Phase 4), not an automated regression gate. Runaway
LLM-cost abuse (resource lens) is partially mitigated by the refusal path
making no LLM call (R7) and is fully addressed by the future empty-energy
gate slice (roadmap S-06), not by a separate risk row here.

### Risk Response Guidance

| Risk | What would prove protection | Must challenge | Context `/10x-research` must ground | Likely cheapest layer | Anti-pattern to avoid |
|------|-----------------------------|----------------|--------------------------------------|-----------------------|-----------------------|
| #1 | Same seed + same inputs → identical stat/mood magnitudes; two opposite-trait creatures over the same care sequence → measurably different end states. | "The magnitudes look right" — expected values must come from FR-004 rules / domain, not from current output. | The deterministic stat formula, the seed plumbing, and how mood is derived from stats. | Unit (seeded RNG) | Implementation mirror: re-deriving the expected delta with the code's own formula. |
| #2 | The gate is *monotonic*: hungrier → less likely to refuse, pickier → more likely; a full creature is always rejected; same seed → same accept/refuse outcome. | "A happy-path feed succeeded ⇒ the gate works." | Roll order (tastiness then reject), `pickyFactor` derivation, the full-creature short-circuit. | Unit (seeded RNG) | Mirror: re-computing `P(reject)` with the same formula inside the assertion. |
| #3 | When the journal insert fails, the Feed does not leave half-applied state — it rolls back, or has a documented/observable orphan-handling path. | "It's already wrapped in a transaction" — verify it actually is. | Whether the stat-write + journal-write are atomic; the transaction boundary. | Hermetic (stub forces the 2nd operation to fail) | Integration test that cannot force a mid-sequence failure (real infra won't trigger it). |
| #4 | The real endpoint Feed (auth → serialize → DB stat write → journal write) succeeds end-to-end through the generated client against a real DB. | Re-stubbing the client inside the "integration" test. | Real endpoint signature, DB fixtures, session/auth shape under `serverpod_test`. | Integration (real DB) | Faking the client — the exact "mock lied" trap from interview Q2. |
| #5 | A non-owner's Feed / read of another user's creature or journal is denied — not merely the unauthenticated case. | "Logged-in ⇒ authorized." | Where the ownership check lives; how a creature is keyed to its user. | Integration (two sessions, real DB) | Asserting only the owner's success, never the non-owner's denial. |
| #6 | The prompt carries the inputs that *make* a reply in-character (traits + current stats + interaction + last-N journal entries); the structured reply parses to two non-empty fields; a refusal makes **no** LLM call. | Asserting that a reply "feels" in-character inside code. | The prompt-assembly contract; the structured-output schema; the refusal branch. | Unit / contract (+ flagged manual / AI-native eval) | Oracle problem: asserting exact LLM prose wording. |
| #7 | An LLM timeout/error produces a clean, bounded failure (no infinite spinner), and no raw upstream body or secret appears in logs. | "A 200 means everything's fine" / "log everything for debugging." | HTTP client timeout configuration; exactly what is logged on the error path. | Hermetic (stub throws / times out) | Asserting a specific log string instead of the *absence* of secret / raw body. |

## 3. Phased Rollout

Each row is a discrete rollout phase that will open its own change folder
via `/10x-new`. Status moves left-to-right through the values below; the
orchestrator updates Status as artifacts appear on disk.

| # | Phase name | Goal (one line) | Risks covered | Test types | Status | Change folder |
|---|------------|-----------------|---------------|------------|--------|---------------|
| 1 | Feed determinism + accept/refuse gate | Lock the PRD determinism contract and the gate's monotonicity/reproducibility, then prove it with a scoped `mutation_test` pass. | #1, #2 | unit (seeded RNG) + mutation gate | not started | — |
| 2 | Feed partial-failure & LLM-failure hardening | Partial-save and LLM-outage branches fail cleanly with no secret/raw-body leak (closes deferred findings F1/F2). | #3, #7 | hermetic stub | not started | — |
| 3 | Real-path integration: Feed endpoint + ownership | The real endpoint+DB Feed works end-to-end and a non-owner is denied. | #4, #5 | integration (real DB) | not started | — |
| 4 | Personality contract: prompt assembly + structured response | The prompt carries the personality inputs, the reply parses, and a refusal makes no LLM call; subjective in-character judgment stays a flagged manual/AI eval. | #6 | unit / contract | not started | — |

**Status vocabulary** (fixed — parser literals):

| Value | Meaning |
|-------|---------|
| `not started` | No change folder for this rollout phase yet. |
| `change opened` | `context/changes/<id>/` exists with `change.md`; research not done. |
| `researched` | `research.md` exists in the change folder. |
| `planned` | `plan.md` exists with a `## Progress` section. |
| `implementing` | Progress section has at least one `[x]` and at least one `[ ]`. |
| `complete` | Progress section is fully `[x]`. |

Every phase targets the already-shipped S-03 Feed slice (the north star) —
this rollout hardens the proof, it does not stake out the unbuilt S-04–S-09.
The deterministic stat layer that Phase 1 pins is reused by S-04 (Pet) and
S-05 (Cure), so the cheapest gate lands earliest and pays forward.

## 4. Stack

The classic test base for this project. AI-native tools (if any) carry a
`checked:` date so future readers can see which lines need re-verification.

| Layer | Tool | Version | Notes |
|-------|------|---------|-------|
| unit + integration (server) | `package:test` + `serverpod_test` | test ^1.31.0 / serverpod_test 3.4.8 | integration tests need the docker-compose Postgres sidecar (`postgres_test:5432`) up before `dart test`; run with `SERVERPOD_PASSWORD_database=<test pw>` |
| widget / unit (Flutter) | `flutter_test` | SDK-bundled | async Riverpod surfaces tested via provider overrides, never a real RPC (see `lessons.md`) |
| seeded determinism | injected `Random(seed)` via the `feedServiceFactory` seam | n/a | reproducible accept/refuse roll for R1/R2; not a package |
| mutation gate (selective) | `mutation_test` | 1.8.0 | **ad-hoc local only, not in CI.** Scoped to `feed_service.dart` against the fast unit suite (not full `dart test` — must not boot Postgres). XML config sets the filtered test command. Closes Phase 1. |
| API mocking | none (hermetic stubs) | n/a | LLM + RNG injected through the single production-default `feedServiceFactory` seam; tests reassign it. No HTTP-edge mocking library in use. |
| e2e | none | n/a | not planned for this rollout — energy-gated, single-user web app; integration (real DB) is the top layer here. |

**Stack grounding tools (current session):**
- Docs: context7 MCP — available; confirms Serverpod 3.4.x / Riverpod 3.x / Flutter test APIs and is the source for `serverpod_test` harness specifics; checked: 2026-06-05
- Search: WebSearch / WebFetch — available; used to verify `mutation_test` 1.8.0 capabilities (XML config, `dart test` default, per-file scoping, HTML report) on pub.dev; checked: 2026-06-05
- Runtime/browser: none — not available in current session; not used
- Provider/platform: none — Serverpod Cloud (`scloud`) and Mistral are runtime deps, no read-only quality-gate MCP in session; not used

Use docs MCPs for current framework/library APIs and setup details. Use
search MCPs for discovery or current status only, then prefer official docs
as the evidence. Do not use MCP docs/search to infer code failure anchors;
those belong in per-phase `/10x-research`.

## 5. Quality Gates

The full set of gates that must pass before a change reaches production.
"Required for §3 Phase `<N>`" means the gate is enforced once that rollout
phase lands; before that, the gate is `planned`.

| Gate | Where | Required? | Catches |
|------|-------|-----------|---------|
| `dart analyze` (`--fatal-infos`) | local + CI (`analyze.yml`, `flutter.yml`) | required | syntactic / type drift |
| `dart format --set-exit-if-changed` | local + CI (`format.yml`, `flutter.yml`) | required | formatting drift (separate gate from analyze — see `lessons.md`) |
| unit (seeded) | local + CI (`tests.yml`) | required after §3 Phase 1 | Feed determinism + gate regressions (R1/R2) |
| `mutation_test` scoped to `feed_service.dart` | local (ad-hoc) | recommended after §3 Phase 1 | weak/absent assertions on the stat math + gate |
| hermetic partial-failure tests | local + CI (`tests.yml`) | required after §3 Phase 2 | non-atomic save + LLM-failure branches (R3/R7) |
| integration (real DB) | local + CI (`tests.yml`, Postgres sidecar) | required after §3 Phase 3 | stub-vs-real divergence + IDOR (R4/R5) |
| prompt-assembly / structured-parse contract | local + CI (`tests.yml`) | required after §3 Phase 4 | prompt drops a personality input; reply fails to parse (R6) |
| in-character manual / AI-native eval | manual, between merge + prod | optional | subjective personality / guardrail breach (R6 face that resists automation) |

## 6. Cookbook Patterns

How to add new tests in this project. Each sub-section is filled in once
the relevant rollout phase ships; before that, the sub-section reads
"TBD — see §3 Phase `<N>`."

### 6.1 Adding a unit test (seeded determinism)

**Test file:** `tamagotchi_server/test/unit/feed_service_test.dart`

**Seam:** `evaluateFeed()` is a pure top-level function — call it directly, no seam or session required. For endpoint-level tests that need scripted draws, reassign the `feedServiceFactory` seam (see `§6.3` when it ships).

**Scripted draws:** Use `ScriptedRandom(const [<doubles>])` from `test/helpers/scripted_random.dart` to pin the exact `[tastiness, reject_roll]` sequence. The helper throws `StateError` if drawn past the end — an empty queue (`const []`) turns "no draws" into an assertable property. For reproducibility assertions (same seed → same output), use two independent `Random(seed)` instances and assert pairwise equality; do **not** assert specific double values (the oracle is equality, not a particular outcome).

**Oracle source:** FR-004 domain rules and the named constants `feedHungerDrop` / `feedEnergyCost` — never derive the expected delta by calling the function under test or re-computing the formula inside the assertion. If the expected value isn't derivable from the spec, stop and look it up in research before writing the assertion.

**Anti-pattern to avoid:** asserting specific `tastiness` doubles from a seeded PRNG call. Even if the value is stable today, it's not part of any contract.

**Mutation gate:** After adding new assertions for `feed_service.dart`, run:
```
dart run mutation_test -f md -o mutation_out mutation_test.xml
```
from `tamagotchi_server/`. Open `mutation_out/mutation-test-report.md`; add assertions only for business-impactful survivors. Document equivalent mutants in the XML `<exclude>` block with a rationale comment (see `tamagotchi_server/mutation_test.xml`).

**XML gotcha:** The `<command>` element text must start immediately after the opening tag with no leading whitespace — see `context/foundation/lessons.md` for the root cause.

### 6.2 Adding a hermetic partial-failure test

- TBD — see §3 Phase 2. Will document: reassigning the `feedServiceFactory`
  seam to a stub that fails the second operation / throws / times out, and
  asserting clean failure + absence of secret/raw body in logs.

### 6.3 Adding an integration test (real DB)

- TBD — see §3 Phase 3. Will document the `withServerpod` harness, the
  Postgres sidecar prerequisite, and the two-session ownership pattern.
- Reference test today: `tamagotchi_server/test/integration/feed_endpoint_test.dart`.

### 6.4 Adding a test for a new API endpoint

- TBD — see §3 Phase 3. Preferred type: integration via `withServerpod`
  against the real DB; assert request → response shape AND DB side-effects;
  cover the non-owner denial, not just the owner's success.

### 6.5 Adding a contract test for the LLM prompt / response

- TBD — see §3 Phase 4. Will document: asserting the prompt carries
  {traits, stats, interaction, last-N journal entries} and the structured
  reply parses to two non-empty fields — never asserting exact prose.
- Reference tests today: `tamagotchi_server/test/llm/creature_prompt_test.dart`,
  `tamagotchi_server/test/llm/feed_copy_test.dart`.

### 6.6 Per-rollout-phase notes

(Optional. After each phase lands, `/10x-implement` appends a 2-3 line note
here capturing anything surprising the rollout phase taught.)

**Phase 1 (Feed determinism + accept/refuse gate, 2026-06-06):** The two test files each had a private `_ScriptedRandom` class — extracting to a shared helper at `test/helpers/scripted_random.dart` was necessary before adding new tests. The `mutation_test` XML `<command>` element requires the command text immediately after the opening tag with no leading whitespace (the parser splits on single spaces, turning indented text into an empty executable string — a gotcha recorded in `lessons.md`). All 19 mutations in `feed_service.dart` were killed by the suite with 0 survivors; the anticipated `hunger == 0` → `<= 0` equivalent mutant was not generated by the builtin rules, so no `<exclude>` block was needed.

## 7. What We Deliberately Don't Test

Exclusions agreed during the rollout (Phase 2 interview, Q5). Future
contributors should respect these unless the underlying assumption changes.

- **Generated client / protocol** (`tamagotchi_client`, `tamagotchi_server/lib/src/generated`) — codegen output; the generator is the test. Re-evaluate only if we hand-edit generated code (which CLAUDE.md forbids). (Source: Phase 2 interview Q5.)
- **Exact LLM prose wording** — non-deterministic; asserting specific response strings is brittle and meaningless. Test the prompt-assembly + structured-parse contract instead (R6). Re-evaluate if we move to a deterministic/canned-response mode. (Source: Phase 2 interview Q5.)
- **Auth-module internals** (`serverpod_auth_idp` token issuance, password hashing) — third-party module; trust it, test only our usage of it (e.g. ownership in R5). Re-evaluate if we fork or configure the module non-trivially. (Source: Phase 2 interview Q5.)
- **Serverpod web marketing routes** (`tamagotchi_server/lib/src/web/`) — boilerplate, low blast radius, not product-critical. Re-evaluate if a real user-facing web route is added there. (Source: Phase 1 negative-space inference; consistent with Q5.)

## 8. Freshness Ledger

- Strategy (§1–§5) last reviewed: 2026-06-05
- Stack versions last verified: 2026-06-05
- AI-native tool references last verified: 2026-06-05

Refresh (`/10x-test-plan --refresh`) when:

- a new top-3 risk surfaces from the roadmap or archive,
- a recommended tool's `checked:` date is older than three months,
- the project's tech stack changes (new framework, new test runner),
- §7 negative-space no longer matches what the team believes.
