---
date: 2026-06-05T18:34:35+00:00
researcher: Karol Sotomski
git_commit: 0c8b910073b1f2d8bdbc41d15963737c2618f391
branch: feed-with-personality-response
repository: nabrudno
topic: "S-03 Feed the creature once and get a personality-driven response + journal entry (NORTH STAR)"
tags: [research, codebase, creature, feed, llm, journal, serverpod, riverpod, north-star]
status: complete
last_updated: 2026-06-05
last_updated_by: Karol Sotomski
last_updated_note: "Provider decided = Mistral AI (mistral-small-2603); pickiness decided = RANDOM (trait + hunger driven). Updated §B, oracle #7, determinism boundary, open questions; added Mistral API quick-reference follow-up."
---

# Research: S-03 Feed — personality-driven response + journal entry (NORTH STAR)

**Date**: 2026-06-05T18:34:35+00:00
**Researcher**: Karol Sotomski
**Git Commit**: 0c8b910073b1f2d8bdbc41d15963737c2618f391 (S-02 merge; this branch has no new commits yet)
**Branch**: feed-with-personality-response
**Repository**: nabrudno

## Research Question

What does it take to build S-03 (`feed-with-personality-response`) — the north-star slice where a logged-in user Feeds the creature, receives an in-character AI response, the journal gains a narrative prose entry produced in the same call, and stats update per FR-004? The hard prerequisite **F-02 (`llm-client-prompt-surface`) has no code and no change folder yet**, so the research deliberately covers (a) F-02's LLM-client + prompt-surface design, (b) the deterministic Feed mechanics oracle (FR-004/008), (c) the AI-response + journal pair (FR-009/011), (d) full-stack wiring on top of what S-02 left behind, and (e) the existing-code reuse surface.

## Summary

- **S-02 left a solid foundation.** The `creature`/`creature_personality`/`journal_entry` tables, the `StatDelta` and `JournalEntry` models, the `JournalEvent.feed` enum value, the `deriveMood()` oracle, the owner-scoping/auth pattern, and the Flutter `creatureProvider` + `hatchController` + provider-override test pattern all exist and are directly reusable. S-03 mostly **adds a `feed` endpoint + a `feedController` + a Feed button**, mirroring hatch.
- **F-02 does not exist.** No LLM/HTTP code is present. But the project already has the exact precedent for "call an external REST API with a runtime secret": the EmailLabs integration in `server.dart` (HTTP Basic + `session.passwords[...]` + run-mode gate). `http: ^1.6.0` is already a dependency. **DECIDED: the provider is Mistral AI, model `mistral-small-2603` (Mistral Small 4).** Recommended shape: a new `tamagotchi_server/lib/src/llm/` feature dir calling the OpenAI-compatible Mistral chat-completions REST API directly (no Dart SDK), structured output via `response_format: {type: json_schema}`, key via `session.passwords['mistralApiKey']` with `Authorization: Bearer`, dev run-mode returns a stub so the devcontainer needs no key.
- **The slice has a clean test seam — two stubbed dependencies.** The deterministic stat layer (clamping, full-rejection, mood, `StatDelta`, journal-entry presence) is testable with a **stubbed LLM**; the now-stochastic picky accept/reject gate is testable with an **injected/seeded `Random`** (the project's existing `randomPersonalityModifiers(Random rng)` seam). Only the AI prose/response *wording* is genuinely non-reproducible.
- **DECIDED: pickiness is RANDOM.** Per the user: "not accepting food HAS TO BE RANDOM based on an appropriate creature's trait and hunger." So the accept/reject gate is a probabilistic roll whose probability is a function of a **picky trait + current hunger** — NOT a pure deterministic predicate. This intentionally **reinterprets the PRD guardrail** "Stats are deterministic given inputs / AI adds flavor, not randomness to core mechanics" — and that guardrail was **amended 2026-06-05** to record the exception: the *accept/reject gate* is now an explicit stochastic exception; the stat *magnitudes on an accepted feed* stay deterministic. A `picky` trait field must be added to `CreaturePersonality` (no such field exists yet), randomized at hatch via the existing `Random` seam.
- **Several numeric values are genuinely undecided** (hunger-reduction amount, energy cost, full threshold, picky predicate, N for the journal window). These are flagged for `/10x-plan`, not guessed here.

---

## Detailed Findings

### A. Existing server-side reuse surface (what S-02 left behind)

**Models (`tamagotchi_server/lib/src/creature/*.spy.yaml`):**

- `creature.spy.yaml` — `Creature` table. Stats `hunger / energy / love / illness` are `int` on a **0–100 scale** (`creature.spy.yaml:13-19`). **Semantics asymmetry (load-bearing for Feed math):** higher `hunger`/`illness` = worse; higher `energy`/`love` = better. So **hunger = 0 means "full."** Unique `creature_owner_idx` on `ownerUuid` enforces one creature per user (`creature.spy.yaml:22-26`).
- `creature_personality.spy.yaml` — eight `double` decay/regen modifiers, randomized at hatch, range `[0.5, 1.5)`, **inert until S-07**. Comment explicitly states interaction modifiers (picky/gluttonous, introvert/extravert) are "out of scope and added additively in S-03/S-04" (`creature_personality.spy.yaml:4-5`). **There is no picky/gluttonous field yet.**
- `journal_entry.spy.yaml` — `JournalEntry` table: `id`, `creatureId`, `ownerUuid`, `timestamp (default=now)`, `event (JournalEvent)`, `prose (String, default='')`, `statDelta (StatDelta?)`. Header note: "No vector column (ORQ-1: last-10 narrative entries)" — **N≈10 is the pre-decided window.** Non-unique `journal_entry_creature_idx` on `creatureId` supports last-N lookup.
- `journal_event.spy.yaml` — enum `hatched, feed, pet, cure`. **`feed` already exists** (`journal_event.spy.yaml:6-7`).
- `stat_delta.spy.yaml` — `StatDelta` (non-table): `hungerDelta / energyDelta / loveDelta / illnessDelta`, all `int`. Ready for S-03 to populate.
- `creature_mood.spy.yaml` — enum `happy, content, sad, sick` (derived on read, never stored).
- `creature_errors.spy.yaml` / `creature_hatch_error_reason.spy.yaml` — typed `CreatureHatchError{reason}` with reasons `alreadyHatched, emptyName`. **Hatch-specific** — S-03 needs its own typed feed error if it surfaces rejections as exceptions.

**Service (`creature_service.dart`) — pure, DB-free:**

- `deriveMood(hunger, energy, love, illness)` (`creature_service.dart:38-45`) — **reuse as-is.** Rule: `illness >= 50` → `sick`; else `worst = max(hunger, 100-energy, 100-love)`; `worst < 25` → `happy`; `< 55` → `content`; else `sad`. Note `illness` only gates `sick`, it is **not** in the `worst` list.
- `baselineCreatureStats = (hunger:0, energy:100, love:50, illness:0)` (`creature_service.dart:14`).
- `randomPersonalityModifiers(Random rng)` (`creature_service.dart:50-62`) — eight rolls of `0.5 + rng.nextDouble()` → `[0.5, 1.5)`; `rng` is an injectable seam for deterministic tests.
- `isUniqueViolation(error)` (`creature_service.dart:72-73`) — SQLSTATE `23505` check.
- **Absences S-03 must add (do NOT exist):** no stat clamp/floor helper (0/100 live only in YAML comments), no decay/regen application, **no journal-write helper** (the hatched insert is inlined in the hatch transaction), no feed/pet/cure math.

**Endpoint (`creature_endpoint.dart`):**

- `requireLogin => true` (`creature_endpoint.dart:13-14`). Owner resolved as `UuidValue.fromString(session.authenticated!.userIdentifier)` and every query scoped by `ownerUuid.equals(...)` (`:23-25`, `:114-116`). **S-03's `feed` reuses this exactly.**
- `hatch()` (`:22-110`) writes Creature + CreaturePersonality + JournalEntry in **one `session.db.transaction`** (`:44-87`); the `JournalEntry` insert at `:74-84` (`event: hatched, prose: '', statDelta: null`) is **the journal-write pattern Feed mirrors** (for Feed: `event: feed`, non-empty prose, populated `StatDelta`).
- `myCreature()` (`:113-125`) — load-by-owner pattern Feed reuses to fetch the creature before mutating.
- `_moodOf(c)` (`:127-128`) wraps `deriveMood`.
- `grep "feed"` over the creature dir: only the YAML comment + enum value — **no Dart feed logic anywhere yet.**

### B. F-02 — LLM client + prompt surface design (no code exists)

**Secrets/config precedent (the EmailLabs integration):**

- Secrets reach runtime via `session.passwords['<key>']` — populated locally by gitignored `config/passwords.yaml`, in deployed/CI by `SERVERPOD_PASSWORD_*` env vars. Canonical use: `server.dart:172-177` reads `session.passwords['emaillabsApiKey']`/`['emaillabsApiSecret']`, base64s for HTTP Basic.
- **Run-mode gate precedent:** `server.dart:113` / `:137` branch on `session.serverpod.runMode == 'development'` to log instead of calling the external API. F-02 should wrap the LLM call the same way: **dev → deterministic stub; prod → real Anthropic call**, so the devcontainer needs no key.
- `grep` confirms **no code reads `Platform.environment` / `getPassword` / `fromEnvironment`** — secrets always flow through `session.passwords`. F-02 must follow this.
- Config dir has `development/production/staging/test.yaml`, `passwords.yaml`, `generator.yaml`; Redis disabled in all run modes.

**Outbound HTTPS / deps:**

- `tamagotchi_server/pubspec.yaml:18` already declares **`http: ^1.6.0`**. No openai/mistral/dio package — and there is no first-party Mistral Dart SDK, so F-02 calls the Mistral chat-completions REST API directly with `package:http` + `dart:convert`, mirroring `_sendVerificationEmail` (`server.dart:183-215`). scloud allows outbound HTTPS/443 to `api.mistral.ai` (only SMTP egress is blocked — see memory `project_tamagotchi_email_emaillabs`).

**Provider / model / structured output (DECIDED — Mistral AI; from the live docs, not memory):**

- **Provider:** Mistral AI. Docs: https://docs.mistral.ai/api. **Model: `mistral-small-2603`** (Mistral Small 4 — model card https://docs.mistral.ai/models/model-cards/mistral-small-4-0-26-03). 256k-token context; pricing **$0.15 / 1M input, $0.60 / 1M output** — cheap enough for the per-interaction Feed hot path. Capabilities listed: Function Calling, **Structured Outputs**, Predicted Outputs.
- **Structured output (two fields `userResponse` + `journalNarrative`):** the API is OpenAI-compatible and exposes three `response_format` modes — `{type:"text"}`, `{type:"json_object"}` (valid JSON, no schema), and **`{type:"json_schema"}`** ("guarantees the message follows the schema you provide"). Use `json_schema` for the two-field contract. The exact envelope (OpenAI-style `response_format:{type:"json_schema", json_schema:{name, schema, strict:true}}`) should be confirmed against the custom-structured-output page at `/10x-plan` time — the docs index page didn't render the verbatim wrapper. Parse `choices[0].message.content` → `jsonDecode` (OpenAI-shaped response).
- **REST shape:** `POST https://api.mistral.ai/v1/chat/completions` (base `https://api.mistral.ai`); headers `Authorization: Bearer <key>`, `Content-Type: application/json`; body `model: "mistral-small-2603"`, `messages` (a `system` persona message + a `user` message with the volatile per-call state), `max_tokens` (~512–1024 ample), optional `temperature`, and `response_format`.

**Recommended F-02 layout (feature-dir convention, "group by feature not layer"):**

- `tamagotchi_server/lib/src/llm/mistral_client.dart` — thin `http.post` wrapper to `/v1/chat/completions`; reads key from `session.passwords['mistralApiKey']`, sends `Authorization: Bearer`; run-mode-gated (dev stub / prod call).
- `tamagotchi_server/lib/src/llm/creature_prompt.dart` — pure `buildInteractionPrompt({personality, stats, mood, interactionType, lastNJournalEntries})` → request body; typed result `({String userResponse, String journalNarrative})`.
- S-03's `feed` endpoint (in the `creature/` feature dir) fetches last-N journal entries via `JournalEntry.db.find(session, where: creatureId.equals(id), orderBy: timestamp, orderDescending: true, limit: N)`, calls `llm/`, writes a `JournalEntry(event: feed, prose: journalNarrative, statDelta: ...)`, returns `userResponse`.
- **Key provisioning (memory-constrained):** add password key `mistralApiKey`; prod via `scloud secret set` (out-of-band, never committed — like EmailLabs keys at `server.dart:160-163`); **devcontainer gets no real key** (user rule `feedback_no_db_credentials_in_devcontainer`) — dev gate returns a stub.

### C. Deterministic Feed mechanics oracle (FR-004 / FR-008) — for the test plan

The oracle is derived from the PRD + data model, **not** from any implementation (none exists). Direction/structure is source-derived; specific magnitudes are flagged OPEN.

| # | Rule | Deterministic expectation | Source | Status |
|---|------|---------------------------|--------|--------|
| 1 | Feed reduces hunger | `hunger_after < hunger_before` by fixed `D_h > 0` | FR-004 (prd.md:72) | dir source-derived; **D_h OPEN** |
| 2 | Feed costs energy | `energy_after < energy_before` by fixed `C_e > 0` (energy-cost model replaced cooldowns) | FR-004 (prd.md:72-73) | dir source-derived; **C_e OPEN** |
| 3 | Full = hunger 0 | Feed rejected when creature already full (hunger at floor) | FR-004 + hunger semantics (prd.md:72, creature.spy.yaml:13) | "full=0" source-derived; **exact threshold OPEN** |
| 4 | Rejection ⇒ no stat change | On rejected Feed, all stats unchanged | FR-004 + guardrail (prd.md:39,72) | source-derived |
| 5 | Rejection surface | Typed, client-switchable result (mirror `CreatureHatchError`) | existing convention | pattern-derived; **exact type OPEN** |
| 6 | Energy gate (FR-007) | At `energy==0` all but Cure blocked, pre-written line, no AI call | FR-007 (prd.md:78) | **OUT OF SCOPE — slice S-06**; flag boundary only |
| 7 | **Picky modifier is RANDOM** (user-decided) | Accept/reject is a probabilistic roll; `P(reject)` is a function of a **picky trait + current hunger** (hungrier ⇒ less picky; pickier trait ⇒ more rejection). Add a `picky` field to `CreaturePersonality`, rolled at hatch. **Reproducible only via injected/seeded `Random`.** | User decision 2026-06-05; FR-004 (prd.md:72); **overrides** guardrail prd.md:39 | **DECIDED random**; probability function + trait range OPEN |
| 8 | Clamp `[0,100]` | hunger/energy floor at 0, no stat above 100 | FR-008 (prd.md:68) + 0-100 scale | source-derived |
| 9 | Mood re-derived | Recompute via `deriveMood` on new stats | deriveMood (creature_service.dart:38-45) | source-derived |
| 10 | Journal pair shell | Exactly one `JournalEntry{event:feed, statDelta=actual deltas, non-empty prose}` | FR-009, US-01 (prd.md:53,82) | presence + delta values source-derived |
| 11 | Test-seam boundary | **Reproducible with a seeded `Random` + stubbed LLM:** stat math/clamp/full-rejection/mood/StatDelta/journal-presence (deterministic) AND the picky accept/reject roll (stochastic but seed-reproducible). **Not reproducible:** AI prose & response wording. | guardrail prd.md:39 (with the picky exception); existing `Random rng` seam (creature_service.dart:50) | the testable seam — inject `Random`, stub LLM |
| 12 | Pairing coherence | A `feed` journal entry exists iff the stat mutation it describes was applied | FR-009 (prd.md:82) | source-derived (invariant, not exact prose) |
| 13 | Love/illness untouched | Feed changes only hunger↓ and energy↓; `loveDelta==0`, `illnessDelta==0` | FR-004 vs FR-005/006 (prd.md:74-76) | source-derived (interaction→stat mapping) |

### D. Full-stack Feed wiring (Flutter) — the patterns to copy

- **`creature_provider.dart:11-13`** — `@Riverpod(keepAlive: true) Future<CreatureStatus?> creature(ref)` calling `ref.read(serverpodClientProvider).creature.myCreature()`. Widgets `ref.watch(creatureProvider)` → `AsyncValue`. **Refreshed after mutation via `ref.invalidate(creatureProvider)`** (the project's idiom — `ref.refresh` is used nowhere).
- **`hatch_controller.dart:13-26`** — the EXACT `feedController` template: `@riverpod class HatchController extends _$HatchController` with `FutureOr<void> build(){}` and an action that does `state = AsyncLoading()` → `state = await AsyncValue.guard(() async { await client.creature.hatch(name); ref.invalidate(creatureProvider); })`. **Caveat:** hatch discards its return value; Feed must surface the AI text, so widen the controller state (e.g. `FutureOr<FeedResult?> build() => null;` then `state = AsyncData(result)`).
- **`home_screen.dart:40-47`** — `creatureStatus.when(loading/error/data)`; `data: status == null ? HatchForm() : CreatureView(status)` is the empty→present flip. Stats re-render automatically once `creatureProvider` is invalidated.
- **`creature_view.dart`** — currently a `StatelessWidget` rendering name/mood/4 `_StatRow`s. **The Feed button belongs here**; it must become a `ConsumerWidget` to `ref.watch(feedControllerProvider)` (loading/disable), call `.feed()` on press, and render the AI response text.
- **`hatch_form.dart`** — the action-trigger pattern (watch controller, derive `isLoading`, in-flight spinner swap, typed-error mapper `_hatchErrorText` switching on `CreatureHatchError.reason`). Feed is simpler (a button, no text field) but needs an analogous typed-error mapper if rejection is surfaced.
- **`client_provider.dart:12-15`** — `serverpodClientProvider` (overridden at root in `main.dart:38`); the feed controller gets the client via `ref.read(serverpodClientProvider)`.
- **`app_router.dart` + `main.dart`** — Feed adds **no route**; it's an in-place interaction on `/` behind the existing auth guard.
- **Client regen:** the generated `EndpointCreature` (`tamagotchi_client/.../client.dart:249-271`) has only `hatch`/`myCreature` today — after adding server `feed`, run `serverpod generate` to get `client.creature.feed(...)`.
- **`CreatureStatus` carries no AI text** today (`{creature, mood}`). S-03 needs a new return type (e.g. `FeedResult`) or to widen `CreatureStatus` to carry the user-facing response.

**Tests** (`tamagotchi_flutter/test/`): `app/app_router_redirect_test.dart`, `creature/creature_view_test.dart`, `home/home_screen_test.dart`. Pattern (per lesson `Test async Riverpod surfaces with provider overrides`): override `creatureProvider.overrideWith((ref)=>...)` for loading/error/data; fake the action notifier (`hatchControllerProvider.overrideWith(_FakeHatchController.new)`) flipping a `StateProvider` seam instead of hitting the server (`StateProvider` from `package:flutter_riverpod/legacy.dart` in Riverpod 3.x). **S-03 adds a `_FakeFeedController`** + `feedControllerProvider` override, asserting the Feed button renders, tapping calls the controller, updated stats render after the (fake) refresh, and the AI response text appears.

## Code References

- `tamagotchi_server/lib/src/creature/creature_service.dart:38-45` — `deriveMood` oracle (reuse as-is)
- `tamagotchi_server/lib/src/creature/creature_service.dart:14` — `baselineCreatureStats`
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:44-87` — hatch transaction (journal-write pattern to mirror)
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:113-128` — `myCreature` load-by-owner + `_moodOf`
- `tamagotchi_server/lib/src/creature/journal_event.spy.yaml:6` — `feed` enum value (already present)
- `tamagotchi_server/lib/src/creature/stat_delta.spy.yaml:4-8` — `StatDelta` (ready to populate)
- `tamagotchi_server/lib/src/creature/creature_personality.spy.yaml:4-5` — interaction mods deferred to S-03/S-04 (no picky field yet)
- `tamagotchi_server/lib/server.dart:160-215` — EmailLabs REST precedent (secret + run-mode gate + `http.post` + `jsonDecode`)
- `tamagotchi_server/pubspec.yaml:18` — `http: ^1.6.0` already present
- `tamagotchi_flutter/lib/creature/hatch_controller.dart:13-26` — `feedController` template
- `tamagotchi_flutter/lib/creature/creature_provider.dart:11-13` — async provider + `ref.invalidate` refresh
- `tamagotchi_flutter/lib/home/home_screen.dart:40-47` — `.when` + empty→present flip
- `tamagotchi_flutter/lib/creature/creature_view.dart` — where the Feed button attaches (needs ConsumerWidget)
- `tamagotchi_flutter/test/creature/creature_view_test.dart` — provider-override test pattern to copy
- `tamagotchi_client/lib/src/protocol/client.dart:249-271` — generated `EndpointCreature` (regen after adding `feed`)

## Architecture Insights

- **Feature-dir convention holds:** the LLM client gets its own `lib/src/llm/` dir; the `feed` endpoint stays in `creature/`. No top-level layer dirs.
- **The test seam has two stubs, not one.** Per the M3L2 two-layer guidance: the stat math + clamping + full-rejection + mood + StatDelta + journal-entry presence are **integration-testable against a real DB with a stubbed LLM** (the `withServerpod` harness — see `serverpod-testing` skill and lesson on Serverpod integration tests in the devcontainer). The **picky accept/reject roll is now stochastic** (user decision) but stays testable by **injecting a seeded/stubbed `Random`** — the exact pattern S-02 already uses for `randomPersonalityModifiers(Random rng)` (`creature_service.dart:50`); a forced-low/high seed pins accept vs reject. The AI prose is asserted only for **presence/non-emptiness**, never exact text. Net: stub the F-02 `LlmService` + inject `Random`, and the whole slice is reproducible. This is now recorded in the PRD: the "Stats are deterministic given inputs" guardrail was **amended 2026-06-05** to carve out the feed-acceptance gate as a deliberate, scoped randomness exception (stat *magnitudes* on an accepted feed remain deterministic; Pet/Cure stay fully deterministic).
- **Non-atomic save risk:** hatch already does its writes in a `session.db.transaction`. S-03's Feed performs (1) stat update + (2) journal insert; doing both inside one transaction keeps the FR-009 "coherent pair" invariant atomic and avoids the partial-failure branch the M3L2 lesson warns about. If the LLM call sits between load and write, decide whether an LLM failure aborts the stat change or falls back to a canned line (see Open Questions).
- **Mutation-refresh idiom is `ref.invalidate`** — keep it; do not introduce `ref.refresh`.
- **Run-mode gating is the established way to keep secrets out of the devcontainer** — reuse it for the LLM call so `flutter`/`dart test` and local runs never need an API key.

## Historical Context (from prior changes)

- `context/foundation/roadmap.md:120-131` — S-03 is the **north star**; riskiest assumption is "AI responses feel uniquely in-character." Mitigation: scope to Feed only; defer Pet/Cure/empty-energy. F-02 flagged as a hard prereq not yet started.
- `context/foundation/roadmap.md` S-02 row — `hatch-creature-and-view-stats` merged as `0c8b910` (#8). S-01 (`signed-in-empty-creature-view`) is **deferred** (Phase 7 EmailLabs sender-auth blocked on DNS) — but its auth scaffold (the `requireLogin`/`session.authenticated` path) is what S-03 builds on.
- `context/foundation/lessons.md` — two directly-applicable lessons: (1) apply migrations via `serverpod run start`, not `--apply-migrations`; (2) test async Riverpod surfaces with provider overrides, not a real RPC (established on S-02's `creatureProvider`/`HomeScreen`, explicitly "reusable for S-03's interactive slice").
- Memory: `project_tamagotchi_email_emaillabs` (scloud blocks SMTP, allows HTTPS REST — same egress story for Anthropic), `feedback_no_db_credentials_in_devcontainer` + `project_scloud_auto_manages_secrets_and_db_config` (no real secrets in devcontainer; scloud injects at runtime), `project_serverpod_integration_tests_run_in_devcontainer` (how to run the integration layer for the deterministic oracle).

## Open Questions (for `/10x-plan` — sources do NOT pin these down)

1. **`D_h` — hunger reduction per Feed.** Flat amount? proportional to current hunger? OPEN.
2. **`C_e` — energy cost per Feed.** OPEN.
3. **Full-rejection threshold.** Reject only at `hunger == 0`, or at a near-full band `hunger <= T`? OPEN.
4. **Picky accept/reject — DECIDED random; sub-decisions remain.** Shape resolved: a probabilistic roll over a `picky` trait + current hunger, reproducible via seeded `Random`. Still OPEN: (a) the **probability function** `P(reject) = f(picky, hunger)` — its exact form and the hunger→pickiness direction (assume hungrier ⇒ less likely to refuse); (b) the **`picky` trait's range/distribution** when added to `CreaturePersonality` and rolled at hatch (reuse the `[0.5,1.5)`-style roll or a `[0,1]` probability scalar?); (c) whether picky-rejection surfaces the **same** typed reason as full-rejection or a distinct one.
5. **Does picky-rejection consume energy?** (Creature "tried" and refused.) OPEN.
6. **Rejection surface mechanics.** Exact exception/enum name; throw vs return a discriminated result (so a refusal line/prose can ride along). OPEN.
7. **Picky-rejection journal behavior.** FR-009 says "each interaction produces a journal entry" — does a refusal still write an entry (zero/near-zero StatDelta + refusal prose) or nothing? Source-ambiguous. OPEN.
8. **Energy-gate scope.** FR-007's `energy==0` block is slice **S-06**. Does S-03 implement only the happy path (assume energy>0) or stub the gate now? OPEN (scoping).
9. **N — journal window size.** Model header implies 10 ("last-10 narrative entries"); confirm N=10 and whether to drop empty-prose `hatched` markers from the prompt.
10. **Streaming vs single-block** (NFR-1 "continuous visible progress within 5s"). For a short two-field structured response, single-block + a loading animation is likely sufficient; decide at plan time. (Flagged in `change.md` / roadmap.)
11. **LLM model + structured-output method — DECIDED provider/model.** Mistral `mistral-small-2603` via `response_format:{type:"json_schema"}`. Remaining detail: confirm the exact `json_schema` envelope (name/schema/strict) against the Mistral custom-structured-output docs page at plan time.
12. **LLM-failure posture.** Fail the interaction, or apply the deterministic stat change + fall back to a canned in-character line + generic journal entry? (Affects transaction boundary.)
13. **Return type for the AI text.** New `FeedResult` model vs widening `CreatureStatus` to carry the user-facing response. OPEN.

## Related Research

- None yet under `context/changes/**/research.md` for this feature. This is the first research artifact for `feed-with-personality-response`. F-02 (`llm-client-prompt-surface`) has no change folder; the F-02 design in §B should seed it when that slice is opened (likely build F-02 first, or fold the minimal LLM surface into S-03).

## Recommended sequencing note

**DECIDED 2026-06-05: path (b) — F-02 is folded into S-03.** No standalone F-02 change folder; this slice builds the LLM surface (`llm/mistral_client.dart` + `creature_prompt.dart` + the `mistralApiKey` secret + dev stub) behind an `LlmService` interface, so the deterministic stat layer + the (seeded-RNG) picky roll can be built and tested against stubs immediately, with the real Mistral wiring landing in the same change. S-04/S-05 reuse the surface this slice produces. The roadmap F-02 row is marked `folded → S-03`. The `LlmService` stub seam plus an injected `Random` is what unblocks the oracle tests without a live model.

## Follow-up Research 2026-06-05T18:34:35+00:00 — Mistral provider + random pickiness decisions

Two owner decisions landed after the initial pass; the body above was updated in place. Recorded here verbatim for the plan.

**Decision 1 — Provider = Mistral AI.** Model `mistral-small-2603` (Mistral Small 4). Replaces the earlier Anthropic recommendation. Mistral API quick-reference (from https://docs.mistral.ai/api and the model card):

- Endpoint: `POST https://api.mistral.ai/v1/chat/completions` (base `https://api.mistral.ai`).
- Auth header: `Authorization: Bearer <MISTRAL_API_KEY>` (note: Bearer, not the `x-api-key` of Anthropic). Secret key name: `mistralApiKey` via `session.passwords[...]`.
- Required body: `model` (`"mistral-small-2603"`), `messages` (array of `{role, content}`). Common optional: `temperature`, `max_tokens`, `stream`, `top_p`, `response_format`.
- Structured output `response_format` modes: `{type:"text"}` | `{type:"json_object"}` (valid JSON, no schema) | `{type:"json_schema"}` (JSON conforming to a supplied schema — use this for `{userResponse, journalNarrative}`). Confirm the exact `json_schema` envelope at plan time.
- Response parse: OpenAI-shaped — `choices[0].message.content` → `jsonDecode`.
- Model facts: 256k context; **$0.15/1M input, $0.60/1M output**; capabilities Function Calling, Structured Outputs, Predicted Outputs. Cheap/low-latency enough for the per-interaction Feed hot path.
- Minimal verbatim example from docs:
  ```bash
  curl https://api.mistral.ai/v1/chat/completions -X POST \
    -H 'Authorization: Bearer YOUR_APIKEY_HERE' \
    -H 'Content-Type: application/json' \
    -d '{"messages":[{"content":"your prompt","role":"user"}],"model":"mistral-small-latest"}'
  ```

**Decision 2 — Pickiness is RANDOM.** User: *"not accepting food HAS TO BE RANDOM based on an appropriate creature's trait and hunger."* This reverses oracle #7's earlier "must be deterministic" reading. Consequences threaded through the doc: add a `picky` trait to `CreaturePersonality` (rolled at hatch via the existing `Random` seam); the accept/reject gate is a probability `P(reject) = f(picky, hunger)` evaluated against an RNG draw; tests pin the outcome with a **seeded/stubbed `Random`** (same seam as `randomPersonalityModifiers`). This is a scoped, deliberate exception to the PRD guardrail "no randomness in core mechanics" — flagged for a `/10x-lesson` or PRD amendment so it's recorded, not a silent contradiction. Stat magnitudes on an *accepted* feed remain deterministic.
