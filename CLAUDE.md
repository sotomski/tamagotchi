# AI-Tamagotchi — Project Conventions

## Where the code lives
- The repository root is the pub workspace root, with three member packages directly under it:
  - `tamagotchi_server/` — Serverpod backend; edit here for endpoints, business logic, migrations.
  - `tamagotchi_client/` — **generated RPC client. Do not hand-edit.** Regenerate via `serverpod generate` from `tamagotchi_server/`.
  - `tamagotchi_flutter/` — Flutter web client (the user-facing app).
- `tamagotchi_server/lib/src/generated/` and `tamagotchi_client/lib/src/protocol/` are codegen output. Never hand-edit; the analyzer excludes them, so errors surface only at runtime.
- Server-specific rules (codegen cycle, sidecar ports, migrations, endpoints, secrets) live in `@tamagotchi_server/CLAUDE.md`.

## Group by feature, not by layer
Organize code into feature directories that own their own models, endpoints, services, and widgets — not top-level `models/`, `endpoints/`, `services/` layer dirs (the Serverpod default scaffold). Examples: `tamagotchi_server/lib/src/creature/{creature_endpoint.dart, creature_service.dart, creature.spy.yaml}`, `tamagotchi_flutter/lib/creature/{creature_screen.dart, creature_state.dart}`. New code joins the feature it belongs to.

## Flutter web build
Build from the server dir: `serverpod run flutter_build` in `tamagotchi_server/`. Output lands in `tamagotchi_server/web/app/` — treat that directory as a build artifact, not something to curate by hand.

## Agent skills (Flutter/Dart)
Skills live under `.claude/skills/` and auto-trigger by task (e.g. `flutter-fix-layout-issues`, `serverpod-endpoints`, `riverpod-providers`, `relic-routing`). They are managed like `pub get` — **the fetched skill dirs are gitignored; only the manifest is committed.** After changing dependencies, re-fetch.

- **The Dart `skills` CLI** (`serverpod/skills`, dependency-aware) is the **only** skill-fetching tool we use. Run `skills get --ide claude` from the repo root; it scans the resolved pub workspace and installs the matching skills — `flutter-*` (flutter/skills), `riverpod-*` + `shadcn_ui-*` (serverpod/skills-registry), and the skills shipped *inside* resolved packages: `serverpod-*` and `relic-*` (version-matched to the pinned package). Manifest: `.dart_skills/skills_config.json` (committed). The clone cache `.dart_skills/repos/` is gitignored. **We deliberately do not use any other skills CLI** (no npm `skills`, no `skills-lock.json`) — if a skill isn't reachable through `skills get`, we don't install it.
- **Project-local: `10x-*`** — hand-authored 10xDevs toolkit skills, committed directly (not fetched by the CLI; the only skill dirs not gitignored).
- **Two fetched skills cut against our conventions — prefer the project pattern over the skill's default:** `flutter-use-http-package` (raw REST) and `flutter-implement-json-serialization` (hand-written `fromJson`/`toJson`). Frontend↔backend goes through the **generated Serverpod RPC client** (`tamagotchi_client`) with Serverpod model classes — do not hand-roll HTTP calls or JSON mapping for backend communication.

### Consult skills proactively — don't wait for auto-surfacing
~120 skills are installed, so the skill-listing budget can crowd out the relevant description and a matching skill may never surface on its own. Skills are also plain files: **before writing or substantially editing Riverpod / Serverpod / Flutter code, scan `.claude/skills/` for a matching `SKILL.md` and `Read` it** (readable even when not surfaced as invocable — `grep -l '^description:' .claude/skills/*/SKILL.md` then read the hit). They are the canonical source for version-specific gotchas (Riverpod 3.x, the `withServerpod` harness) that training data gets wrong. Quick map:
- **Riverpod** — providers / consumers: `riverpod-providers`, `riverpod-consumers`; tests + `overrideWith` + `ProviderScope`: `riverpod-testing`, `riverpod-overrides`; 3.x breaking changes (legacy `StateProvider` import, `Ref` changes): `riverpod-3-0-migration`; codegen: `riverpod-codegen-and-hooks`.
- **Serverpod** — endpoints: `serverpod-endpoints`; models / migrations / queries: `serverpod-models`, `serverpod-database`; `withServerpod` / rollback / `sessionBuilder` / auth in tests: `serverpod-testing`.
- **Flutter** — widget / integration tests: `flutter-add-widget-test`, `flutter-add-integration-test`; layout: `flutter-fix-layout-issues`, `flutter-build-responsive-layout`.
- **shadcn_ui** — `shadcn_ui-<component>`, but only when intentionally adding shadcn (the app is Material today).

## Context directory
Project-level docs live in `context/foundation/`:
- `@context/foundation/prd.md` — what we're building and why.
- `@context/foundation/stack-assessment.md` — agent-friendliness scoring of the stack.
- `@context/foundation/health-check.md` — known toolchain / CI / config issues.
- `@context/foundation/shape-notes.md` — early discovery notes (background only).

`context/archive/` is immutable — open a new change via `/10x-new` instead of editing archived material.

<!-- BEGIN @przeprogramowani/10x-cli -->

## 10xDevs AI Toolkit - Module 3, Lesson 4 (E2E Tests)

**For E2E tests, use the `/10x-e2e` skill.** It is the single source of truth
for the workflow — risk → seed test + rules → generate → review against the five
anti-patterns → re-prompt → verify. The skill's `references/` carry the full
rules, anti-patterns, seed pattern, and prompt-template.

A few hard rules that hold even before you invoke the skill:

- **Locators:** `getByRole` / `getByLabel` / `getByText` first; `getByTestId`
  only when accessibility attributes are ambiguous. Never CSS selectors, XPath,
  or DOM structure.
- **Never `page.waitForTimeout()`.** Wait for state: `toBeVisible()`,
  `waitForURL()`, `waitForResponse()`.
- **Test independence + cleanup.** Each test runs standalone — its own setup,
  action, assertion, and cleanup; unique ids (timestamp suffix) so parallel runs
  and re-runs don't collide.

Two boundaries to keep straight:

- **DOM (snapshot) is the default.** Vision (`--caps=vision`) is a supplement for
  visual-only risks (layout, z-index, animation); for pixel regression prefer
  deterministic tools (`toMatchSnapshot`, Argos, Lost Pixel). VLM model
  selection/cost is a debugging topic (Lesson 5), not testing.
- **Healer helps on selectors, harms on logic.** A changed selector → healer
  re-finds it (route through PR review). A changed business behavior → healer
  masks the bug; that failing-test-to-fix case is Lesson 5.

<!-- END @przeprogramowani/10x-cli -->
