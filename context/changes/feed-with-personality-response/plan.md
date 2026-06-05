# Feed the creature once and get a personality-driven response + journal entry (NORTH STAR) — Implementation Plan

## Overview

S-03 is the product's **north star**: the smallest end-to-end slice that proves the core hypothesis — AI-driven personality plus a structured journal makes a virtual pet feel uniquely alive. A logged-in user Feeds their creature and receives a personality- and food-shaped, in-character AI response; the journal gains a coherent narrative prose entry produced in the same LLM call; stats update deterministically (hunger ↓, energy ↓) gated by a **random accept/refuse roll**. The hard prerequisite **F-02 (LLM client + prompt surface) is folded into this slice** — we build the server-side Mistral client behind an `LlmService` interface so the deterministic layer is testable against a stub.

## Current State Analysis

S-02 left a solid, directly-reusable foundation (verified against the code, not just research):

- **Data model is ready.** `Creature` (0–100 stats, `hunger=0` means full — `creature.spy.yaml:13`), `CreaturePersonality` (eight `[0.5,1.5)` decay/regen mods rolled at hatch), `JournalEntry` (`event`, `prose` default `''`, `statDelta: StatDelta?`), `StatDelta` (four `int` deltas), `JournalEvent.feed` **already exists**, `CreatureMood`. No vector column (ORQ-1: last-10 window).
- **Service layer is pure and DB-free.** `deriveMood()` (`creature_service.dart:38-45`, reuse as-is), `baselineCreatureStats`, and the **seeded-RNG seam** `randomPersonalityModifiers(Random rng)` (`:50`) — the exact pattern S-03's stochastic gate reuses. **Absent (S-03 must add):** stat clamp helper, feed math, the picky/tastiness gate, a journal-write helper.
- **Endpoint pattern to mirror.** `hatch()` (`creature_endpoint.dart:22-110`) resolves the owner from `session.authenticated!.userIdentifier`, scopes every query by `ownerUuid`, and writes Creature + Personality + a `hatched` `JournalEntry` in **one `session.db.transaction`** (`:44-87`). `myCreature()` (`:113-125`) is the load-by-owner pattern Feed reuses. `requireLogin => true`.
- **External-REST precedent exists.** EmailLabs (`server.dart:164-224`): `http.post` + `session.passwords[...]` + a run-mode branch + `jsonDecode` of the response. `http: ^1.6.0` is already a dependency. scloud allows outbound HTTPS/443 (only SMTP is blocked).
- **Full-stack wiring pattern exists.** `creature_provider.dart` (`@Riverpod(keepAlive: true) Future<CreatureStatus?>`), `hatch_controller.dart:13-26` (the `feedController` template), `ref.invalidate(creatureProvider)` refresh idiom, `home_screen.dart:40-47` (`.when` empty→present flip), `creature_view.dart` (currently a `StatelessWidget` — must become a `ConsumerWidget` to host the Feed button), `hatch_form.dart` (in-flight spinner + typed-error mapper). Lesson #2: test async Riverpod surfaces with provider overrides + a `_FakeController` flipping a `StateProvider` seam (legacy import in Riverpod 3.x), never a real RPC.

**Absent (S-03 builds it):** any LLM/HTTP code, the Feed endpoint, the Feed domain logic, the `FeedResult` return type, and the Flutter Feed UI.

## Desired End State

A signed-in user on `/` sees a Feed button on their creature. Pressing it shows a continuous loading animation, then within ~5s renders an in-character response that references the creature's personality and the (randomly-rolled, funnily-named) food. Stats update (hunger −30, energy −10, clamped); the journal gains one coherent `feed` entry with prose + the actual `StatDelta`. Sometimes the creature **refuses** — a random roll weighted by its pickiness (derived from `hungerDecayMod`), current hunger, and the food's tastiness — and the response/journal say so in character. An already-full creature gets a cheap canned "stuffed" line. A flaky/unreachable model degrades gracefully (stats still change, a canned in-character line + generic journal entry are produced) rather than hard-failing.

**Verification:** `serverpod generate` produces `client.creature.feed()` returning `FeedResult`; hermetic unit tests pin the gate math under a seeded `Random`; `withServerpod` integration tests (stubbed LLM, seeded rng) prove the stat+journal pair and the refusal/degrade branches; Flutter widget tests (provider overrides) prove the button, loading state, response render, and stats refresh.

### Key Discoveries

- `creature.spy.yaml:13` — **hunger=0 means full** (load-bearing for the full-refusal gate and the hunger-drop direction).
- `creature_service.dart:50` — `randomPersonalityModifiers(Random rng)` is the established seeded-RNG seam to copy for the gate.
- `creature_endpoint.dart:44-87` — the one-transaction write Feed mirrors (Creature update + `JournalEntry` insert in a single `session.db.transaction`).
- `server.dart:164-224` — EmailLabs `http.post` + `session.passwords` + `jsonDecode` is the exact shape `MistralLlmService` copies (server-side raw REST is correct here; the RPC-only rule is for *frontend↔backend*).
- `prd.md:39` — the guardrail is **already amended** to permit randomness *only* in the accept/refuse gate; accepted-feed magnitudes stay deterministic.
- Lesson #1 — apply migrations via `serverpod run start`, **not** `--apply-migrations`. (No DB migration is needed this slice — see "What We're NOT Doing" — but the implementer must not reach for the wrong command if one is generated.)
- Lesson #2 — provider-override widget-test pattern; `StateProvider` lives in `package:flutter_riverpod/legacy.dart` (Riverpod 3.x).

## What We're NOT Doing

- **No database migration / no schema change.** Pickiness is *derived* from the existing `hungerDecayMod` — no new `CreaturePersonality` field. `FeedResult` is a non-persisted model (like `StatDelta`/`CreatureStatus`). Nothing alters a table. Only `serverpod generate` runs.
- **No FR-007 energy gate** (the `energy==0` block + pre-written exhausted responses). That is slice **S-06**. S-03 assumes `energy > 0`; energy clamps at floor 0 so feeding a 0-energy creature is harmless.
- **No Pet / Cure** (S-04 / S-05). Feed only, so the prompt + response shape can iterate without coupling.
- **No token streaming.** Single-block structured response + a loading animation (NFR-1 satisfied for a two-field payload).
- **No `test-plan.md` cookbook update.** That artifact is created *after* this slice.
- **No tastiness-driven stat magnitude.** Tastiness influences only the accept gate + the AI prose, never the −30/−10 magnitudes (keeps the PRD guardrail intact).
- **No semantic/vector journal search.** Last-10 prose entries only (ORQ-1).

## Implementation Approach

Build bottom-up so each layer is testable before the next depends on it: (1) the LLM surface behind an interface with a key-presence-based real/stub split; (2) the pure Feed domain logic (clamp, picky, tastiness, gate) driven by an injectable `Random`; (3) the endpoint that composes them in one transaction, with `FeedResult` and graceful degradation, then `serverpod generate`; (4) the Flutter Feed UI. Tests live with the layer that owns the behavior: hermetic unit tests in Phase 2, `withServerpod` integration tests in Phase 3, widget tests in Phase 4.

The two randomness sources both flow through seams so the whole slice is reproducible: a `feedRandomFactory` (`Random` seam, tests inject a seed) and an `llmServiceFactory` (tests inject a stub or a deliberately-failing stub). In environments with no key the factory returns `StubLlmService` automatically, so CI/`dart test`/`flutter test` never need a Mistral key while **dev with a local key calls the real model** for manual testing.

## Critical Implementation Details

- **LLM selection is key-presence-based, not run-mode-based.** `llmServiceFor(session)` returns `MistralLlmService` when `session.passwords['mistralApiKey']` is non-null/non-empty, else `StubLlmService`. This makes dev (local key) and prod (scloud-injected) hit the real API while the test run-mode (no `passwords.yaml` entry) stays hermetic. Do **not** gate on `runMode == 'development'` here — that was the EmailLabs pattern; this slice deliberately diverges so dev can manually test the model.
- **RNG draw order is part of the contract.** A single `Random` from `feedRandomFactory()` is consumed in a fixed order so seeded tests are stable: `evaluateFeed` draws **tastiness first, then the reject roll**; the canned full-refusal line is picked (only on the full-refusal path) after. Document this order at the call site; changing it breaks seeded tests.
- **The LLM is called for picky-refusals too** (so the AI writes a refusal line referencing the funny food), but **not** for already-full refusals (cheap canned line, no entry, no call). The `accepted` flag + `tastiness` are inputs to the prompt so the model writes accept- vs refuse-appropriate prose.
- **Coherent-pair atomicity:** the stat update + journal insert run in one `session.db.transaction` (mirroring hatch). The LLM call happens *before* the transaction; on LLM failure the canned fallback is substituted and the transaction still runs (degrade), so a stat change never lands without a matching journal entry.

## Phase 1: LLM surface + secret wiring (F-02 fold-in)

### Overview

Create the `lib/src/llm/` feature dir: an `LlmService` interface, a real Mistral REST client, a deterministic stub, the key-presence selection seam, the pure prompt builder, and the canned-copy module. Provision the `mistralApiKey` secret.

> **Read first:** `.claude/skills/serverpod-configuration/SKILL.md` (passwords, run modes, secrets), `.claude/skills/serverpod-models/SKILL.md` (if any serializable model is added here). Mirror the EmailLabs REST call at `server.dart:164-224` and use `package:http` directly (server-side raw REST is the right tool; the RPC-only rule is for frontend↔backend).

### Changes Required

#### 1. LLM service interface + result type

**File**: `tamagotchi_server/lib/src/llm/llm_service.dart`

**Intent**: Define the seam the endpoint depends on, so the deterministic layer is testable against a stub without a live model.

**Contract**: `abstract interface class LlmService { Future<({String userResponse, String journalNarrative})> generateInteraction(Session session, InteractionRequest request); }`. `InteractionRequest` is a plain Dart class/record carrying `personality`, current `stats`, `mood`, `interactionType` (Feed), `accepted` (bool), `tastiness` (double `[0,1)`), and `recentEntries` (last-10 prose). Two output fields only — the funny food name surfaces *within* the prose (the prompt instructs the model to invent and reference it from `tastiness`).

#### 2. Mistral REST client

**File**: `tamagotchi_server/lib/src/llm/mistral_client.dart`

**Intent**: Implement `LlmService` against Mistral's OpenAI-compatible chat-completions API with structured output.

**Contract**: `POST https://api.mistral.ai/v1/chat/completions`; headers `Authorization: Bearer ${session.passwords['mistralApiKey']}`, `Content-Type: application/json`; body `model: "mistral-small-2603"`, `messages` (system persona + user state from the prompt builder), `max_tokens` (~768), `response_format: {type: "json_schema", json_schema: {name, strict: true, schema}}` where the schema requires `{userResponse: string, journalNarrative: string}`. Parse `choices[0].message.content` → `jsonDecode` → the two fields. Confirm the exact `json_schema` envelope against Mistral's custom-structured-output docs page at implement time; fall back to `{type:"json_object"}` + explicit schema instructions in the prompt if `json_schema` is rejected.

#### 3. Deterministic stub

**File**: `tamagotchi_server/lib/src/llm/stub_llm_service.dart`

**Intent**: A no-network `LlmService` for key-less environments (test run-mode, CI) and as the default in widget/integration tests.

**Contract**: Returns canned, deterministic `userResponse`/`journalNarrative` drawn from `feed_copy.dart`, varying by `request.accepted` so accept vs refuse paths are distinguishable in assertions. Never throws.

#### 4. Selection seam

**File**: `tamagotchi_server/lib/src/llm/llm_service.dart` (same file as the interface, or a small `llm_factory.dart`)

**Intent**: Pick real vs stub by key presence, with a test-overridable seam.

**Contract**: `LlmService llmServiceFor(Session session)` → `MistralLlmService` if `session.passwords['mistralApiKey']?.isNotEmpty ?? false`, else `StubLlmService`. Expose `@visibleForTesting LlmService Function(Session) llmServiceFactory = llmServiceFor;` so integration tests can inject a stub or a failing stub.

#### 5. Prompt builder (pure)

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: Turn an `InteractionRequest` into the `messages` array — pure and unit-testable.

**Contract**: `List<Map<String,dynamic>> buildInteractionMessages(InteractionRequest req)`. System message fixes the in-character persona + the "stay in character, no chatbot/disclaimer language" guardrail (PRD success criteria) + the instruction to invent and name a food whose fanciness matches `tastiness`. User message carries the volatile state (stats, mood, personality summary, `accepted`, `tastiness`, the last-10 prose entries).

#### 6. Canned copy module

**File**: `tamagotchi_server/lib/src/llm/feed_copy.dart`

**Intent**: Provide the non-LLM copy pools.

**Contract**: `const List<String> fullRefusalLines` (**10–20 funny "I'm stuffed" lines**, picked by the shared `Random`), plus canned `degradeUserResponse`/`degradeJournalNarrative` (LLM-failure fallback) and the stub's accept/refuse strings.

#### 7. Secret provisioning

**File**: `tamagotchi_server/config/passwords.yaml` (local, gitignored)

**Intent**: Make a dev key available for manual testing; document prod + test.

**Contract**: Add a `mistralApiKey:` entry under the dev section for local manual testing. Prod: provisioned out-of-band via `scloud secret set mistralApiKey` (never committed). Test run-mode: **no** entry → `StubLlmService`. Add a short comment noting the dev key is a deliberate, approved exception to the no-secrets-in-devcontainer rule (which governs DB creds).

### Success Criteria

#### Automated Verification

- Server analyzes cleanly: `dart analyze` in `tamagotchi_server/`
- Prompt-builder unit test passes: messages include persona, stats, mood, `accepted`, `tastiness`, and recent entries
- `feed_copy.dart` test passes: `fullRefusalLines.length` is 10–20 and all non-empty; degrade/stub strings non-empty
- Selection unit test passes: `llmServiceFor` returns stub when key absent, Mistral client when key present

#### Manual Verification

- With a local `mistralApiKey`, a throwaway `main`/test harness calling `MistralLlmService.generateInteraction` returns two non-empty fields from the real API and references a plausibly-named food
- Without a key, the same harness returns the stub copy and makes no network call

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Feed domain logic + hermetic unit tests

### Overview

Add the pure, DB-free Feed mechanics — stat clamp, the derived picky factor, the tastiness roll, the composed reject probability, and `evaluateFeed` — all driven by an injectable `Random`. This is the highest-signal test surface and depends on nothing external.

> **Read first:** the existing `creature_service.dart` (extend its style — pure functions, `Random rng` seam, records over classes). No external skill needed; this is plain Dart + `package:test`.

### Changes Required

#### 1. Feed mechanics

**File**: `tamagotchi_server/lib/src/creature/feed_service.dart` (new; or extend `creature_service.dart`)

**Intent**: Encode every deterministic + stochastic rule as small pure functions so the oracle is asserted in isolation.

**Contract**:
- `int clampStat(int v) => v.clamp(0, 100);`
- `const feedHungerDrop = 30; const feedEnergyCost = 10;`
- `double pickyFactor(double hungerDecayMod) => 1.5 - hungerDecayMod;` (range `(0,1]`; **low decay ⇒ pickier**)
- `double rejectProbability({required double picky, required int hunger, required double tastiness}) => picky * (1 - hunger / 100) * (1 - tastiness);` (monotonic; gourmet food or a starving creature drive it toward 0)
- `({bool full, bool accepted, double tastiness, StatDelta delta}) evaluateFeed({required Creature creature, required CreaturePersonality personality, required Random rng})`:
  - `creature.hunger == 0` → `full: true` (no draws consumed yet; caller handles the full path).
  - else draw `tastiness = rng.nextDouble()` **then** the reject roll `rng.nextDouble() < rejectProbability(...)`.
  - accepted → `delta = StatDelta(hungerDelta: clampStat(hunger - feedHungerDrop) - hunger, energyDelta: clampStat(energy - feedEnergyCost) - energy, loveDelta: 0, illnessDelta: 0)`.
  - picky-refusal → `delta = StatDelta(0,0,0,0)`.
- A `feedRandomFactory` seam: `@visibleForTesting Random Function() feedRandomFactory = () => Random();`.

#### 2. Hermetic unit tests

**File**: `tamagotchi_server/test/unit/feed_service_test.dart` (new)

**Intent**: Assert the oracle against PRD/domain values, never against the implementation's own output.

**Contract**: Parameterized tests covering: hunger drop = 30 (clamped, so a near-full creature floors at 0 without going negative); energy cost = 10 (clamped); `loveDelta == 0 && illnessDelta == 0`; `pickyFactor` direction (mod 0.5 → 1.0, mod→1.5 → →0); `rejectProbability` reaches 0 at `hunger==100` and at `tastiness→1`; with a seed that forces a low draw → accepted, a seed that forces a high draw → picky-refusal with zero delta; `full` flag at `hunger==0`. Use seeded `Random` directly (the primary signal).

### Success Criteria

#### Automated Verification

- Unit tests pass: `dart test test/unit/feed_service_test.dart` in `tamagotchi_server/`
- `dart analyze` clean
- (Optional selective gate) `npx stryker run --mutate "lib/src/creature/feed_service.dart"` shows no high-value survived mutants on the gate math

#### Manual Verification

- Eyeball a handful of `(hungerDecayMod, hunger, tastiness)` triples and confirm `rejectProbability` values match intuition (pickier + fuller + blander ⇒ higher)

**Implementation Note**: Pause for manual confirmation before Phase 3.

---

## Phase 3: Feed endpoint + FeedResult + journal pair + integration tests

### Overview

Add the `FeedResult` model and the `feed` endpoint that composes Phases 1–2 into one transaction with graceful degradation, regenerate the client, and prove the behavior with `withServerpod` integration tests (real DB, stubbed LLM, seeded rng).

> **Read first:** `.claude/skills/serverpod-endpoints/SKILL.md`, `.claude/skills/serverpod-models/SKILL.md`, `.claude/skills/serverpod-database/SKILL.md` (queries/`orderBy`/`limit`), `.claude/skills/serverpod-cli/SKILL.md` (`serverpod generate`), `.claude/skills/serverpod-testing/SKILL.md` (`withServerpod`, `sessionBuilder.copyWith` auth, rollback). Bring up Postgres: `docker compose up -d` in `tamagotchi_server/`.

### Changes Required

#### 1. FeedResult model

**File**: `tamagotchi_server/lib/src/creature/feed_result.spy.yaml` (new, non-table)

**Intent**: Carry the discriminated outcome to the client.

**Contract**: `class: FeedResult` with `userResponse: String`, `accepted: bool`, `status: CreatureStatus` (updated creature + re-derived mood, so the client can render without a second fetch). No `table:`.

#### 2. Typed feed error (minimal)

**File**: `tamagotchi_server/lib/src/creature/creature_feed_error.spy.yaml` + reason enum (new)

**Intent**: Surface the only genuine error path — feeding with no creature — typed, mirroring `CreatureHatchError`. Refusals are **not** errors (they ride `FeedResult.accepted=false`).

**Contract**: `CreatureFeedError { reason: CreatureFeedErrorReason }` with a single reason `noCreature`. (Behind the UI this should never fire; it exists for convention parity and a clean client switch.)

#### 3. Feed endpoint

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Compose the gate, the LLM call, and the journal-pair write behind `requireLogin`, owner-scoped.

**Contract**: `Future<FeedResult> feed(Session session)`:
1. Resolve `ownerUuid` from `session.authenticated!.userIdentifier`; load the owner's `Creature` (throw `CreatureFeedError(noCreature)` if none); load its `CreaturePersonality`.
2. `final rng = feedRandomFactory();` then `final decision = evaluateFeed(creature, personality, rng);`.
3. **Full** (`decision.full`): pick a `fullRefusalLines` entry via `rng`; return `FeedResult(accepted:false, userResponse: line, status: current)`. No LLM, no journal entry, no stat change.
4. Otherwise: fetch last-10 journal entries with non-empty prose (`JournalEntry.db.find(session, where: (t)=>t.creatureId.equals(creature.id!), orderBy:(t)=>t.timestamp, orderDescending:true, limit:10)` then filter `prose.isNotEmpty`); build the `InteractionRequest` (`accepted: decision.accepted`, `tastiness: decision.tastiness`); call `llmServiceFactory(session).generateInteraction(...)` inside try/catch — **on failure** log and substitute `feed_copy` degrade strings (stats still apply).
5. In one `session.db.transaction`: if `decision.accepted`, update the creature's stats by `decision.delta`; insert `JournalEntry(event: JournalEvent.feed, prose: journalNarrative, statDelta: decision.delta)` (zero delta on picky-refusal — the entry still records the refusal).
6. Return `FeedResult(accepted: decision.accepted, userResponse, status: CreatureStatus(creature: updated, mood: deriveMood(...)))`.

#### 4. Regenerate client

**File**: generated trees (`lib/src/generated/`, `../tamagotchi_client/lib/src/protocol/`)

**Intent**: Expose `client.creature.feed()` + `FeedResult`/`CreatureFeedError` to Flutter.

**Contract**: Run `serverpod generate` in `tamagotchi_server/`. Do not hand-edit generated files.

#### 5. Integration tests

**File**: `tamagotchi_server/test/integration/feed_endpoint_test.dart` (new)

**Intent**: Prove the composed behavior end-to-end against a real DB with the LLM stubbed and rng seeded.

**Contract**: Override `llmServiceFactory` → a `StubLlmService` (and, in one case, a throwing stub for the degrade path) and `feedRandomFactory` → seeded. Authenticated `sessionBuilder.copyWith(...)`. Cases:
- Accepted feed: hunger −30 / energy −10 (clamped), `love`/`illness` unchanged, exactly **one** `feed` journal entry with the matching `StatDelta` and non-empty prose, `FeedResult.accepted == true`, mood re-derived.
- Full creature (`hunger==0`): `accepted == false`, canned line returned, stats unchanged, **no** journal entry written.
- Picky-refusal (seed forces a high roll): `accepted == false`, a `feed` journal entry **with zero StatDelta** + refusal prose, stats unchanged.
- Degrade (stub throws): stats still change, a `feed` entry is written with the degrade prose, `feed()` does not throw.
- No creature: `feed()` throws `CreatureFeedError(noCreature)`.
- Owner-scoping: a second user's `feed()` never touches the first user's creature.

### Success Criteria

#### Automated Verification

- `serverpod generate` succeeds; `client.creature.feed()` and `FeedResult` exist in the generated client
- Integration tests pass: `docker compose up -d` then `dart test test/integration/feed_endpoint_test.dart` in `tamagotchi_server/` (with `SERVERPOD_PASSWORD_database` for the test container)
- `dart analyze` clean (excluding generated trees)

#### Manual Verification

- With a dev `mistralApiKey`, call `feed` via the running server and confirm a real, in-character, food-referencing response + a coherent journal entry
- Repeated feeds eventually surface a refusal whose copy reads in-character (not a generic error)

**Implementation Note**: Pause for manual confirmation before Phase 4.

---

## Phase 4: Flutter wiring + widget tests

### Overview

Add the `feedController`, the Feed button + response/loading UI on a now-`ConsumerWidget` `CreatureView`, and provider-override widget tests. Stats refresh via the existing `ref.invalidate(creatureProvider)` idiom.

> **Read first:** `.claude/skills/riverpod-providers/SKILL.md`, `.claude/skills/riverpod-codegen-and-hooks/SKILL.md` (`@riverpod` + `part`), `.claude/skills/riverpod-consumers/SKILL.md`, `.claude/skills/riverpod-refs/SKILL.md` (`invalidate`), `.claude/skills/riverpod-testing/SKILL.md` + `.claude/skills/riverpod-overrides/SKILL.md` (overrides), `.claude/skills/riverpod-3-0-migration/SKILL.md` (`StateProvider` now in `package:flutter_riverpod/legacy.dart`), `.claude/skills/flutter-add-widget-test/SKILL.md`, `.claude/skills/flutter-fix-layout-issues/SKILL.md`. Follow lesson #2 (provider overrides, not a real RPC).

### Changes Required

#### 1. Feed controller

**File**: `tamagotchi_flutter/lib/creature/feed_controller.dart` (new)

**Intent**: Drive the Feed button idle → loading → result, surfacing the AI text (unlike hatch, which discards its return).

**Contract**: `@riverpod class FeedController extends _$FeedController { FutureOr<FeedResult?> build() => null; Future<void> feed() async { state = const AsyncLoading(); state = await AsyncValue.guard(() async { final r = await ref.read(serverpodClientProvider).creature.feed(); ref.invalidate(creatureProvider); return r; }); } }`. Run `dart run build_runner build` for the `.g.dart`.

#### 2. Feed button + response UI

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`

**Intent**: Host the interaction; render the response and refusal distinctly; show continuous progress during the wait.

**Contract**: Convert `CreatureView` from `StatelessWidget` to `ConsumerWidget`. Watch `feedControllerProvider`: `isLoading` → an animated indicator (spinner / animated dots) in place of the button (mirror `hatch_form.dart`'s in-flight swap); on `AsyncData(FeedResult)` render `userResponse` (styled differently when `!accepted`); on `AsyncError` (RPC/network only — refusals are data) show a generic retry hint. Keep the four `_StatRow`s; they re-render once `creatureProvider` is invalidated.

#### 3. Widget tests

**File**: `tamagotchi_flutter/test/creature/creature_view_test.dart` (extend) + a `_FakeFeedController`

**Intent**: Prove the UI without a server.

**Contract**: Override `creatureProvider` with canned `AsyncValue`s and `feedControllerProvider.overrideWith(_FakeFeedController.new)` (the fake flips a `StateProvider` seam instead of calling the server). Assert: the Feed button renders for a present creature; tapping calls the controller; the loading animation shows after a single `pump()` (loading via a never-completing future); the accepted response text renders; a refusal (`accepted:false`) renders its distinct copy; updated stats render after the (fake) refresh.

### Success Criteria

#### Automated Verification

- `dart run build_runner build` succeeds (controller `.g.dart` generated)
- Widget tests pass: `flutter test test/creature/creature_view_test.dart` in `tamagotchi_flutter/`
- `flutter analyze` clean
- `serverpod run flutter_build` (in `tamagotchi_server/`) builds the web app without error

#### Manual Verification

- In the running web app, Feed shows a continuous loading animation then the in-character response within ~5s; stats update; the journal reflects the entry
- A refusal renders distinctly (not as an error); an already-full creature shows the canned "stuffed" line
- No `RenderFlex`/overflow issues when a long AI response renders

**Implementation Note**: Final phase — pause for manual confirmation; the north-star demo is the acceptance bar.

---

## Testing Strategy

### Unit Tests (hermetic, Phase 2)
- Feed math: hunger −30 / energy −10 with clamping; `love`/`illness` deltas zero.
- `pickyFactor` direction and `rejectProbability` composition (boundaries at `hunger==100`, `tastiness→1`).
- Seeded accept vs picky-refusal outcomes; `full` at `hunger==0`.
- Prompt builder content; canned-copy invariants.

### Integration Tests (`withServerpod`, real DB, stubbed LLM + seeded rng, Phase 3)
- Accepted feed stat+journal pair; full-refusal (no entry); picky-refusal (zero-delta entry); degrade path; no-creature error; owner-scoping.

### Widget Tests (provider overrides, Phase 4)
- Button render, tap-calls-controller, loading animation, accepted/refused render, stats refresh.

### Manual Testing Steps
1. With a dev key, hatch then Feed; confirm in-character, food-named response + coherent journal entry within ~5s.
2. Feed repeatedly; confirm an occasional in-character refusal and (when full) a canned "stuffed" line.
3. Temporarily point the key at an invalid value; confirm the degrade path (stats change, canned line, no crash).

## Performance Considerations

One external call per accepted/picky feed on the hot path; `mistral-small-2603` is low-latency and cheap ($0.15/$0.60 per 1M tokens), well within NFR-1's 5s with a loading animation. Last-10 prose entries bound prompt size. Full-refusals make no LLM call.

## Migration Notes

None — no schema change (pickiness derived; `FeedResult` non-table). `serverpod generate` only. If the generator emits a migration spuriously, do not apply it; if a real one is ever needed, apply via `serverpod run start` (lesson #1), never `--apply-migrations`.

## References

- Research: `context/changes/feed-with-personality-response/research.md`
- Change brief: `context/changes/feed-with-personality-response/change.md`
- PRD guardrail (amended): `context/foundation/prd.md:39`; US-01/FR-004/FR-009/FR-011
- Hatch transaction to mirror: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:44-87`
- EmailLabs REST precedent: `tamagotchi_server/lib/server.dart:164-224`
- RNG seam to copy: `tamagotchi_server/lib/src/creature/creature_service.dart:50`
- Controller template: `tamagotchi_flutter/lib/creature/hatch_controller.dart:13-26`
- Widget-test pattern: `tamagotchi_flutter/test/creature/creature_view_test.dart`; lesson #2 (`context/foundation/lessons.md`)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: LLM surface + secret wiring

#### Automated
- [x] 1.1 Server analyzes cleanly (`dart analyze`) — d4f858f
- [x] 1.2 Prompt-builder unit test passes (persona/stats/mood/accepted/tastiness/recent entries) — d4f858f
- [x] 1.3 `feed_copy.dart` test passes (10–20 non-empty refusal lines; degrade/stub strings non-empty) — d4f858f
- [x] 1.4 Selection unit test passes (stub when key absent, Mistral when present) — d4f858f

#### Manual
- [x] 1.5 Real Mistral round-trip returns two non-empty fields + named food (with local key) — d4f858f
- [x] 1.6 Key-less harness returns stub copy, no network call — d4f858f

### Phase 2: Feed domain logic + hermetic unit tests

#### Automated
- [x] 2.1 Unit tests pass (`dart test test/unit/feed_service_test.dart`) — cf66e92
- [x] 2.2 `dart analyze` clean — cf66e92
- [x] 2.3 (Optional) Stryker shows no high-value survived mutants on the gate math — n/a (Stryker is a JS/TS mutation runner; no Dart mutation tool in this stack)

#### Manual
- [x] 2.4 `rejectProbability` triples match intuition — cf66e92

### Phase 3: Feed endpoint + FeedResult + journal pair + integration tests

#### Automated
- [x] 3.1 `serverpod generate` succeeds; `client.creature.feed()` + `FeedResult` exist — 8c9e0c3
- [x] 3.2 Integration tests pass (`dart test test/integration/feed_endpoint_test.dart`) — 8c9e0c3
- [x] 3.3 `dart analyze` clean (excl. generated) — 8c9e0c3

#### Manual
- [x] 3.4 Real `feed` call returns in-character, food-referencing response + coherent journal entry — 8c9e0c3
- [x] 3.5 Repeated feeds surface an in-character refusal — 8c9e0c3

### Phase 4: Flutter wiring + widget tests

#### Automated
- [x] 4.1 `build_runner build` succeeds (controller `.g.dart`) — 5296cad
- [x] 4.2 Widget tests pass (`flutter test test/creature/creature_view_test.dart`) — 5296cad
- [x] 4.3 `flutter analyze` clean — 5296cad
- [x] 4.4 `serverpod run flutter_build` builds the web app — 5296cad

#### Manual
- [x] 4.5 Feed shows loading animation then response within ~5s; stats + journal update — 5296cad
- [x] 4.6 Refusal renders distinctly; full creature shows canned line — 5296cad
- [x] 4.7 No overflow when a long response renders — 5296cad
