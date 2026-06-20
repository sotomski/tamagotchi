# Patrol e2e for Flutter web (M3L4 contract) — Plan Brief

> Full plan: `context/changes/playwright-for-flutter/plan.md`
> Frame brief: `context/changes/playwright-for-flutter/frame.md`
> Research: `context/changes/playwright-for-flutter/research.md`

## What & Why

The next 10xDevs lesson (M3L4) is about Playwright e2e tests. On a Flutter web
(CanvasKit) app, raw Playwright fights the renderer (shadow DOM + TypeScript), so
we hit the same **quality contract** — risk-driven test selection, a seed + rules,
the five anti-patterns, VERIFY-by-deliberate-break — with **patrol** (Dart-native
browser e2e) instead, plus **marionette** as an AI exploration assist. The
lesson's own "Other stacks" clause licenses the swap: principles transfer, syntax
changes.

## Starting Point

No e2e today (`test-plan.md §4` = `e2e: none`); the top layer is integration via
`withServerpod`. The devcontainer already runs the Postgres sidecars (dev +
`postgres_test`) but has **no Chromium and no `patrol_cli`**. The UI has **zero
widget `Key`s**. The Feed S-03 slice is shipped and the LLM call is server-side.

## Desired End State

From the devcontainer, `dart bin/main.dart --mode e2e --apply-migrations` then
`patrol test … feed_persistence_test.dart -d chrome --web-headless` boots the API
with a deterministic LLM stub and drives headless Chromium so **one** risk-tied
test — login → feed → page reload → stats + journal persisted — passes, and goes
red when the persistence path is deliberately broken. Two quality levers exist,
~7 `Key`s annotate the UI, marionette can explore a debug build, and the
foundation docs read `e2e: patrol`.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Tool for driving Flutter web | patrol (not raw Playwright) | patrol finds widgets on the Flutter tree, dodging CanvasKit's shadow DOM | Frame |
| LLM mock boundary | absent `mistralApiKey` → `StubLlmService` | the server-side call can't be `page.route()`'d; key-presence is the real seam | Research |
| **How to get the stub** | **dedicated `e2e` runmode** | `mistralApiKey` IS in the `development` passwords section, so plain dev hits real Mistral | Plan |
| E2E scope | persistence happy-path only (1 test) | smallest proof of the genuine cross-boundary risk on an unproven toolchain | Plan |
| Auth / storageState | DB-seed user + creature + login-once token | deterministic state; DB-seed alone can't put a JWT in the browser | Plan |
| Devcontainer install | bake patrol_cli + Chromium into Dockerfile | reproducible image, matches how Flutter/Serverpod CLIs are pinned | Plan |
| marionette | built phase (with a web-support verification gate) | realize the AI-explore-then-author workflow; patrol stays load-bearing | Plan |
| Levers location | project-local; `10x-e2e` skill untouched | keep curriculum skill pristine; patrol levers live where patrol reads them | Plan |
| CI | local-only; documented follow-up | Linux-web parity unproven; mirrors `mutation_test`'s local-only precedent | Plan |

## Scope

**In scope:** patrol toolchain + smoke proof; `e2e` runmode; ~7 widget `Key`s;
patrol seed test + E2E rules file; DB-seed + login-once harness; one persistence
e2e test (reviewed + break-verified); marionette wiring; `test-plan.md` +
`tech-stack.md` updates.

**Out of scope:** raw Playwright / ARIA `Semantics`; R5 ownership at the browser
(stays integration); hatch/refusal as e2e; JWT-localStorage injection; CI e2e job;
editing the `10x-e2e` skill; a Mistral base-URL mock.

## Architecture / Approach

Two tiers stay disjoint: **patrol owns the front end** (builds + serves the web
app, drives headless Chromium); **we boot only the Serverpod API on `:8080`**
against the always-running `tamagotchi_test` sidecar — no `docker compose up`. The
new `e2e` runmode (config + local passwords section without `mistralApiKey` +
extending `server.dart`'s fixed-verification-code gate) makes the stub
deterministic and lets UI sign-up work without a mailer. Spike-first: prove the
toolchain (Phase 1) before authoring; isolate the auth soft spot (Phase 3) before
the test (Phase 4).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Toolchain + smoke | patrol_cli + Chromium, `e2e` runmode, green smoke test | patrol Linux-web parity is undocumented |
| 2. Keys + levers | ~7 `Key`s, seed test + E2E rules | seed quality = test quality |
| 3. Harness | DB-seed + login-once auth | session reuse on patrol web (top soft spot) |
| 4. Persistence test | one reviewed, break-verified e2e test | decorative assertion / flake |
| 5. marionette | debug binding + MCP server | web support undocumented (may end as a noted limitation) |
| 6. Docs | `e2e: patrol` in foundation docs | none |

**Prerequisites:** devcontainer rebuild after the Dockerfile change; local `e2e:`
passwords section.
**Estimated effort:** ~4–6 focused sessions across 6 phases (Phases 1 + 3 carry
the unknowns).

## Open Risks & Assumptions

- **Auth/login-once on patrol web** is the top risk — primary path + a fully
  specified fallback are in the plan (Phase 3).
- **patrol Linux-web parity** is unproven — Phase 1's smoke run gates everything.
- **CORS** (patrol origin → `:8080`) is unverified — checked in Phase 1.
- **marionette web support** is undocumented — Phase 5 may land a documented
  limitation rather than a working integration.
- The `e2e:` passwords section is local/gitignored — any future CI must replicate
  it; JWT issuance must need nothing beyond `shared` + `e2e.database` (verify).

## Success Criteria (Summary)

- One patrol test proves Feed stats + journal survive a real page reload, and
  fails when that persistence is broken.
- `patrol test … --web-headless` runs green in the devcontainer.
- `test-plan.md` / `tech-stack.md` reflect `e2e: patrol` with `checked:` dates.
