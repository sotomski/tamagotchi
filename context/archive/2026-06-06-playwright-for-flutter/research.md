---
date: 2026-06-06T20:47:26+0000
researcher: Karol Sotomski
git_commit: c50a0b9f875c272d9722534d5deff854cf16f5b8
branch: main
repository: sotomski/tamagotchi
topic: "patrol/marionette e2e integration wiring (items 1–4) + 10x-e2e skill internals (item 5)"
tags: [research, e2e, patrol, marionette, serverpod, flutter-web, llm-mock, auth, 10x-e2e]
status: complete
last_updated: 2026-06-06
last_updated_by: Karol Sotomski
---

# Research: patrol/marionette e2e integration wiring + 10x-e2e skill internals

**Date**: 2026-06-06T20:47:26+0000
**Researcher**: Karol Sotomski
**Git Commit**: c50a0b9f875c272d9722534d5deff854cf16f5b8
**Branch**: main
**Repository**: sotomski/tamagotchi

## Research Question

Following the `frame.md` decision (patrol = Dart-native e2e runner; marionette = AI
exploration assist; raw Playwright rejected for CanvasKit; achieve the M3L4 quality
contract), ground the **integration wiring** the frame did not resolve:

1. **LLM mock boundary** — the Mistral call is server-side; how do we mock it for an
   out-of-process e2e run?
2. **Full-stack boot & serving** — how does the app come up (Postgres → server → web
   build → browser) for a browser-level test?
3. **Auth session reuse** — the `storageState` equivalent on Flutter web + Serverpod.
4. **Widget keys/semantics** — what stable patrol finders exist vs. net-new work.
5. **`10x-e2e` skill internals** (folded in after installing the skill) — the contract
   to adapt, and every Playwright idiom that needs a patrol/Dart translation.

## Summary

Two findings reshape the plan:

- **The LLM "mock" already exists with zero net-new code.** `llmServiceFor(session)`
  picks the client by **API-key presence, not run mode** ([`llm_service.dart:77-88`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/llm/llm_service.dart#L77-L88)).
  Boot the e2e server **without** the `mistralApiKey` secret → it serves the
  deterministic `StubLlmService` automatically — no network call, no flake, no cost,
  no code change. This is precisely the skill's "mock where the server calls out"
  caveat: a browser-level `page.route()` could never intercept this server-side call,
  but the key-presence seam does. (Net-new config — a configurable Mistral base URL
  pointed at a local mock — is only needed if we want to exercise the *real* HTTP path
  or vary stub output per scenario; not required for the contract.)

- **The `10x-e2e` skill will *halt* on this repo and must be adapted, not invoked
  verbatim.** Its Setup gate STOPs when there is no `playwright.config.*`/`*.spec.ts`
  ([SKILL.md:111-122](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/.claude/skills/10x-e2e/SKILL.md#L111-L122)),
  and its `allowed-tools` hardwire `mcp__playwright__*`. We keep its **contract** (the
  PLAN→GENERATE→REVIEW→VERIFY loop, the five anti-patterns, real-vs-mocked boundaries,
  deliberate-break verification) and author **patrol-flavored levers** (a seed patrol
  test in Dart + a patrol E2E rules file). The skill's own "Other stacks" section
  ([SKILL.md:393-395](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/.claude/skills/10x-e2e/SKILL.md#L393-L395))
  explicitly licenses this.

Supporting facts: patrol **owns front-end serving** (`flutter run -d web-server` +
Playwright/Chromium) — we own only the backend (Serverpod on 8080 + Postgres). The app
resolves its API URL to `http://localhost:8080` via a bundled `config.json` fallback,
so a patrol-served build hits the real backend. Auth is **stateless JWT**
(`serverpod_auth_idp`), so a token *can* be reused across tests — but seeding it on
patrol web is the **least-clean piece** and is the main open question. The UI has **zero
`Key`s/`Semantics`** today, but patrol finds widgets on the **Flutter widget tree, not
the DOM/ARIA tree**, so `ensureSemantics()` is **not** required (correcting one agent's
recommendation); ~13/20 interactive elements already have stable text finders, ~7 need a
net-new `Key`. The devcontainer has Node v24 + Flutter 3.44 but **no Chromium binary**
and no `patrol_cli`.

---

## Detailed Findings

### Item 1 — LLM mock boundary (server-side Mistral) ✅ largely already solved

**The seam.** `feedServiceFactory` is a static function field, default = production wiring:

- [`feed_service.dart:167`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/creature/feed_service.dart#L167) — `FeedService Function(Session) feedServiceFactory = feedServiceFor;`
- [`feed_service.dart:159-160`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/creature/feed_service.dart#L159-L160) — `feedServiceFor(session) => FeedService(rng: Random(), llm: llmServiceFor(session));`
- [`creature_endpoint.dart:163`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/creature/creature_endpoint.dart#L163) — endpoint calls `feedServiceFactory(session)` unconditionally.

**The Mistral client.** [`mistral_client.dart`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/llm/mistral_client.dart): `MistralLlmService` (l.17); endpoint **hardcoded** `https://api.mistral.ai/v1/chat/completions` (l.20-22); `http.post` via `package:http` (l.95); API key from `session.passwords['mistralApiKey']` (l.78); **no HTTP timeout** set; model hardcoded `mistral-small-2603` (l.25). (No timeout = test-plan R7 — out of scope here, noted for Phase 2.)

**The decisive mechanism — selection by key presence, NOT run mode:**

```dart
// llm_service.dart:77-88
LlmService llmServiceFor(Session session) =>
    llmServiceForKey(session.passwords['mistralApiKey']);

LlmService llmServiceForKey(String? mistralApiKey) {
  if (mistralApiKey != null && mistralApiKey.isNotEmpty) return MistralLlmService();
  return StubLlmService();   // deterministic canned accept/refuse copy
}
```

`StubLlmService` ([`stub_llm_service.dart:10-29`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/llm/stub_llm_service.dart#L10-L29)) returns fixed `stubAccept*/stubRefuse*` strings — deterministic, no network. The `test` runmode's `passwords.yaml` has **no** `mistralApiKey`, which is exactly why tests already get the stub.

**Consequence for e2e:** run the server in `development` mode (real DB, real auth, real routing) **with the `mistralApiKey` secret absent** → every Feed uses the deterministic stub. Internal boundaries stay real (the integration risk), the one expensive/non-deterministic external API is mocked at the seam where the server actually calls out. **No code change required.**

**In-process seam (for contrast, not usable out-of-process):** integration tests reassign the static and self-clean ([`feed_endpoint_test.dart:29-39`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/test/integration/feed_endpoint_test.dart#L29-L39), `feedServiceFactory = ...; addTearDown(() => feedServiceFactory = feedServiceFor);`). A separate-process e2e server can't be reassigned this way — hence the key-presence path is the right lever.

**Net-new only if needed:** a `MISTRAL_API_ENDPOINT` override (env/config) to point the real client at a local mock HTTP server — needed only to test the real serialization/HTTP path or to vary responses per scenario. Not needed for the M3L4 contract.

### Item 2 — Full-stack boot & serving ✅ ready, with one topology correction

**Ports** (`config/development.yaml`): API **8080**, Insights 8081, Web **8082**.
**Server entry:** [`bin/main.dart:5-7`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/bin/main.dart#L5-L7) → `run()` in [`server.dart:21`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/server.dart#L21). Start long-lived: `dart bin/main.dart --apply-migrations` (applies migrations on boot — consistent with `lessons.md`'s `serverpod run start` rule).

**Important topology correction — patrol serves the front-end, not Serverpod.**
The Serverpod web server serves the *production* Flutter build at `http://localhost:8082/app` via `FlutterRoute` ([`server.dart:75-97`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/server.dart#L75-L97), built by `serverpod run flutter_build` → `web/app/`). **patrol does NOT use this.** Per patrol's web docs, `patrol test --device chrome` runs `flutter run -d web-server`, which **builds + serves the app itself** on its own port and drives Chromium via Playwright. So for an e2e run we need only: **Postgres + the Serverpod API (8080)** — patrol owns the web tier.

**How the patrol-served app finds the backend.** The Flutter client resolves its URL via `getServerUrl()` ([`tamagotchi_flutter/lib/main.dart:21-32`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/main.dart#L21-L32)): `--dart-define=SERVER_URL` → bundled `assets/config.json` → fallback `http://localhost:8080`. The bundled [`assets/config.json`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/assets/config.json) already says `http://localhost:8080`, so a patrol build connects to the real backend with no extra wiring. (The dynamic `/app/assets/assets/config.json` route is only relevant to the Serverpod-served build, which patrol bypasses.)

**⚠️ CORS open question.** Under patrol, the app is served from patrol's web-server origin (e.g. `localhost:<random>`) and calls the API at `localhost:8080` — **cross-origin**. Confirm Serverpod's dev CORS config permits this before assuming the flow works. (Not yet verified in code.)

**docker-compose** (`tamagotchi_server/docker-compose.yaml`, included by `.devcontainer/docker-compose.yml`): `postgres` (dev DB `tamagotchi`, container 5432 → host 8090) and `postgres_test` (DB `tamagotchi_test`, 5432 → host 9090), both `pgvector/pgvector:pg16`. Dev config uses host `postgres`; test config uses host `postgres_test`.

**Integration harness (in-process, the contrast):** `withServerpod(...)` ([`feed_endpoint_test.dart:99`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/test/integration/feed_endpoint_test.dart#L99)) boots Serverpod in-process on dynamic ports (`test.yaml` ports = 0), wraps each test in a rolled-back transaction. This is **not** the e2e path — it never serves the web build or opens a socket the browser can hit.

**devcontainer** (`.devcontainer/`): base `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`; Flutter 3.44.0; Serverpod CLI 3.4.8; `libglu1-mesa`, `postgresql-client`; **node feature present** (Node v24 confirmed at runtime); ports 8080/8081/8082/8090 forwarded. The `claude-code-config` volume mounts at `/home/vscode/.claude` (this is why host `~/.claude` skills are invisible here). **No Chromium binary; no `patrol_cli`.**

**Boot sequence for patrol e2e (what works today + the gap):**
```
docker compose up -d                              # Postgres (dev + test)
# run WITHOUT the Mistral secret  → StubLlmService
dart bin/main.dart --apply-migrations             # Serverpod API on :8080
patrol test --device chrome --web-headless true   # patrol builds+serves the web app, drives Chromium → :8080
```
Gap: install `patrol_cli` (`dart pub global activate patrol_cli`); install Chromium + OS libs (`npx playwright install --with-deps chromium`); run Chromium with `--ipc=host --init`.

### Item 3 — Auth session reuse (storageState equivalent) ⚠️ feasible but the soft spot

**Stack:** `serverpod_auth_idp` (server + flutter, 3.4.8). Endpoints `EmailIdpEndpoint`, `JwtRefreshEndpoint`. Token model is **stateless JWT** (`JwtConfigFromPasswords`, [`server.dart:46-55`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/server.dart#L46-L55)). **Dev mode uses a fixed verification code `'12345678'`** ([`server.dart:18`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/server.dart#L18)) so sign-up works **without a real mailer** — a strong enabler for creating e2e test users.

**Client side.** `SignInWidget` from `serverpod_auth_idp_flutter` ([`sign_in_screen.dart:24-35`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/auth/sign_in_screen.dart#L24-L35)) — a **third-party black-box widget** (its internal fields/buttons aren't keyed by us; patrol must find them by text or by inspecting the package). Client built with `FlutterAuthSessionManager`; `await client.auth.initialize()` restores a persisted session before first paint ([`main.dart:25-32`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/main.dart#L25-L32)).

**Where the session lives on web.** `FlutterAuthSessionManager` → `ClientAuthSuccessStorage`, default backed by `flutter_secure_storage ^10.0.0` ([`pubspec.yaml:75`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/pubspec.yaml#L75)) → on Flutter **web this delegates to browser `localStorage`**. Persisted value is an `AuthSuccess { authStrategy, token (JWT), authUserId, scopeNames }` (shape visible in [`app_router_redirect_test.dart:31-36`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/test/app/app_router_redirect_test.dart#L31-L36); widget tests swap in an `_InMemoryAuthStorage`, l.12-20).

**Integration-test auth (in-process only):** `TestSessionBuilder` + `AuthenticationOverride.authenticationInfo(userUuid, scopes)` ([`feed_endpoint_test.dart:42-48`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/test/integration/feed_endpoint_test.dart#L42-L48)) — no real token. **Not reusable** for browser e2e (the browser needs a real JWT in storage).

**One creature per account** is DB-enforced: unique index on `ownerUuid` (`creature.spy.yaml`), set from `session.authenticated!.userIdentifier` at hatch ([`creature_endpoint.dart:24-27`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/creature/creature_endpoint.dart#L24-L27)). Tests seed creatures by direct `Creature.db.insertRow` + `CreaturePersonality.db.insertRow`.

**storageState equivalent — options, ranked:**
- **(a) UI login once per run (simplest, most robust on patrol web).** Drive `SignInWidget` once at suite start. This *is* one of the two dedicated auth scenarios anyway. Cost: a few seconds per run; no storage-internals coupling.
- **(b) Seed the JWT into `localStorage` before each test.** Because JWTs are stateless (signature-verified, no server revocation), a captured `AuthSuccess` can be re-injected. Blocker: patrol web's `$.platform.web` surface exposes **cookies**, not a documented `localStorage` setter; and the exact `flutter_secure_storage` web key must be captured empirically. Injection likely needs a Playwright-layer JS eval — **verify patrol exposes that on web**.
- **(c) DB-seed user + creature for deterministic state**, combined with (a) or (b) for the token. Mirrors the integration seeding pattern; good for putting the creature in a known stat state.

**Recommendation for the plan:** start with **(a) login-once helper** (works on patrol web with no storage-internals coupling); treat (b) as an optimization to prove out later. This is the single least-certain piece of the wiring — flag it as the top open question.

### Item 4 — Widget keys/semantics inventory ✅ mostly text-findable; one correction

**Global facts:** **zero** `Key`s, **zero** `Semantics`, and **no** `SemanticsBinding.instance.ensureSemantics()` anywhere across 12 non-generated Dart files.

**Correction (important):** patrol's `$` finder operates on the **Flutter widget tree** (it's `patrol_finders`, the same `Finder` model as `flutter_test`), reached via patrol's in-browser `js_interop` bridge — **not** the DOM accessibility tree. Therefore `ensureSemantics()` and `Semantics`/ARIA annotations are **NOT required for patrol** (they were the *raw-Playwright* requirement the frame rejected). One sub-agent recommended adding `ensureSemantics()` — that recommendation applies to raw Playwright, not patrol; **do not adopt it** unless we later need DOM-level assertions.

**Stable text finders that already exist** (usable as `$('...')` immediately): `'AI-Tamagotchi'`, `'Log out'`, `'Sign in'`, `'Hatch'`, `'Feed'`, `'Retry'`, `'No creature yet — hatch one to begin'`, `'Feeding…'`, `'Mood: …'`, stat labels `'Hunger'/'Energy'/'Love'/'Illness'`, and the feed/hatch error strings.

**Net-new `Key`s recommended (~7), by priority:**
| Element | File:line | Why a Key |
|---|---|---|
| Hatch name field | [`hatch_form.dart:59`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/creature/hatch_form.dart#L59) | `TextField` — labelText "Name" findable but a `Key('hatchNameField')` is unambiguous |
| Hatch button | [`hatch_form.dart:76`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/creature/hatch_form.dart#L76) | text "Hatch" works; Key adds resilience |
| Feed button | [`creature_view.dart:58`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/creature/creature_view.dart#L58) | text "Feed" works; Key adds resilience |
| Hatch/Home/Feeding spinners | `hatch_form.dart:72`, `home_screen.dart:41`, `creature_view.dart:92` | `CircularProgressIndicator` is invisible to text finders — Key needed to assert loading/wait states |
| Feed response container | [`creature_view.dart:119`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/creature/creature_view.dart#L119) | distinguish accepted vs refused state beyond color |
| Per-stat value rows | `creature_view.dart:44-47` | to assert a *specific* stat changed (dynamic numbers) |

Roughly **13/20 interactive elements are already text-findable; ~7 need a Key**. The `SignInWidget` internals (Item 3) are the one true unknown.

### Item 5 — `10x-e2e` skill internals + Playwright→patrol translation

Installed at `/workspaces/nabrudno/.claude/skills/10x-e2e/` (SKILL.md + 5 references). It is a **plan-driving skill** (the E2E sibling of `/10x-implement` and `/10x-tdd`), not just a reference pack — it reads the same `plan.md` and mutates the same `## Progress`.

**Hard constraints that conflict with our stack:**
- **Setup STOPs if no Playwright** ([SKILL.md:111-122](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/.claude/skills/10x-e2e/SKILL.md#L111-L122)): "no `playwright.config.*`, no `*.spec.ts` → STOP… won't set it up."
- **`allowed-tools` hardwire `mcp__playwright__*`** (SKILL.md frontmatter l.17-24) — no patrol/marionette tools.
- Browser-driven path assumes a Playwright **CLI** (~27K tokens) or **MCP** (~114K tokens) (`browser-driven-generation.md`).

→ **Do not invoke `/10x-e2e` verbatim on this repo** (it would halt at the Setup gate). Use it as the **contract source** and run the loop with patrol/marionette tooling. The skill's **"Other stacks"** section sanctions exactly this ([SKILL.md:393-395](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/.claude/skills/10x-e2e/SKILL.md#L393-L395)): *"encode your tool's idioms… into your own variant of these levers and drive its own runner. The principles transfer; the syntax doesn't."*

**The tool-agnostic contract we keep:**
- **Two quality levers** = a seed test + an E2E rules file the agent reads automatically; *what the seed shows is what gets generated* (`seed-test-pattern.md`).
- **The loop**: PLAN (pick one risk; explore the running app; map happy + edge path) → GENERATE (one test per risk from the levers) → REVIEW (five anti-patterns; re-prompt by name) → VERIFY (run green, then **deliberately break** the protected behavior and confirm red; revert).
- **Eligibility gate** before each phase: browser-level fit **and** feature built **and** no existing passing test. Tight budget: **1 test per risk, 1–3 per phase** — protect a named risk, never chase coverage.
- **The five anti-patterns** (`e2e-anti-patterns.md`): ① hallucinated assertion, ② brittle selector, ③ shared state, ④ `waitForTimeout`, ⑤ no cleanup.
- **Real vs mocked**: internal boundaries (auth/routing/DB) stay **real**; mock expensive/non-deterministic external APIs at the network layer — **with the explicit caveat** ([SKILL.md:246](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/.claude/skills/10x-e2e/SKILL.md#L246)) that a **server-side** API can't be `page.route()`'d — "mock it where the server actually calls out." → our key-presence stub (Item 1).
- **VERIFY-by-deliberate-break** and the **commit-only-on-green** invariant.

**Playwright → patrol/Dart translation table** (the heart of the adaptation):

| M3L4 / Playwright idiom | patrol / Dart equivalent for this project |
|---|---|
| `getByRole`/`getByLabel`/`getByText` primary; `getByTestId` fallback | `$` finders: `$('Feed')` (text), `$(#feedButton)` (Key), `$(ElevatedButton)` (type). Prefer **Key + visible text**; treat raw `byType`/index as the "brittle selector" anti-pattern |
| Ban CSS selectors / XPath / DOM structure | N/A (no DOM on CanvasKit). Equivalent ban: widget-tree **index** and fragile ancestor chains |
| `page.waitForTimeout()` banned | `await $.pumpAndSettle()` / finder auto-wait / `waitUntilVisible()`; never fixed delays |
| `toBeVisible()` / `waitForURL()` / `waitForResponse()` | `expect($('…'), findsOneWidget)`, `await $('…').waitUntilVisible()`; route-level waits via `pumpAndSettle` |
| `storageState` (login once, reuse `auth.json`) | **Item 3** — login-once helper (recommended) or seed the JWT into `localStorage`; reuse the stateless Serverpod JWT |
| Mock external API at network layer (`page.route` OpenRouter) | **Boot server without `mistralApiKey` → `StubLlmService`** (server-side seam). `page.route()` cannot reach the server-side Mistral call |
| unique data + `afterEach` cleanup | timestamped creature names + **FR-010 Reset** / DB teardown; patrol `tearDown` |
| `seed.spec.ts` (TypeScript) | a **seed patrol test in Dart** modeling the four patterns |
| E2E rules file (`CLAUDE.md`/`.cursor/rules`) | a **patrol E2E rules file** in the test dir (or a CLAUDE.md addition), with the table above baked in |
| Playwright CLI/MCP browser-driven exploration | **marionette MCP** drives a debug build to explore + screenshot, then author patrol tests; or patrol's own iteration. *(marionette web support is tagged-but-undocumented — see below; not load-bearing.)* |
| `playwright test <spec>` (single-spec + CI) | `patrol test --target <file> --device chrome --web-headless true` |
| `--caps=vision` visual supplement | patrol screenshots / marionette `take_screenshots` |

### External tooling facts (patrol / marionette / devcontainer)

- **patrol owns build+serve+drive of the front end** via `flutter run -d web-server` + auto-launched Playwright/Chromium; it does **not** manage the backend (we bring up Serverpod + Postgres). Source: patrol.leancode.co/documentation/web, leancode.co/blog/patrol-web-support.
- **Install chain (web):** `dart pub global activate patrol_cli` → `patrol doctor` → `flutter pub add patrol --dev`. **Node must pre-exist** (have it: v24). Playwright + Chromium **auto-install on first `patrol test`**, but the **apt OS libs are not** — in a container run `npx playwright install --with-deps chromium` once, and run Chromium with `--ipc=host --init`. Native (Android/iOS) setup is **not** needed for web.
- **patrol web maturity:** usable since patrol 4.0; **no develop/watch mode on web** (run-once per invocation, upstream Flutter limitation); **Linux-web parity is under-documented** (architecture is OS-agnostic; an open issue exists for Windows web) — **verify empirically**. Web-specific gotcha: subscribe to native dialogs (`acceptNextDialog()`) *before* triggering them. Exact exit-code/artifact paths are undocumented — verify.
- **marionette** = an MCP server (`dart pub global activate marionette_mcp`) driving a **debug** build via the VM Service; `MarionetteBinding.ensureInitialized()` must replace `WidgetsFlutterBinding` in `main.dart` under `kDebugMode`; register as a Claude Code MCP server. Tools: `connect`, `get_interactive_elements`, `tap`, `enter_text`, `scroll_to`, `take_screenshots`, `get_logs`, `hot_reload`. **Web is platform-tagged but completely undocumented**, and the DWDS VM-service-extension path is a known sharp edge — **prove it works before depending on it**. → marionette is a *nice-to-have* exploration assist, **patrol is the supported path**.

---

## Code References

- [`tamagotchi_server/lib/src/llm/llm_service.dart#L77-L88`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/llm/llm_service.dart#L77-L88) — **key-presence LLM selection** (the e2e mock lever)
- [`tamagotchi_server/lib/src/llm/stub_llm_service.dart#L10-L29`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/llm/stub_llm_service.dart#L10-L29) — deterministic stub copy
- [`tamagotchi_server/lib/src/llm/mistral_client.dart#L17-L95`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/llm/mistral_client.dart#L17-L95) — hardcoded endpoint, key, no timeout
- [`tamagotchi_server/lib/src/creature/feed_service.dart#L159-L167`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/src/creature/feed_service.dart#L159-L167) — `feedServiceFactory` seam
- [`tamagotchi_server/lib/server.dart#L46-L97`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/lib/server.dart#L46-L97) — auth init (JWT, dev verification code l.18) + `FlutterRoute` serving (production only)
- [`tamagotchi_flutter/lib/main.dart#L21-L32`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/lib/main.dart#L21-L32) — `getServerUrl()` + `FlutterAuthSessionManager` + `auth.initialize()`
- [`tamagotchi_flutter/assets/config.json`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_flutter/assets/config.json) — `apiUrl: http://localhost:8080`
- [`tamagotchi_server/test/integration/feed_endpoint_test.dart#L29-L48`](https://github.com/sotomski/tamagotchi/blob/c50a0b9f875c272d9722534d5deff854cf16f5b8/tamagotchi_server/test/integration/feed_endpoint_test.dart#L29-L48) — in-process seam reassignment + `AuthenticationOverride`
- `tamagotchi_flutter/lib/creature/{creature_view.dart, hatch_form.dart}`, `lib/home/home_screen.dart`, `lib/auth/sign_in_screen.dart` — UI finder inventory (Item 4)
- `.claude/skills/10x-e2e/SKILL.md` + `references/*.md` — the contract to adapt (Item 5)
- `.devcontainer/{Dockerfile, docker-compose.yml, devcontainer.json}` + `tamagotchi_server/docker-compose.yaml` — infra/ports

## Architecture Insights

- **The "external API" boundary for this app is a service seam, not the network edge.** The lesson's network-layer mock assumes a client-side API call; here the Mistral call is server-side, so the correct mock point is the `llmServiceFor` key-presence switch. The codebase already implements this switch for tests — e2e reuses it for free.
- **patrol and Serverpod own disjoint tiers.** patrol = front-end (build/serve/drive); Serverpod = API + DB. The Serverpod-served `/app` route is irrelevant under patrol. This cleanly separates "what we boot" (Postgres + API, no Mistral key) from "what patrol boots" (the Flutter web app).
- **patrol finds widgets, not DOM nodes.** This is the whole reason patrol beats raw Playwright on CanvasKit — and it means the no-`Semantics` state of the UI is fine; we add `Key`s, not ARIA.
- **Statelessness is the auth lever.** JWT-by-signature (no server revocation) is what makes a captured token reusable across tests; the dev fixed verification code makes fresh test users cheap.

## Historical Context (from prior changes)

- `context/changes/playwright-for-flutter/frame.md` — the framing this research grounds (patrol = TOOL, marionette = ASSIST, raw Playwright REJECTED, M3L4 contract = tool-agnostic TARGET). Confidence HIGH; this research confirms it and resolves the integration unknowns it deferred.
- `context/foundation/test-plan.md:123` — §4 currently `e2e: none`; §7 lists e2e as deliberately excluded. The frame anticipates flipping these to `patrol` for the curriculum exercise (a plan/`/10x-test-plan` decision, not made here).
- `context/foundation/lessons.md` — the `feedServiceFactory` single-seam rule (entry "Inject impure collaborators via one production-default factory seam") is exactly the seam Item 1 leans on; `serverpod run start` migration rule and `dart format` gate apply to any code we touch.

## Related Research

- None prior in `context/changes/**/research.md` for this change (this is the first research artifact for `playwright-for-flutter`).

## Open Questions (for /10x-plan to resolve)

1. **Auth session reuse on patrol web (top risk).** Confirm whether patrol web can inject `localStorage` (for JWT seeding) or whether we standardize on a **login-once UI helper**. Capture the `flutter_secure_storage` web key empirically if pursuing seeding.
2. **CORS.** Verify Serverpod's dev CORS config accepts requests from patrol's web-server origin → `localhost:8080`. If not, this needs a config tweak.
3. **patrol Linux-web parity.** Docs are thin on Linux web; do a smoke run (`patrol test --device chrome --web-headless`) on a trivial test before building the suite. Confirm exit codes/artifact paths empirically.
4. **Which risks are genuinely browser-level?** Most `test-plan.md` risks are unit/hermetic/integration (R1/R2 unit, R3/R7 hermetic, R4 integration, R6 contract). The browser-level candidates are the **cross-boundary authenticated flow** (login → hatch → feed → response + journal **survive a page reload**) and **R5 ownership at the UI** (a user only ever sees their own creature). Decide the 1–3 e2e risks with the plan (this also touches the §4/§7 test-plan flip).
5. **Devcontainer image change.** Adding Chromium + Playwright OS libs to the Dockerfile vs. installing at test time — decide persistence strategy; verify headless Chromium runs (`--ipc=host --init`) under the container's resources.
6. **marionette on web — spike or drop?** Decide whether to spike marionette-over-DWDS (undocumented) or rely on patrol's own iteration for authoring and keep marionette out of the load-bearing path.
7. **Net-new `Key`s.** ~7 `Key`s (spinners, hatch field, feed-response container, stat values) — land them in the same phase as the seed test, or a dedicated annotation phase?
