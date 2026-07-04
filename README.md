# AI-Tamagotchi

An AI-driven virtual pet where every creature has a **randomized, continuous personality**
that genuinely shapes how it responds to care. Feed, Pet, and Cure your creature; it reacts
in character via an LLM, keeps a **narrative journal** of its life, and its stats decay in
real time at personality-driven rates — even while you're away.

The product hypothesis, personas, and full requirements live in
[`context/foundation/prd.md`](context/foundation/prd.md).

## Stack

| Layer | Technology |
|-------|------------|
| Backend | [Serverpod](https://serverpod.dev) 3.4.x (persistent Dart server, generated typed RPC client) |
| Database | Postgres 16 (+ pgvector); no Redis |
| Frontend | Flutter Web + [Riverpod](https://riverpod.dev) 3.x |
| AI | Mistral (in-character responses) · Gemini (birth-image generation) |
| Deployment | Serverpod Cloud (`scloud`), auto-deploy on merge via GitHub Actions |

Dart SDK `^3.8.0`. See [`context/foundation/tech-stack.md`](context/foundation/tech-stack.md)
for the full rationale.

## Repository layout

This repo is a **pub workspace** with three member packages directly under the root:

| Package | Role |
|---------|------|
| [`tamagotchi_server/`](tamagotchi_server) | Serverpod backend — endpoints, business logic, migrations. |
| [`tamagotchi_client/`](tamagotchi_client) | **Generated** RPC client. Do not hand-edit — regenerate with `serverpod generate`. |
| [`tamagotchi_flutter/`](tamagotchi_flutter) | Flutter web client (the user-facing app). |

Code is organized **by feature, not by layer** — e.g. `tamagotchi_server/lib/src/creature/`
owns the creature's models, endpoint, and services together. See
[`CLAUDE.md`](CLAUDE.md) for the full conventions.

## Prerequisites

- Dart SDK `^3.8.0` and Flutter (web enabled)
- Docker (for the local Postgres sidecar)
- The Serverpod CLI: `dart pub global activate serverpod_cli`

## Getting started

All server commands run from `tamagotchi_server/`.

**1 — Start Postgres and apply migrations:**

```bash
cd tamagotchi_server
docker compose up --build --detach
dart bin/main.dart --apply-migrations
```

**2 — Run the backend** (`:8080` API, `:8081` insights, `:8082` web):

```bash
dart bin/main.dart
```

**3 — Run the Flutter client** (from `tamagotchi_flutter/`, with the server running):

```bash
cd tamagotchi_flutter
flutter run -d chrome
```

Alternatively, build the web bundle into the server's `web/app/` directory (served by the
backend) with `serverpod run flutter_build` from `tamagotchi_server/`.

### Regenerating the client after backend changes

After editing any `*.spy.yaml` (protocol/endpoint definitions) or model, regenerate the
shared client from `tamagotchi_server/`:

```bash
serverpod generate
```

This rewrites `tamagotchi_server/lib/src/generated/` and `tamagotchi_client/lib/src/protocol/`.
Both trees are build artifacts — never hand-edit them.

## Testing

**Server** (from `tamagotchi_server/`) — unit tests run standalone; integration tests need
the Postgres sidecar up (port 8090) and a test DB password:

```bash
docker compose up -d
SERVERPOD_PASSWORD_database=<test-pw> dart test
```

**Flutter** (from `tamagotchi_flutter/`):

```bash
flutter test
```

Browser-level e2e (Patrol) is local-only; the full recipe is in
[`context/foundation/test-plan.md`](context/foundation/test-plan.md) §6.7.

The project's risk map and testing strategy live in that same test plan.

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — project conventions (workspace layout, feature-first
  organization, codegen cycle, agent skills).
- [`context/foundation/`](context/foundation) — the 10x written foundation: `prd.md`,
  `tech-stack.md`, `roadmap.md`, `test-plan.md`, `health-check.md`, `stack-assessment.md`,
  `infrastructure.md`.
- [`context/archive/`](context/archive) — immutable record of completed changes.
- [`MVP-CHECK-REPORT.md`](MVP-CHECK-REPORT.md) — MVP technical-foundations assessment.
