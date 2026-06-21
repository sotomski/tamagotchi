---
date: 2026-06-05T15:02:18+0000
researcher: Karol Sotomski
git_commit: c1eb1f93d2b12f1baad02622718f2229c4604e91
branch: hatch-creature-and-view-stats
repository: nabrudno
topic: "Hatch a creature and view its stats (S-02) — data model, endpoint, and Flutter surface"
tags: [research, codebase, serverpod, creature, journal, riverpod, stats, mood, S-02]
status: complete
last_updated: 2026-06-05
last_updated_by: Karol Sotomski
---

# Research: Hatch a creature and view its stats (S-02)

**Date**: 2026-06-05T15:02:18+0000
**Researcher**: Karol Sotomski
**Git Commit**: c1eb1f93d2b12f1baad02622718f2229c4604e91
**Branch**: hatch-creature-and-view-stats
**Repository**: nabrudno

## Research Question

S-02 from `context/foundation/roadmap.md`: a logged-in user can **hatch one creature** (randomized personality traits as continuous values) and **see its stats** (hunger / energy / love / illness) plus a **derived mood**. Stats are mechanical — no AI yet. How should this be built on top of the S-01 auth slice, and what does the data model need to be? The roadmap flags this slice's risk as *"it fixes the data model for creature + journal"* — so the model decisions made here are load-bearing for S-03–S-09.

## Summary

This is the **first first-party persisted data model** in the project. Everything that exists today is either the S-01 auth module (`serverpod_auth_idp`, fully wired) or the default scaffold `Greeting` class — which has its `table:` key **commented out**, so it is a wire-only serializable, *not* an ORM precedent. S-02 introduces the first `CREATE TABLE`, the first first-party endpoint with `requireLogin`, the first migration with a first-party table, and the first async-data Riverpod provider on the Flutter side.

The mechanical shape of the work is well-bounded and the conventions are all in place (group-by-feature dirs, the `serverpod generate` cycle, Riverpod codegen, the S-01 widget-test harness). **The real open work is the oracle, not the plumbing:** the sources name the four stats and four trait exemplars but are **silent on stat ranges, initial values at hatch, the trait model's numeric shape, and — most importantly — the mood derivation formula**. Those must be decided in `/10x-plan` (PRD guardrail: "Stats are deterministic given inputs", so whatever formula is chosen must be pure/deterministic). The roadmap also says the slice "fixes the data model for creature **and journal**" — so the **journal table should be defined now** even though no narrative entry is written until S-03 (no AI at hatch).

## Decision oracle — what the slice must do (from sources, not implementation)

| # | Oracle question | Status | Source |
| --- | --- | --- | --- |
| A | Personality traits exist, randomized at hatch, **continuous values** | RESOLVED | `prd.md:60` (FR-002), `roadmap.md:109` |
| A | Trait exemplars named: **picky / gluttonous** (Feed axis), **introvert / extravert** (Pet axis) | RESOLVED (exemplars) | `prd.md:51,72,74`; `roadmap.md:135`; `shape-notes.md:86,109` |
| A | Numeric trait range (min/max), and whether they're 4 independent traits or 2 bipolar axes | **UNSPECIFIED** | sources silent |
| B | Four stats: **hunger, energy, love, illness** | RESOLVED | `prd.md:66` (FR-003), `roadmap.md:109`, `shape-notes.md:101` |
| B | Stat value ranges / units (e.g. 0–100) | **UNSPECIFIED** | sources silent |
| B | Initial stat values at hatch | **UNSPECIFIED** | sources silent |
| C | A **derived mood** must be displayed | RESOLVED (exists) | `prd.md:66`, `roadmap.md:109`, `shape-notes.md:101` |
| C | The **formula** deriving mood from the four stats | **UNSPECIFIED** | sources silent — design decision |
| C | Stat display = **raw numbers for MVP** (not mood icons) | RESOLVED | `prd.md:117` (Open Q #2), `shape-notes.md:150` |
| D | Journal **data model** is in scope (this slice "fixes the data model for creature + journal") | RESOLVED | `roadmap.md:117` (S-02 risk) |
| D | Journal schema = **timestamp + narrative-prose + state-change record**, no vector column | RESOLVED | `roadmap.md:117`; `prd.md:53` (US-01 AC) |
| D | Whether hatch **writes** a journal entry | **UNSPECIFIED** (sources tie narrative entries to S-03+; no AI at hatch) | `roadmap.md:109,122` |
| E | Deterministic guardrail: same traits + same inputs ⇒ same stats & mood | RESOLVED | `prd.md:39` (Guardrails) |
| F | Trait-constraint guardrails (degenerate all-max/all-min) | RESOLVED: **no constraint for MVP**, tune later | `prd.md:61,116` (Open Q #1); `roadmap.md:116` |

**Explicitly DEFERRED past S-02 — do not pull in** (`roadmap.md`):
- Real-time stat **decay** + energy **regen** → S-07 (`roadmap.md:170-182`). S-02 stats are static after hatch.
- **AI responses** + narrative journal generation → S-03 (`roadmap.md:120-131`).
- **Feed / Pet / Cure** interactions + personality modifiers + energy-cost rules → S-03–S-05.
- **Empty-energy gate** → S-06. **Journal reading screen** → S-08. **Reset / re-hatch** → S-09.

S-02 = **hatch + view only**. No stat-changing logic, no AI, no interaction handlers.

## Detailed Findings

### 1. Backend — model, endpoint, DB, migration (`tamagotchi_server/`)

**Versions** (`tamagotchi_server/pubspec.yaml`): `serverpod: 3.4.8`, `serverpod_auth_idp_server: 3.4.8`, Dart SDK `^3.8.0`. `http: ^1.6.0` already present (added in S-01's REST email pivot).

**No first-party persisted model exists yet.** `find lib/src -name '*.spy.yaml'` returns exactly one file — `tamagotchi_server/lib/src/greetings/greeting.spy.yaml` — and its `table:` key is **commented out** (`greeting.spy.yaml:13`), so `Greeting` is a serializable-only class with no DB table. **The creature table will be the project's first first-party `CREATE TABLE`.** All other `.spy.yaml` files live inside the installed auth packages in pub-cache.

**Canonical `.spy.yaml` for a persisted model** (from the `serverpod-models` skill + real auth-module examples):
```yaml
class: Creature
table: creature
fields:
  id: UuidValue?, defaultPersist=random_v7   # UUID PK — the pattern the auth tables use
  ownerUuid: UuidValue                        # the auth user (see relation nuance below)
  name: String
  # ...trait + stat fields (double for continuous traits, int/double for stats)...
  hatchedAt: DateTime, default=now
indexes:
  creature_owner_idx:
    fields: ownerUuid
    unique: true                              # one-creature-per-user, DB-authoritative
```
- Scalar types available: `bool, int, double, String, Duration, DateTime, ByteData, UuidValue, Uri, BigInt`, generated enums/classes, `List/Map/Set`. Nullable with `?`; defaults via `default=`, `defaultPersist=`.
- Enum models are a separate file: `enum: CreatureMood` / `values:` (only needed if mood is stored as an enum rather than derived on read — see Open Questions).

**Relation-to-auth-user nuance (important).** `config/generator.yaml` has **no `modules:` nickname block** (it contains only `type` / `client_package_path` / `server_test_tools_path`). So the skill's `module:auth:AuthUser` relation shorthand will **not** resolve as-is. The proven in-repo pattern is what the auth tables themselves do: store the owner as a **plain `UuidValue` scalar column**, not a cross-module DB FK. The migrated auth tables hold `"authUserId" uuid NOT NULL` as a bare uuid (`migrations/20260521163433251/migration.sql:245`). **Recommendation:** `ownerUuid: UuidValue` scoped in application code, mirroring `authUserId`. (Alternative: add a `modules:` nickname to `generator.yaml` first — extra surface, not needed for MVP.)

**Endpoint convention** (`tamagotchi_server/CLAUDE.md:9-11`; precedent `lib/src/greetings/greeting_endpoint.dart`, `lib/src/auth/email_idp_endpoint.dart`): an `Endpoint` subclass in the feature dir auto-registers (no manual wiring) — visible in generated `lib/src/generated/endpoints.dart`. Client name = class name minus `Endpoint`, lowercased (`GreetingEndpoint` → `client.greeting`; so `CreatureEndpoint` → `client.creature`).
```dart
class CreatureEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;                       // gate; base default is false

  Future<Creature> hatch(Session session, String name) async { ... }
  Future<Creature?> myCreature(Session session) async { ... }
}
```
`requireLogin` is a virtual getter on the base `Endpoint` (`serverpod-3.4.8/lib/src/server/endpoint.dart:35,39`).

**Authenticated user id inside a method:** `session.authenticated` returns `AuthenticationInfo?` (`serverpod-3.4.8/lib/src/server/session.dart:66`); `.userIdentifier` is the auth user's UUID **as a `String`** (`authentication_info.dart:16-19`). With `requireLogin => true` it is non-null inside the method:
```dart
final uuid = UuidValue.fromString(session.authenticated!.userIdentifier);
```
(There is no `AuthSuccess`-on-session path server-side; `AuthSuccess` is a client login-result model.)

**DB access (Serverpod 3.4 ORM, `serverpod-database` skill):** all calls take `session` first, live on `Model.db`:
- `await Creature.db.insertRow(session, creature)`
- `await Creature.db.findFirstRow(session, where: (t) => t.ownerUuid.equals(uuid))`
- `await Creature.db.find/updateRow/deleteRow(...)`, filters via `where: (t) => ...` with `.equals/.inSet/&|~`, transactions via `session.transaction((tx) async {...})`.

**One-creature-per-user — two layers (use both):**
1. **DB unique index** on `ownerUuid` in the `.spy.yaml` `indexes:` block — authoritative, race-safe (a concurrent double-hatch hits the constraint).
2. **Application pre-check** in `hatch`: `findFirstRow(ownerUuid == uuid)`; if non-null, throw a serializable "already hatched" exception instead of inserting. The unique index is the backstop. (Per root `CLAUDE.md` test guidance: a non-atomic check-then-insert means the unique-constraint branch is integration-tested against real DB, not mocked.)

**Migration cycle** (`tamagotchi_server/CLAUDE.md:13-16`): after editing the `.spy.yaml`, `serverpod generate` then `serverpod create-migration` (from `tamagotchi_server/`) — produces a new timestamped sibling under `migrations/` + a new `migration_registry.txt` line. Apply locally with `dart bin/main.dart --apply-migrations` (Postgres sidecar up: `docker compose up -d`); scloud applies at deploy/startup. Existing baseline migration: `migrations/20260521163433251/` (auth + serverpod only — no first-party table yet). Never hand-edit an applied migration.

**Feature-dir placement** (root `CLAUDE.md`, names this exact example): `tamagotchi_server/lib/src/creature/{creature.spy.yaml, creature_endpoint.dart, creature_service.dart}` (+ a `journal*.spy.yaml` for the journal table). Generated output mirrors the dir: `lib/src/generated/creature/creature.dart` and `tamagotchi_client/lib/src/protocol/creature/creature.dart`. Precedent: `lib/src/auth/` and `lib/src/greetings/` both co-locate model + endpoint.

### 2. Frontend — home, providers, RPC, tests (`tamagotchi_flutter/`)

**Current home** (`tamagotchi_flutter/lib/home/home_screen.dart`, read in full): already a `ConsumerWidget` (`:14`). `AppBar` with a `TextButton.icon` "Log out" → `ref.read(serverpodClientProvider).auth.signOutDevice()` (`:26-31`) — this is the **call-site shape** any new RPC follows (read client off provider, call a method). `body` is a `const Center` holding the single `Text('No creature yet — hatch one to begin')` (`:34-42`). The docstring (`:11-12`) explicitly notes "no Hatch button (hatching is S-02)". **S-02's UI work slots exactly here:** drop the `const`, and render a conditional — empty-state + Hatch button when no creature, stats view when a creature exists.

**Provider convention:** `@Riverpod(keepAlive: true)` on a top-level function, `part '<file>.g.dart'` committed, regenerated by `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi_flutter/`. `serverpodClientProvider` (`lib/app/client_provider.dart:13`) throws in-body and is injected via `overrideWithValue(client)` in `main.dart:38`. Consumed with `ref.read(...)` (actions) / `ref.watch(...)` (build). **All existing providers are synchronous `Provider`s — there is no FutureProvider/AsyncNotifier anywhere in `lib/`. S-02 introduces the first async-data provider.** Canonical codegen async form (`riverpod-providers` skill): `@riverpod Future<T> foo(Ref ref) async {...}`, rendered via `AsyncValue.when(loading/error/data)`. For the Hatch *action* (button → loading → result), the `riverpod-mutations` skill is the idiomatic fit; an `AsyncNotifier` holding the creature state also works. Pin fetch providers `keepAlive: true` to match repo convention.

**Generated client RPC shape** (`tamagotchi_client/lib/src/protocol/client.dart`): each endpoint is an `EndpointXxx extends EndpointRef` field on `Client`. Existing: `emailIdp`, `jwtRefresh`, `greeting` (`:307-320`) — **no `creature` yet**. Example (`EndpointGreeting.hello`, `:253-258`):
```dart
Future<Greeting> hello(String name) =>
    caller.callServerEndpoint<Greeting>('greeting', 'hello', {'name': name});
```
`client.creature.hatch(name)` generates identically once the server endpoint exists. **Backend comms go only through the generated `tamagotchi_client` + Serverpod model classes** (root `CLAUDE.md`) — the stats model (incl. mood, if server-derived) must be a generated Serverpod model, so `serverpod generate` runs before the Flutter side compiles.

**Feature-dir placement** (root `CLAUDE.md`, exact example): `tamagotchi_flutter/lib/creature/{creature_screen.dart, creature_state.dart}` (+ committed `.g.dart`). The router has only `/` → `HomeScreen` and `/sign-in` (`app_router.dart`) — the **empty state and the stats view are two states of the same `/` route**. Most consistent: keep `HomeScreen` as the `/` host and render a `lib/creature/` widget inside its body based on the async creature state; no new route unless a distinct URL is wanted (PRD gives none).

**Build commands:** Flutter codegen `dart run build_runner build --delete-conflicting-outputs` (from `tamagotchi_flutter/`); RPC client regen `serverpod generate` (from `tamagotchi_server/`); web build `serverpod run flutter_build` (from `tamagotchi_server/`, output → `tamagotchi_server/web/app/`). `riverpod_lint` is **inert** in this workspace ([[project_riverpod_lint_inert_in_pub_workspace]]) — Riverpod-rule violations need manual review.

**Widget-test harness (reuse from S-01):** `test/app/app_router_redirect_test.dart` and `test/home/home_screen_test.dart` exist (tests mirror `lib/` feature layout → S-02 adds `test/creature/...` or extends `test/home/`). The S-01 pattern: a real `Client('http://localhost:8080/')` wired to `FlutterAuthSessionManager(storage: _InMemoryAuthStorage())` so auth state is controllable with no network/secure-storage; pumped via `UncontrolledProviderScope` + `AppWidget`; auth flipped with `client.auth.updateSignedInUser(...)`; a `_drainBenignOverflow` helper swallows the SignInWidget's known overflow only. **`home_screen_test.dart:93,96` currently assert the "No creature yet" copy and `find.byType(ElevatedButton) → findsNothing` — adding a Hatch button breaks these by design; S-02 must update them.** Because the harness uses a *real* client (not a mock), the cleanest way to test loading/error/data of hatch+stats is to **override the new creature provider** (`creatureProvider.overrideWith(...)` returning canned `AsyncValue`s) rather than round-trip the RPC (`riverpod-overrides` / `riverpod-testing` skills).

## Code References

- `tamagotchi_server/lib/src/greetings/greeting.spy.yaml:10-24` — only first-party `.spy.yaml`; `table:` commented out (not an ORM precedent).
- `tamagotchi_server/lib/src/greetings/greeting_endpoint.dart` — first-party `Endpoint` precedent.
- `tamagotchi_server/lib/src/auth/email_idp_endpoint.dart`, `jwt_refresh_endpoint.dart` — auth endpoints (thin module subclasses).
- `tamagotchi_server/lib/src/generated/endpoints.dart` — auto-registration registry; client-name derivation.
- `tamagotchi_server/config/generator.yaml` — **no `modules:` nickname** (drives the `ownerUuid` scalar decision).
- `tamagotchi_server/migrations/20260521163433251/migration.sql:245` — auth tables store `authUserId uuid` (the owner-as-scalar precedent).
- `tamagotchi_server/CLAUDE.md:4,9-16` — generate cycle, endpoints, migrations.
- `tamagotchi_flutter/lib/home/home_screen.dart:14,26-31,34-42` — ConsumerWidget home; log-out RPC call-site; the empty-state slot S-02 replaces.
- `tamagotchi_flutter/lib/app/client_provider.dart:13` — `serverpodClientProvider` (throws; injected via override).
- `tamagotchi_flutter/lib/main.dart:38` — `serverpodClientProvider.overrideWithValue(client)`.
- `tamagotchi_client/lib/src/protocol/client.dart:253-258,307-320` — RPC call shape + endpoint registry (no `creature` yet).
- `tamagotchi_flutter/test/home/home_screen_test.dart:13-30,51-79,93,96` — reusable test harness; assertions S-02 must update.
- `context/foundation/prd.md:39,51,53,60-61,66-68,72-74,116-117` — oracle (guardrails, traits, stats, mood, open questions).
- `context/foundation/roadmap.md:107-118` (S-02), `:120-206` (S-03–S-09 deferral boundary).

## Architecture Insights

- **This slice sets schema precedent for the whole product.** Creature + journal tables, the owner-scoping pattern (`ownerUuid` scalar), and the stat/trait numeric model will be reused/extended by S-03–S-09. Getting the column set and ranges right now avoids a migration churn later (the roadmap's stated risk). The roadmap explicitly says define the **journal** model here too, even though no narrative entry is written until S-03 — so the table lands now, the content arrives later.
- **Determinism is a hard PRD guardrail** (`prd.md:39`): mood derivation and any hatch-time stat seeding must be pure functions of their inputs. Randomization at hatch is the *one* sanctioned source of nondeterminism (trait rolls) — and even that should be isolated so the rest stays testable. This points at a `creature_service.dart` with a pure mood function (easy to unit-test) separate from the endpoint's DB I/O.
- **Owner-as-scalar, not cross-module FK** — dictated by the absent generator nickname; matches how auth stores `authUserId`. Keep scoping in app code (`where ownerUuid.equals(uuid)`), unique index for the one-per-user invariant.
- **First async surface on the client** — S-02 establishes the `AsyncValue.when` + provider-override-in-tests pattern that every later interactive slice (feed/pet/cure) will copy. Worth setting cleanly.
- **Group-by-feature** is already the lived convention (`lib/src/auth/`, `lib/src/greetings/`, `lib/home/`, `lib/auth/`, `lib/app/`); creature code joins it as `lib/src/creature/` (server) and `lib/creature/` (Flutter).

## Historical Context (from prior changes)

- `context/changes/signed-in-empty-creature-view/` (S-01) — built the auth vertical slice this stacks on: route guard, `serverpodClientProvider`, the `ConsumerWidget` home with log-out, and the widget-test harness. Its `plan.md` documents the build/codegen commands and the `riverpod_lint`-inert caveat. S-01 deliberately stopped at the **empty** home with **no Hatch button** — S-02 adds the button and everything behind it.
- S-01 `research.md:104` already scoped the forward hook for this slice: "Protecting future endpoints — override `requireLogin => true`; inside a method `session.authenticated` → `userIdentifier`. Relevant for **S-02's creature endpoints**, not S-01." This research confirms and details that path.
- `context/changes/frontend-state-mgmt-routing-scaffold/` (F-01) — the go_router + Riverpod baseline; established `@Riverpod(keepAlive: true)` + committed `.g.dart`.

## Related Research

- `context/changes/signed-in-empty-creature-view/research.md` — the S-01 auth research (auth API, client wiring, provider conventions) this builds directly on.

## Open Questions

These are **design decisions for `/10x-plan`**, not codebase unknowns. Sources are silent; the PRD determinism guardrail (`prd.md:39`) constrains the answers.

1. **Trait model — shape + range.** Four named exemplars sit on two bipolar axes (picky↔gluttonous = Feed; introvert↔extravert = Pet). Model as **2 continuous axis values** (e.g. one `double` per axis) or **4 independent trait doubles**? Range (e.g. `0.0–1.0`)? FR-002 only says "continuous values". *Recommendation:* the simplest forward-compatible choice — a small fixed set of named `double` traits in a known range — since S-03+ reads them as modifiers. **Decide in plan.**
2. **Stat ranges + initial values at hatch.** Stats named but unbounded in sources. Pick a range (a `0–100 int` is the obvious convention) and the **hatched** starting values (e.g. fed/rested/loved/healthy baseline). The stat floor (`prd.md:68`, FR-008) is an **S-07** concern but the chosen range should leave room for it. **Decide in plan.**
3. **Mood derivation formula (the key gap).** `prd.md:66` requires a "derived mood" but no formula exists anywhere. Must be a **pure, deterministic** function of the four stats (per `prd.md:39`). Open sub-decisions: is mood an **enum** (happy/content/sad/sick…) or a scalar? Derived **on read** (server computes, returns with stats — keeps it un-stored and always-consistent) or **stored**? *Recommendation:* derive on read in `creature_service.dart` as a pure function; do not store it. **Decide in plan** — this is the single biggest oracle gap; if the rule isn't obvious, the 10x oracle rule says *stop and ask the user* rather than guess.
4. **Does hatch write a journal entry?** The roadmap wants the **journal table defined** in this slice, but narrative entries are an S-03 (AI) concern and there's no AI at hatch. Options: (a) define the journal table, write **no** entry at hatch; (b) write a minimal non-narrative "hatched" state-change record (timestamp + event, empty/placeholder prose). *Recommendation:* (a) — define the schema, defer all writes to S-03 — unless the user wants a "born" marker. **Confirm in plan.**
5. **Trait guardrails** — RESOLVED by sources: **no constraint for MVP** (`prd.md:116`); full randomization, tune later. No action needed beyond a note.
6. **Endpoint surface** — `hatch(session, name)` + `myCreature(session)` is the minimal pair (create + read-for-display). Confirm whether the user names the creature at hatch or it's auto/anonymous (PRD/roadmap don't say a name is required — US-01 doesn't mention naming). **Confirm in plan.**
