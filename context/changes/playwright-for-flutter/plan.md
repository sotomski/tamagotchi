# Patrol e2e for Flutter web (M3L4 contract) Implementation Plan

## Overview

Stand up **patrol** (Dart-native browser e2e; internal Playwright/Chromium
bridge) on this Flutter web app, prove it runs headless on Linux in the
devcontainer, author project-local **quality levers** (a seed patrol test + a
patrol E2E rules file), and land **one** risk-tied browser test — the Feed
persistence flow — through the M3L4 loop (PLAN → GENERATE → REVIEW against the
five anti-patterns → VERIFY by deliberate break). **marionette** is wired as a
built AI-exploration assist. CI is deferred (documented follow-up). Raw
Playwright is *not* used (CanvasKit shadow-DOM friction — see `frame.md`).

## Current State Analysis

- **No e2e today.** `test-plan.md §4` says `e2e: none`; `§7` lists e2e as a
  deliberate exclusion. The top test layer is integration (real DB) via
  `withServerpod`. This change adds a browser layer that hardens the already-
  shipped S-03 Feed slice — it does not revise the rollout philosophy.
- **The app boots without `docker compose up`.** `.devcontainer/docker-compose.yml`
  `include`s `tamagotchi_server/docker-compose.yaml` and the `dev` service
  `depends_on: postgres`, so the dev DB (`postgres` → `tamagotchi`) **and**
  `postgres_test` (→ `tamagotchi_test`) are **always running** while the
  devcontainer is up. e2e needs only the Serverpod API (`:8080`) started; patrol
  builds + serves the Flutter web tier itself (`flutter run -d web-server`).
- **The LLM mock is a key-presence seam, not run mode.** `llmServiceFor()`
  (`llm_service.dart:77-88`) returns `StubLlmService` when `mistralApiKey` is
  absent/empty. **Correction to research:** `mistralApiKey` **is present** in the
  `development` section of `config/passwords.yaml` (gitignored, local) — so plain
  `development` mode hits the real Mistral API. We get the stub via a dedicated
  `e2e` runmode whose passwords section omits the key.
- **patrol finds widgets on the Flutter tree, not the DOM** — so `ensureSemantics()`
  / ARIA `Semantics` are **not** needed. The UI has **zero `Key`s** today;
  ~13/20 interactive elements are text-findable, ~7 need a net-new `Key`.
- **Auth is stateless JWT** (`serverpod_auth_idp`); **dev fixed verification code
  `'12345678'`** (`server.dart:18,34`) lets sign-up complete without a mailer —
  but that gate is `runMode == 'development'`, so the `e2e` runmode must extend it.
- **The `10x-e2e` skill will halt** on this repo (Setup STOPs with no
  `playwright.config.*`/`*.spec.ts`; `allowed-tools` hardwire `mcp__playwright__*`).
  We keep its **contract** and author patrol levers — its "Other stacks" section
  licenses exactly this. **We do not modify the skill or its references.**
- **Devcontainer gaps:** Node v24 + Flutter 3.44 present; **no Chromium binary,
  no `patrol_cli`**.

### Key Discoveries

- `tamagotchi_server/lib/src/llm/llm_service.dart:77-88` — key-presence stub seam.
- `tamagotchi_server/config/passwords.yaml` — `development:` section contains
  `database` + `mistralApiKey`; `test:` has only `database`; `shared:` has the
  two peppers. **Gitignored, local-only.**
- `tamagotchi_server/lib/server.dart:34,113,137` — three `runMode == 'development'`
  gates (fixed verification code + log-only email callbacks) the `e2e` runmode
  must also satisfy.
- `tamagotchi_server/config/{development,test}.yaml` — ports (dev fixed 8080/8081/8082;
  test dynamic `0`); DB hosts `postgres` vs `postgres_test`.
- `tamagotchi_flutter/lib/creature/{creature_view.dart,hatch_form.dart}`,
  `lib/home/home_screen.dart`, `lib/auth/sign_in_screen.dart` — the `Key` inventory
  (Phase 2) and the third-party `SignInWidget` black box (Phase 3 soft spot).
- `tamagotchi_flutter/lib/main.dart:19,23-32` — `WidgetsFlutterBinding`
  (the marionette hook, Phase 5) + `getServerUrl()` → bundled `config.json`
  → `http://localhost:8080`.
- `tamagotchi_server/test/integration/feed_endpoint_test.dart:42-48,99` —
  in-process seeding/auth patterns (the contrast; not reusable out-of-process).

## Desired End State

From the devcontainer (sidecars already running):

```
dart bin/main.dart --mode e2e --apply-migrations      # tamagotchi_test, stub LLM, fixed code
patrol test --target integration_test/feed_persistence_test.dart -d chrome --web-headless
```

…boots the API on `:8080` against `tamagotchi_test` with the deterministic stub,
patrol serves + drives the Flutter web app in headless Chromium, and the
persistence test goes **green**; deliberately breaking the persistence path turns
it **red**. The two quality levers exist; ~7 `Key`s annotate the UI; marionette
can drive a debug build (or its web limitation is documented); `test-plan.md` and
`tech-stack.md` reflect `e2e: patrol`.

## What We're NOT Doing

- **No raw Playwright / TypeScript / `ensureSemantics()` / ARIA `Semantics`** —
  patrol works on the widget tree (frame decision).
- **No R5 ownership/IDOR at the browser level** — stays an integration concern
  (scope = persistence happy-path only).
- **No hatch flow or refusal-edge as e2e** — the creature is DB-seeded (hatch is
  precluded by the one-creature-per-account unique index and is integration-
  covered); refusal is deterministic and unit-covered.
- **No JWT-into-localStorage injection** — deferred optimization; we use a
  login-once helper.
- **No CI e2e job in this change** — local-only; CI wiring is a documented
  follow-up (mirrors `mutation_test`'s "ad-hoc local only").
- **No edits to `.claude/skills/10x-e2e/`** — levers are project-local.
- **No Mistral base-URL override / HTTP-layer mock** — the `e2e` runmode's
  absent key gives the stub for free.
- **No testing of the Serverpod-served `/app` route** — patrol serves its own
  web build; that route is irrelevant under patrol.
- **No new `/10x-test-plan` rollout phase** — this hardens S-03; we only flip the
  `§4`/`§7` stack entries.

## Implementation Approach

Spike-first. The riskiest unknown — **does patrol run headless Chromium on Linux
in this container at all** — is proven in Phase 1 with a trivial smoke test
before any real test work. The second soft spot — **authenticated session reuse
on patrol web** — gets its own phase (3) with a fully specified primary path and
fallback, so it is a decision rule, not an open question. The single risk-tied
test (4) then composes the proven toolchain (1), affordances + levers (2), and
harness (3). marionette (5) and docs (6) follow. Each phase ends green and
committed; phases are independently resumable via the shared `## Progress`.

## Critical Implementation Details

- **State sequencing — the stub gate is load-bearing.** The e2e server MUST boot
  in the `e2e` runmode (no `mistralApiKey`) *before* any test runs; booting plain
  `development` hits the real Mistral API and breaks determinism + costs money.
  Equally, `server.dart`'s fixed-verification-code gate must include `e2e`
  *before* sign-up is attempted, or UI auth dead-ends waiting for a mailer.
- **Postgres is already up — never `docker compose up` for e2e.** The sidecars are
  part of the devcontainer's compose project. e2e uses **`tamagotchi_test`**
  (host `postgres_test`), isolating its committed rows from the dev DB and from
  integration tests (which roll back).
- **Timing/lifecycle (patrol web gotchas).** No develop/watch mode on web
  (run-once per `patrol test`). Subscribe to native dialogs (`acceptNextDialog()`)
  *before* triggering them. Linux-web parity is under-documented — Phase 1 proves
  it empirically (exit codes, artifact paths included).
- **Debug & observability.** Capture a patrol screenshot on failure as evidence;
  in the Phase 1 smoke run, check the browser console for CORS errors
  (patrol origin → `:8080` is cross-origin and unverified).

---

## Phase 1: Patrol toolchain + Linux-web smoke proof

### Overview

Install the toolchain, create the `e2e` runmode, and prove patrol can drive
headless Chromium against the served app in this container — the gate for
everything downstream.

### Changes Required

#### 1. Devcontainer image — patrol_cli + Chromium

**File**: `.devcontainer/Dockerfile`

**Intent**: Make `patrol_cli` and a headless-capable Chromium present on every
rebuild (the chosen "bake into Dockerfile" persistence strategy), alongside the
already-pinned Flutter/Serverpod CLIs.

**Contract**: In the `vscode`-user `RUN` block, `dart pub global activate patrol_cli`;
in a root-privileged step (or via the Node feature's npx) run
`npx playwright install --with-deps chromium` so the apt OS libs land. Requires a
**devcontainer rebuild** (manual). Runtime invocation uses `--ipc=host --init`
(document in the cookbook, Phase 6).

#### 2. patrol dependency + config

**File**: `tamagotchi_flutter/pubspec.yaml`, `tamagotchi_flutter/integration_test/`

**Intent**: Add patrol as a dev dependency and its config so `patrol test` is
runnable.

**Contract**: `flutter pub add patrol --dev`; add the `patrol` config block
(app name / config per patrol web docs); create the `integration_test/` directory
patrol expects. Run `patrol doctor` to confirm the web toolchain resolves.

#### 3. The `e2e` runmode config

**File**: `tamagotchi_server/config/e2e.yaml` (new)

**Intent**: A runmode that boots the API on the fixed `:8080` the patrol-served
app expects, against the already-running `tamagotchi_test` DB.

**Contract**: Mirror `development.yaml`'s fixed ports (apiServer 8080, insights
8081, web 8082, real `publicHost`/scheme) but set the `database` block to
`host: postgres_test`, `name: tamagotchi_test`, `user: postgres` (matching
`test.yaml`). `redis.enabled: false`.

#### 4. The `e2e` passwords section

**File**: `tamagotchi_server/config/passwords.yaml` (local, gitignored)

**Intent**: Supply only the secrets the e2e server needs — crucially **omitting
`mistralApiKey`** so the stub is selected.

**Contract**: Add an `e2e:` section with `database:` = the `postgres_test`
password (from `tamagotchi_server/docker-compose.yaml`). Peppers come from
`shared:`. **No `mistralApiKey`.** Verify by booting `--mode e2e` and completing a
sign-in that JWT issuance needs nothing beyond `shared` + `e2e.database` (if the
JWT/auth config reads a dev-only password, add it here). Document this local step
in the cookbook (Phase 6) since the file is gitignored.

#### 5. Extend the dev-only run-mode gates to `e2e`

**File**: `tamagotchi_server/lib/server.dart`

**Intent**: Make `e2e` behave like `development` for the no-mailer conveniences:
fixed verification code + log-only email callbacks.

**Contract**: Replace the three `runMode == 'development'` checks (l.34 config
selection, l.113 + l.137 send-callback log-only branch) with a single predicate
covering `{'development', 'e2e'}`.

```dart
bool _isLocalDevMode(String runMode) =>
    runMode == 'development' || runMode == 'e2e';
```

#### 6. Smoke test (toolchain canary)

**File**: `tamagotchi_flutter/integration_test/smoke_test.dart` (new)

**Intent**: The minimal proof that patrol builds + serves the app and drives
headless Chromium — *not* a risk-tied test and *not* the seed.

**Contract**: A single patrol test that pumps the app and asserts the Sign-in
screen renders (`$('Sign in')` / the `SignInWidget`). Run via
`patrol test --target integration_test/smoke_test.dart -d chrome --web-headless`.
Confirms Linux-web parity + that the served app reaches `:8080` (CORS).

### Success Criteria

#### Automated Verification

- Devcontainer rebuilds with `patrol --version` and `chromium`/Playwright present.
- `patrol doctor` reports the web toolchain ready.
- `dart analyze` clean after the `server.dart` change.
- e2e server boots: `dart bin/main.dart --mode e2e --apply-migrations` connects to
  `tamagotchi_test` and listens on `:8080`.
- Smoke test passes: `patrol test --target integration_test/smoke_test.dart -d chrome --web-headless`.

#### Manual Verification

- Headless Chromium runs under the container's CPU/memory (no OOM/crash).
- No CORS error in the browser console (patrol origin → `:8080`); if present,
  note the Serverpod CORS config tweak needed.
- The e2e server log shows `StubLlmService` selection (or simply no Mistral
  call) — confirming `mistralApiKey` is absent in `e2e`.
- Note patrol's exit code + artifact (screenshot/log) paths for the cookbook.

**Implementation Note**: After automated verification passes, pause for manual
confirmation before Phase 2.

---

## Phase 2: Widget Keys + quality levers

### Overview

Add the stable finders patrol needs and the two quality levers that shape every
generated test — landed before the first real test, per the skill.

### Changes Required

#### 1. Net-new widget `Key`s (~7)

**File**: `tamagotchi_flutter/lib/creature/hatch_form.dart`,
`tamagotchi_flutter/lib/creature/creature_view.dart`,
`tamagotchi_flutter/lib/home/home_screen.dart`

**Intent**: Give invisible/ambiguous elements stable finders so tests assert
loading/wait states and specific stat changes without brittle widget-tree
indices.

**Contract**: Add `Key`s per the research inventory — hatch name field
(`hatch_form.dart:59`), hatch button (`:76`), feed button (`creature_view.dart:58`),
the three spinners (`hatch_form.dart:72`, `home_screen.dart:41`,
`creature_view.dart:92`), the feed-response container (`creature_view.dart:119`),
and the per-stat value rows (`creature_view.dart:44-47`). Keep visible text intact
(prefer Key + text). Stable, descriptive key strings (e.g. `Key('feedButton')`,
`Key('feedingIndicator')`, `Key('statRow-Hunger')`).

#### 2. Patrol seed test (lever #1, project-local)

**File**: `tamagotchi_flutter/integration_test/seed_test.dart` (new)

**Intent**: The exemplar every generated patrol test is modeled on — *what the
seed shows is what gets generated*. Adapts `references/seed-test-pattern.md` to
patrol/Dart.

**Contract**: Demonstrates the four patterns in patrol idiom: (a) Key/semantic-
text finders (`$(#feedButton)` / `$('Feed')`), never `byType`/index; (b) full
self-contained cycle (setup → action → assertion → cleanup) with a unique
timestamped identifier; (c) wait-for-state (`$.pumpAndSettle()` /
`waitUntilVisible()`), never a fixed delay; (d) a risk-tied test name. Carries a
provenance header linking to the protected risk and to itself as the seed.

#### 3. Patrol E2E rules file (lever #2, project-local)

**File**: `tamagotchi_flutter/integration_test/E2E_RULES.md` (new)

**Intent**: The rules the agent reads before generating a patrol test — the
Playwright→patrol mapping baked in so generated tests are idiomatic and stable.

**Contract**: Encode `references/e2e-quality-rules.md` translated to patrol: Key +
visible-text finders over `byType`/index; `pumpAndSettle`/`waitUntilVisible` not
fixed delays; independent + uniquely-keyed data + teardown; assert the business
outcome; **real boundaries (auth/routing/DB) stay real, the server-side Mistral
call is mocked at the `e2e`-runmode key-presence seam, not in the browser**; name
the test after the risk.

### Success Criteria

#### Automated Verification

- `dart analyze` clean after adding `Key`s.
- `dart format --set-exit-if-changed` clean on touched Dart files.
- Existing widget tests still pass (`flutter test`) — Keys don't break them.
- `seed_test.dart` compiles and runs green via `patrol test`.

#### Manual Verification

- The seed test reads as a faithful patrol translation of the four patterns
  (would be a good model to clone).
- `E2E_RULES.md` covers all five anti-patterns + the real-vs-mocked boundary in
  patrol terms.

**Implementation Note**: Pause for manual confirmation before Phase 3.

---

## Phase 3: Backend harness — DB-seed + login-once auth

### Overview

Establish deterministic seeded state and a real authenticated browser session —
the storageState equivalent and the change's top risk.

### Changes Required

#### 1. e2e seed/teardown script

**File**: `tamagotchi_server/tool/e2e_seed.dart` (new)

**Intent**: Create a deterministic test **user** (via the auth module, so
credentials validate and a JWT can issue) and **creature** (via
`Creature.db.insertRow`) in `tamagotchi_test`, with a teardown by unique id.

**Contract**: Opens a Serverpod session against the `e2e` runmode DB; creates the
user through `serverpod_auth_idp_server`'s email account-creation path with a
unique timestamped email + the dev fixed code; inserts a `Creature`
(+`CreaturePersonality`) keyed to that user's `userIdentifier` (one-per-account
unique index). Exposes seed + teardown so a run is re-runnable. Mirrors the
in-process seeding in `feed_endpoint_test.dart:42-48` but for an out-of-process DB.

#### 2. Login-once helper

**File**: `tamagotchi_flutter/integration_test/helpers/auth.dart` (new)

**Intent**: Populate the browser session once so the test starts authenticated —
the storageState equivalent.

**Contract**: A patrol helper that drives `SignInWidget` (found by text — it's a
third-party black box, `sign_in_screen.dart:24`) with the seeded credentials,
then waits for the authenticated home (`$('AI-Tamagotchi')`). **Primary path:**
seed via the script (#1) + login-once here. **Fallback (specified, not open):** if
programmatic auth-module user creation or login-once proves intractable on patrol
web, register a fresh unique user through the UI sign-up flow (dev fixed code) and
DB-seed only the creature for the new uuid (looked up by email). Phase chooses
primary; switches to fallback only if the empirical check below fails.

### Success Criteria

#### Automated Verification

- `e2e_seed.dart` runs against `tamagotchi_test`: creates user + creature, and
  teardown removes them (re-runnable, no unique-constraint collision).
- A patrol harness test reaches the authenticated home via the login-once helper.

#### Manual Verification

- **The soft spot:** the authenticated session **survives a patrol-driven page
  reload** (`$.native`/reload then still on home, not bounced to `/sign-in`) —
  this is what makes Phase 4's reload assertion meaningful.
- Confirm which path (primary vs fallback) was used and why.

**Implementation Note**: Pause for manual confirmation before Phase 4.

---

## Phase 4: Persistence e2e test (the one risk)

### Overview

The single risk-tied browser test, hardened through the M3L4 loop.

### Changes Required

#### 1. Feed persistence test

**File**: `tamagotchi_flutter/integration_test/feed_persistence_test.dart` (new)

**Intent**: Prove the cross-boundary risk — Feed mutations (stats + journal entry)
survive a real page reload across auth → routing → API → DB — fails if they don't.

**Contract**: Driven PLAN → GENERATE → REVIEW → VERIFY. Flow: seed user+creature
(Phase 3) → login-once → record starting stats → tap Feed (`$(#feedButton)`) →
wait for the in-character response container (`$(#feedResponse)`) via
`waitUntilVisible` (no fixed delay) → **reload** → assert the post-feed stats AND
the journal entry are still present (the business outcome), not a decorative
title. Real boundaries stay real; the Mistral call is the deterministic stub via
the `e2e` runmode. Provenance header links to the protected persistence risk +
`seed_test.dart`. **REVIEW** against the five anti-patterns (re-prompt by name).
**VERIFY:** green, then deliberately break the persistence path (e.g. make the
feed mutation non-persistent / drop the journal write), confirm the test goes
**red**, then revert — never commit the break.

### Success Criteria

#### Automated Verification

- `feed_persistence_test.dart` passes:
  `patrol test --target integration_test/feed_persistence_test.dart -d chrome --web-headless`.
- `dart analyze` + `dart format --set-exit-if-changed` clean.

#### Manual Verification

- Five-anti-pattern review done (no hallucinated assertion, brittle selector,
  shared state, fixed wait, or missing cleanup).
- Deliberate-break check performed: the inverted persistence behavior turned the
  test red; the break was reverted (not committed).
- Re-running the test twice in a row is green (unique-id + teardown hold).

**Implementation Note**: Pause for manual confirmation before Phase 5.

---

## Phase 5: Marionette exploration assist (built)

### Overview

Wire marionette as the AI-native exploration assist, with a verification gate
(web support is undocumented).

### Changes Required

#### 1. marionette dependency + debug binding

**File**: `tamagotchi_flutter/pubspec.yaml`, `tamagotchi_flutter/lib/main.dart`

**Intent**: Let an MCP-driven agent drive a **debug** build to explore the live
app, without affecting release/e2e builds.

**Contract**: Add `marionette_flutter` (dev). In `main.dart`, under `kDebugMode`,
replace `WidgetsFlutterBinding.ensureInitialized()` (l.19) with
`MarionetteBinding.ensureInitialized()`; keep the standard binding otherwise.

#### 2. marionette MCP server registration

**File**: `marionette_mcp` global tool + Claude Code MCP config (`.mcp.json`)

**Intent**: Expose marionette's tools (`connect`, `get_interactive_elements`,
`tap`, `enter_text`, `take_screenshots`, …) to the agent.

**Contract**: `dart pub global activate marionette_mcp`; register it as a Claude
Code MCP server. Verify against a debug **web** build: connect, list interactive
elements, screenshot. If web support fails (DWDS VM-service path is a known sharp
edge), record the limitation — marionette is the assist, patrol is the supported
path, so a documented limitation is an acceptable outcome.

### Success Criteria

#### Automated Verification

- `flutter pub get` resolves with `marionette_flutter`.
- `dart analyze` clean; release/e2e builds unaffected (binding swap is
  `kDebugMode`-gated).
- `marionette_mcp` activates and appears as a registered MCP server.

#### Manual Verification

- marionette connects to a debug build and returns interactive elements +
  a screenshot — **or** the web limitation is documented with the evidence.
- The e2e and smoke patrol runs (non-debug) are unaffected by the binding change.

**Implementation Note**: Pause for manual confirmation before Phase 6.

---

## Phase 6: Foundation docs + cookbook

### Overview

Make the docs reflect the new browser layer.

### Changes Required

#### 1. test-plan.md updates

**File**: `context/foundation/test-plan.md`

**Intent**: Flip the e2e stack entry, supersede the exclusion, and add a cookbook
recipe.

**Contract**: `§4 Stack` — change the `e2e` row from `none` to `patrol` (+ version,
`checked: 2026-06-07`, and a marionette note as the exploration assist). `§7` —
note the e2e exclusion is superseded by this curriculum exercise (a browser layer
hardening S-03 persistence). `§6` — add `6.7 Adding a patrol e2e test`: the boot
recipe (no `docker compose up`; `dart bin/main.dart --mode e2e --apply-migrations`;
`patrol test … -d chrome --web-headless`; `--ipc=host --init`), the `e2e` runmode
+ local passwords section, the seed + login-once harness, and the two levers; note
CI as a deferred follow-up. `§8` — bump the freshness ledger.

#### 2. tech-stack.md test layer

**File**: `context/foundation/tech-stack.md`

**Intent**: Record patrol + marionette in the stack with verification dates.

**Contract**: Add patrol (e2e runner) and marionette (AI exploration assist) to
the test layer, each with a `checked: 2026-06-07` date and a one-line role note.

### Success Criteria

#### Automated Verification

- `grep -n 'e2e' context/foundation/test-plan.md` shows `patrol`, not `none`.
- `grep -n 'patrol' context/foundation/tech-stack.md` hits the test layer.

#### Manual Verification

- The `6.7` cookbook recipe is followable start-to-finish by someone new.
- The CI-as-follow-up note is explicit (what's deferred and why).

**Implementation Note**: Final phase — roll up any pending manual items and pause
for confirmation before the epilogue.

---

## Testing Strategy

### Unit / widget tests

- Existing `flutter test` widget tests must stay green after the Phase 2 `Key`
  additions and the Phase 5 `kDebugMode` binding swap.

### Integration tests

- Unchanged. The `e2e` runmode uses `tamagotchi_test` and commits real rows;
  `withServerpod` integration tests use the same DB but roll back, so they don't
  conflict provided e2e cleans up its unique-id data.

### Manual / browser testing steps

1. Rebuild the devcontainer; `patrol doctor` is green.
2. `dart bin/main.dart --mode e2e --apply-migrations` (sidecars already up).
3. `patrol test --target integration_test/smoke_test.dart -d chrome --web-headless` → green.
4. `patrol test --target integration_test/feed_persistence_test.dart -d chrome --web-headless` → green.
5. Break the persistence path → the test goes red → revert.
6. (marionette) connect to a debug build and list interactive elements.

## Performance Considerations

- Headless Chromium adds CPU/memory load not previously present in the container —
  verified in Phase 1. Run with `--ipc=host --init`.
- The image grows (Chromium + Playwright OS libs); accepted for reproducibility.
- E2E is the slowest, most flake-prone layer — budget is **one** test; no per-edit
  CI run (deferred).

## Migration Notes

- `config/passwords.yaml` is gitignored; the `e2e:` section is a **local** step
  each machine (and any future CI) must replicate — documented in `§6.7`.
- The `e2e` runmode writes to `tamagotchi_test`; if cleaner isolation is ever
  wanted, point `e2e.yaml` at a dedicated DB instead (not done now).

## References

- Frame brief: `context/changes/playwright-for-flutter/frame.md`
- Research: `context/changes/playwright-for-flutter/research.md`
- Contract source (not modified): `.claude/skills/10x-e2e/SKILL.md` + `references/`
- Stub seam: `tamagotchi_server/lib/src/llm/llm_service.dart:77-88`
- Run-mode gates: `tamagotchi_server/lib/server.dart:34,113,137`
- Key inventory: `tamagotchi_flutter/lib/creature/{creature_view,hatch_form}.dart`,
  `lib/home/home_screen.dart`
- patrol web: https://patrol.leancode.co/documentation/web ;
  marionette: https://pub.dev/packages/marionette_flutter

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Patrol toolchain + Linux-web smoke proof

#### Automated

- [x] 1.1 Devcontainer rebuilds with patrol_cli + Chromium present — 5dc57f6
- [x] 1.2 `patrol doctor` reports web toolchain ready — 5dc57f6
- [x] 1.3 `dart analyze` clean after server.dart change — 5dc57f6
- [x] 1.4 e2e server boots `--mode e2e` against tamagotchi_test on :8080 — 5dc57f6
- [x] 1.5 Smoke test passes (`patrol test … smoke_test.dart`) — 5dc57f6

#### Manual

- [x] 1.6 Headless Chromium runs under container resources (no OOM/crash) — 5dc57f6
- [x] 1.7 No CORS error patrol origin → :8080 (or tweak noted) — 5dc57f6
- [x] 1.8 Stub LLM selected in e2e mode (no Mistral call); exit/artifact paths noted — 5dc57f6

### Phase 2: Widget Keys + quality levers

#### Automated

- [x] 2.1 `dart analyze` clean after adding Keys — c39b05a
- [x] 2.2 `dart format --set-exit-if-changed` clean on touched files — c39b05a
- [x] 2.3 Existing widget tests still pass (`flutter test`) — c39b05a
- [x] 2.4 `seed_test.dart` compiles and runs green via patrol — c39b05a

#### Manual

- [x] 2.5 Seed test is a faithful patrol model of the four patterns — c39b05a
- [x] 2.6 `E2E_RULES.md` covers the five anti-patterns + real-vs-mocked boundary — c39b05a

### Phase 3: Backend harness — DB-seed + login-once auth

#### Automated

- [x] 3.1 `e2e_seed.dart` seeds + tears down user + creature (re-runnable) — 99196fd
- [x] 3.2 Patrol harness reaches authenticated home via login-once helper — 99196fd

#### Manual

- [x] 3.3 Authenticated session survives a patrol-driven page reload — 99196fd
- [x] 3.4 Primary vs fallback path used is recorded with rationale — 99196fd

### Phase 4: Persistence e2e test (the one risk)

#### Automated

- [x] 4.1 `feed_persistence_test.dart` passes via patrol — e149dcd
- [x] 4.2 `dart analyze` + `dart format` clean — e149dcd

#### Manual

- [x] 4.3 Five-anti-pattern review done — e149dcd
- [x] 4.4 Deliberate-break turned the test red; break reverted (not committed) — e149dcd
- [x] 4.5 Two consecutive runs are green (unique-id + teardown hold) — e149dcd

### Phase 5: Marionette exploration assist (built)

#### Automated

- [x] 5.1 `flutter pub get` resolves with `marionette_flutter`
- [x] 5.2 `dart analyze` clean; release/e2e builds unaffected (kDebugMode-gated)
- [x] 5.3 `marionette_mcp` activates and is registered as an MCP server

#### Manual

- [x] 5.4 marionette drives a debug build (or web limitation documented)
- [x] 5.5 Non-debug patrol runs unaffected by the binding change

### Phase 6: Foundation docs + cookbook

#### Automated

- [ ] 6.1 `test-plan.md` shows `e2e: patrol` (not `none`)
- [ ] 6.2 `tech-stack.md` test layer includes patrol

#### Manual

- [ ] 6.3 `§6.7` cookbook recipe is followable end-to-end
- [ ] 6.4 CI-as-follow-up note is explicit
