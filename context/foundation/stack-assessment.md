---
project: AI-Tamagotchi
assessed_at: 2026-05-21
agent_readiness: ready-with-compensation
context_type: brownfield
stack_components:
  language: Dart 3.8+
  framework: Serverpod 3.4.8 (server) + Flutter 3.32+ (client)
  build_tool: Dart SDK + Flutter build (web)
  test_runner: package:test + serverpod_test + flutter_test
  package_manager: pub (workspace)
  ci_provider: GitHub Actions (server-side workflows only)
  deployment_target: Serverpod Cloud (scloud)
gates_passed: 4
gates_failed: 0
notes:
  - Serverpod's training-data depth is shallow relative to mainstream backend frameworks; compensation strategies below are required, not optional.
  - Flutter side currently has no CI workflow (analyze/format/test scoped to tamagotchi_server only).
  - Flutter toolchain versions are inconsistent across files (devcontainer 3.44.0 vs tests.yml 3.32.8 vs pubspec ^3.32.0).
  - Updated 2026-05-23 — project decided not to use Redis (single Serverpod instance; no cross-instance pubsub/session/rate-limit needs). All references to Redis in this assessment have been amended to reflect the current single-instance topology. See `infrastructure.md` for the deployment decision that drove this.
---

## Stack Components

The project is a **pub workspace** rooted at the repository root (`pubspec.yaml`) with three member packages: `tamagotchi_client` (generated typed RPC client), `tamagotchi_server` (Serverpod 3.4.8 backend, Dockerised, Postgres only — Redis intentionally not used), and `tamagotchi_flutter` (Flutter 3.32+ web client). All packages share `sdk: '^3.8.0'`.

**Language — Dart 3.8+.** Soundly typed; pubspecs pin `environment: sdk: '^3.8.0'` consistently across the three workspace members. The language carries types end-to-end; the Serverpod client/server protocol is generated as typed Dart from `.spy.yaml` definitions, eliminating drift between RPC contract and call sites.

**Server framework — Serverpod 3.4.8.** Convention-heavy backend toolkit: `lib/src/endpoints/*.dart` for RPC, `lib/src/protocol/` for shared models, `lib/src/generated/` for codegen output, `migrations/` for DB migrations, `config/{development,test,staging,production}.yaml` for runmode-scoped config, `config/passwords.yaml` for runmode-scoped secrets, `Dockerfile` for prod build (Dart 3.8.0 → alpine), `docker-compose.yaml` for local dev/test infra (Postgres `pgvector/pgvector:pg16` only, with separate dev + test instances; Redis was removed 2026-05-23 — `redis.enabled: false` in every runmode config). `bin/main.dart` is the entry point with `dart bin/main.dart --apply-migrations` as the canonical start script.

**Client framework — Flutter 3.32+.** Standard Flutter app structure under `tamagotchi_flutter/lib/`. Talks to the server via `tamagotchi_client` (path dependency) and uses `serverpod_flutter` + `serverpod_auth_idp_flutter` for the IDP authentication flow. Targets Flutter web for the MVP (per PRD non-goal #3 "no native mobile apps"). Build is wired via Serverpod's `flutter_build` script which compiles Flutter web with `--wasm` into `tamagotchi_server/web/app/`.

**Tests.** `tamagotchi_server` uses `package:test ^1.25.5` plus `serverpod_test 3.4.8`; integration test scaffolding under `test/integration/test_tools/serverpod_test_tools.dart` (excluded from analyzer). `tamagotchi_flutter` uses `flutter_test` (SDK-bundled). `dart_test.yaml` exists at server root. No client-side widget or integration tests on disk yet.

**Lint / format.** `package:lints/recommended.yaml` on server with two custom rules (`unawaited_futures: true`, `avoid_print: true`) and `formatter.trailing_commas: preserve`. `flutter_lints` on Flutter package (>=3.0.0 <7.0.0). Analyzer excludes the Serverpod-generated tree (`lib/src/generated/**`).

**Package manager.** `pub` with workspace resolution; lockfile lives at the workspace root (`pubspec.lock`, 39 KB) and member packages declare `resolution: workspace`.

**CI / GitHub Actions.** Three workflows in `.github/workflows/`, all push+PR to `main`, all scoped via `working-directory: tamagotchi_server`:

- `analyze.yml` — `dart analyze --fatal-infos` on the server (Dart 3.8.0)
- `format.yml` — `dart format --set-exit-if-changed .` on the server
- `tests.yml` — boots `docker compose up` (Postgres test sidecar), `dart pub global activate serverpod_cli 3.4.8`, `serverpod generate`, `dart test` (Flutter 3.32.8)

The Flutter package has **no CI coverage** — no `flutter analyze`, no `flutter test`, no web build verification.

**Deployment — Serverpod Cloud (scloud).** Confirmed in conversation. The devcontainer pre-installs `serverpod_cloud_cli` v0.29.0 alongside `serverpod_cli` v3.4.8, which lines up. No `scloud` project config (e.g. a `scloud.yaml`) is on disk yet — that surface will need to be authored before first deploy. The existing `Dockerfile` is the dev/local-prod artifact, not the scloud deploy artifact.

**Devcontainer.** Ubuntu 24.04 base; pins `FLUTTER_VERSION=3.44.0` (newer than the `^3.32.0` requirement and the `3.32.8` used in CI — see toolchain drift note); also installs `node` (via feature) and the `claude-code` devcontainer feature. Forwards ports 8080–8082 (server) and 8090 (Postgres). The dev compose `includes ../tamagotchi_server/docker-compose.yaml`, so the dev shell shares the server's Postgres stack.

**Instruction files.** Only `CLAUDE.md` at the repo root. Its current content documents the **bootstrap-chain skill flow** (`/10x-init → /10x-shape → /10x-prd → /10x-tech-stack-selector → /10x-bootstrapper`) — it is meta-documentation for running the scaffolding skills, not runtime conventions an agent can use to write code in this codebase. No `AGENTS.md`, no `.cursor/rules`, no `.github/copilot-instructions.md`.

## Quality Gate Assessment

| Component        | Typed | Convention-based | Popular in training (within Dart) | Well-documented | Verdict |
|------------------|:-----:|:----------------:|:--------------------------------:|:---------------:|:-------:|
| Language (Dart)  |  ✓    |        —         |                —                 |        —        |  pass   |
| Server (Serverpod) |  —  |        ✓         |               ~                  |        ✓        | pass\*  |
| Client (Flutter) |  —    |        ✓         |                ✓                 |        ✓        |  pass   |
| Test runner      |  —    |        —         |                ✓                 |        ✓        |  pass   |

Legend: ✓ = pass, ✗ = fail, ~ = partial, — = not applicable.
`*` Serverpod earns a partial on training-data depth; see Gate Details.

### Gate Details

**Type safety — pass.** Dart is statically typed with sound null safety by default. The Serverpod codegen pipeline (`serverpod generate`) writes typed protocol classes into `lib/src/generated/`, so RPC boundary contracts (server endpoints ↔ Flutter client) are compiled. Type-checking is enforced in CI via `dart analyze --fatal-infos` (`.github/workflows/analyze.yml`). The `analysis_options.yaml` adds `unawaited_futures: true`, which catches a real Dart correctness footgun. Evidence: `tamagotchi_server/pubspec.yaml:7`, `tamagotchi_server/analysis_options.yaml:16-20`, `.github/workflows/analyze.yml:22`.

**Convention-based — pass.** Serverpod is highly opinionated: a code-generation cycle defines protocol from `.spy.yaml`, endpoints live in `lib/src/endpoints/`, the generated client is consumed via a path dependency, migrations are managed through `serverpod create-migration` + `dart bin/main.dart --apply-migrations`, and runmode-scoped configs live under `config/`. A new contributor (or agent) can predict file locations from the framework's docs. Flutter on the client side similarly imposes well-known structure (`lib/main.dart`, widget tree, `pubspec.yaml`-driven asset declarations). Evidence: `tamagotchi_server/` directory layout, `tamagotchi_server/config/{development,production,staging,test}.yaml`, `tamagotchi_server/migrations/`.

**Training-data popularity (per-Dart-family) — pass for Flutter, partial for Serverpod.** Flutter dominates the Dart ecosystem in training data; the agent has internalised widget patterns, state management idioms, and pubspec conventions. Serverpod, by contrast, is the leading **Dart server** framework but the Dart server ecosystem itself is small compared to Python/Node/Ruby backends — so per-language-family the agent has shallow priors on Serverpod-specific idioms (`Endpoint` subclasses, `Session` typing, `serverpod generate` workflow, scoped table classes). It does NOT fail the gate (it is mainstream within its niche) but it falls below "the agent will write idiomatic code without hand-holding" — hence the partial mark and the compensation entries below. Evidence: pubspec.yaml dependency `serverpod: 3.4.8`; recent-but-stable framework on serverpod.dev.

**Documented — pass.** Both frameworks ship official, version-pinned docs: `docs.serverpod.dev` versions per major release; `docs.flutter.dev` is best-in-class for the Dart ecosystem. The agent can fetch authoritative reference material via WebFetch when needed. Evidence: framework reputations; no community-wiki dependency observed in the codebase.

## Gaps & Compensation

The gates technically all pass, but **two soft gaps** materially affect agent workflows on this project:

### Gap 1 — Serverpod-specific patterns are shallow in training data

The agent will write correct Dart and Flutter without much steering. It will **not** automatically know:

- The Serverpod codegen lifecycle (`serverpod generate` must run after editing `.spy.yaml` protocol files; the resulting `lib/src/generated/` tree is read-only).
- The endpoint discovery convention (a class extending `Endpoint` placed in `lib/src/endpoints/` is auto-registered; method signatures map 1:1 to RPC, with `Session session` as the first parameter).
- The migration workflow (`serverpod create-migration` writes to `migrations/`; `dart bin/main.dart --apply-migrations` is the canonical apply step; `--apply-repair-migration` is for drift).
- Runmode scoping (`config/development.yaml` vs `production.yaml`; `SERVERPOD_PASSWORD_*` env vars override secrets in `config/passwords.yaml`).
- The Flutter ↔ server build coupling (Serverpod's `flutter_build` script compiles the Flutter web app into `tamagotchi_server/web/app/`).

**Why it matters:** without these in an instruction file, every session's first edits will either skip codegen, hand-edit generated files, or invent a non-canonical migration step. The codebase will drift away from Serverpod's idioms.

### Gap 2 — No runtime-conventions instruction file exists

`CLAUDE.md` at the repo root is bootstrap-chain meta-documentation; it tells the user how to run scaffolding skills, not how to write Serverpod endpoints or Flutter widgets in **this** codebase. The agent therefore loads no project-specific runtime context on session start.

**Why it matters:** every agent session re-derives conventions from scratch — which file layout to use, where to put new endpoints, which lint rules are enforced, how to run tests locally, how to deploy. Onboarding cost is paid per session, not once.

### Recommended Instruction File Additions

The block below is **ready to paste** at the end of `/workspaces/nabrudno/CLAUDE.md` (or, preferably, into a new dedicated runtime-conventions section if you'd like to keep the bootstrap docs visually separate). All entries are concrete enough to be load-bearing for an agent on first read.

````markdown
## Runtime conventions (AI-Tamagotchi)

This section describes how the agent should write code, run commands, and ship changes in **this** codebase. The bootstrap-chain documentation above is meta — it covers scaffolding skills, not day-to-day work.

### Project layout

The project is a **pub workspace** rooted at the repository root. Three packages:

- `tamagotchi_server/` — Serverpod 3.4.8 backend. Endpoints, protocol definitions, migrations, runmode configs.
- `tamagotchi_client/` — Generated typed RPC client. **Do not hand-edit.** Regenerate via `serverpod generate` from the server package.
- `tamagotchi_flutter/` — Flutter web client. Depends on `tamagotchi_client` via a path dependency.

Always run pub / dart commands from the package directory, not from the workspace root, unless the task is workspace-wide.

### Serverpod codegen workflow (non-obvious — read before editing protocol)

`lib/src/generated/**` is **read-only** for humans and agents. It is regenerated by `serverpod generate`. To change the protocol surface:

1. Edit or add a `.spy.yaml` file under `tamagotchi_server/lib/src/protocol/`.
2. From `tamagotchi_server/`, run `serverpod generate` (requires `dart pub global activate serverpod_cli 3.4.8`).
3. The change propagates to `tamagotchi_server/lib/src/generated/` AND to `tamagotchi_client/lib/src/protocol/` automatically.
4. Commit the generated files alongside the `.spy.yaml` change.

The analyzer excludes `lib/src/generated/**` (see `analysis_options.yaml`), so type errors there will not fail CI — but they WILL fail at runtime. Always run `dart analyze --fatal-infos` after regenerating.

### Endpoint discovery

A class extending `Endpoint` placed under `tamagotchi_server/lib/src/endpoints/` is auto-registered. Method signatures map 1:1 to RPC; the first parameter must be `Session session`. After adding a new endpoint or method, run `serverpod generate` to refresh the client.

### Database migrations

From `tamagotchi_server/`:

- Create: `serverpod create-migration` — diffs the live schema against the generated protocol and writes a migration under `migrations/`.
- Apply: `dart bin/main.dart --apply-migrations` (runs at server start; the canonical `start` script in `pubspec.yaml` does this).
- Repair drift: `dart bin/main.dart --apply-repair-migration` (advanced; coordinate with the user before invoking).

Never edit applied migration files in place. Always create a new migration.

### Runmode-scoped configuration

`tamagotchi_server/config/{development,test,staging,production}.yaml` carry the non-secret runtime config; `config/passwords.yaml` carries secrets per runmode. Override secrets in deployed environments via `SERVERPOD_PASSWORD_<key>` environment variables (see the `tests.yml` CI workflow for the pattern).

### Local development

From `tamagotchi_server/`:

```
docker compose up -d           # postgres (pgvector/pgvector:pg16), dev + test instances (no redis — single-instance topology)
dart pub get
serverpod generate              # if protocol changed
dart bin/main.dart --apply-migrations
```

Server ports: 8080 (API), 8081 (insights), 8082 (web). Postgres dev: 8090.

### Building the Flutter web client

From `tamagotchi_server/` (NOT from `tamagotchi_flutter/`):

```
serverpod run flutter_build
```

This compiles `tamagotchi_flutter` with `--wasm` and copies the build into `tamagotchi_server/web/app/`. The server then serves the Flutter app at `/app/`.

### Lint rules and formatting

- Server: `package:lints/recommended` + `unawaited_futures: true` + `avoid_print: true` + `trailing_commas: preserve`.
- Flutter: `package:flutter_lints`.
- Format with `dart format .` from each package directory. CI fails on `dart format --set-exit-if-changed` for the server package.

### CI coverage gap (known)

The three GitHub Actions workflows in `.github/workflows/` (`analyze.yml`, `format.yml`, `tests.yml`) all scope to `working-directory: tamagotchi_server`. **The Flutter package has no CI** — no `flutter analyze`, no `flutter test`, no web build verification. When adding Flutter-side coverage, model the workflow on `tests.yml` but with `subosito/flutter-action@v2` and `flutter test` / `flutter analyze`.

### Toolchain version pins (drift to reconcile)

- `tamagotchi_*/pubspec.yaml` → Dart `^3.8.0`, Flutter `^3.32.0`
- `.github/workflows/*.yml` → Dart `3.8.0`, Flutter `3.32.8`
- `.devcontainer/Dockerfile` → Flutter `3.44.0`

The devcontainer is ahead of CI. Either bump CI to match the devcontainer, or pin the devcontainer to `3.32.8` so local and CI runs share an analyzer version. Coordinate this with the user before changing — version bumps can surface new lint warnings.

### Deployment — Serverpod Cloud (scloud)

Production deploys go to **Serverpod Cloud** via the `scloud` CLI (`serverpod_cloud_cli` v0.29.0; pre-installed in the devcontainer). The on-disk `Dockerfile` is for local container builds, NOT the scloud deploy artifact — scloud has its own build pipeline. Before the first deploy, an `scloud` project config will need to be authored. Do not invoke `scloud deploy` or any production-mutating scloud subcommand without explicit user confirmation per session.

### Testing locally

From `tamagotchi_server/`: `docker compose up -d` (test Postgres sidecar exposed on 9090), then `dart test`. Integration tests live under `test/integration/`; the `test_tools/serverpod_test_tools.dart` helper is generated and excluded from analyzer.
````

## Summary

The stack is **agent-friendly with light compensation**: Dart's type system, Serverpod's strong conventions, and Flutter's training-data dominance carry most of the load. The two gaps that need explicit instruction-file coverage are (1) Serverpod's codegen/migration/runmode workflow (not enough Serverpod in pre-training for the agent to internalise it) and (2) the absence of any runtime-conventions section in `CLAUDE.md` today.

**Strengths**

- End-to-end static typing (Dart sound null safety + Serverpod-generated protocol classes).
- Convention-rich server framework — file layout, endpoint discovery, migration commands, runmode configs are all opinionated.
- CI already enforces analyzer + formatter + tests on every PR (server side).
- Devcontainer pre-installs the full toolchain including `scloud` CLI — local environment matches the deploy target.

**Gaps to address**

- No runtime-conventions instruction file. The block above is ready to paste into `CLAUDE.md`.
- Flutter package has no CI coverage — analyze/format/test only run on `tamagotchi_server`.
- Toolchain version drift between devcontainer (3.44.0), CI (3.32.8), and pubspec (^3.32.0).
- No `scloud` project config on disk yet; first deploy will need that authored.

**Recommended next step**: run `/10x-health-check` to drill into the dependency / security / test posture and turn these soft gaps into a concrete fix list.
