# Feed the creature once and get a personality-driven response + journal entry (NORTH STAR) — Plan Brief

> Full plan: `context/changes/feed-with-personality-response/plan.md`
> Research: `context/changes/feed-with-personality-response/research.md`

## What & Why

S-03 is the product's **north star** — the smallest end-to-end slice that proves the core hypothesis: AI-driven personality + a structured journal makes a virtual pet feel uniquely alive. A logged-in user Feeds their creature, gets a personality- and food-shaped in-character AI response, the journal gains a coherent narrative entry from the same call, and stats update deterministically behind a random accept/refuse roll. The LLM client (ex-F-02) is folded into this slice behind an `LlmService` interface.

## Starting Point

S-02 shipped the full data model (`Creature`/`CreaturePersonality`/`JournalEntry`/`StatDelta`, `JournalEvent.feed` already present), a pure `deriveMood()` + the `randomPersonalityModifiers(Random rng)` seeded-RNG seam, the owner-scoped `hatch()`/`myCreature()` endpoint pattern (one-transaction writes), and the Flutter `creatureProvider` + `hatchController` + provider-override test pattern. There is **no** LLM code, Feed endpoint, Feed UI, or feed math yet. EmailLabs (`server.dart`) is the existing precedent for an external REST call with a runtime secret.

## Desired End State

Pressing Feed shows a continuous loading animation, then within ~5s an in-character response referencing the creature's personality and a randomly-rolled, funnily-named food. Stats move (hunger −30, energy −10, clamped) and the journal gains one coherent `feed` entry. Sometimes the creature refuses — a random roll weighted by pickiness (derived from `hungerDecayMod`), hunger, and food tastiness — and says so in character. A full creature gets a canned "stuffed" line; a flaky model degrades gracefully instead of failing.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| LLM provider/model | Mistral `mistral-small-2603`, REST `json_schema` | Cheap, low-latency, OpenAI-compatible structured output | Research |
| Pickiness source | Derived from existing `hungerDecayMod` (no new field) | Traits already encode personality; low decay ⇒ pickier | Plan |
| Accept/refuse curve | `P(reject)=picky×(1−hunger/100)×(1−tastiness)` | Monotonic; gourmet food or a starving creature drive refusal→0 | Plan |
| Tastiness | Per-Feed random `[0,1)`, raw to prompt | AI invents a funny food name; also lowers `P(reject)` | Plan |
| Hunger drop / energy cost | Flat −30 / flat −10 (clamped) | Deterministic, satisfying cadence, leaves energy headroom | Plan |
| Full gate | Reject only at `hunger==0` | Literal "already full"; one clean boundary | Plan |
| Refusal surface | `FeedResult{accepted}` (never throw) | Refusals are in-character content, not errors | Plan |
| Refusal AI/journal | Picky → LLM + zero-delta entry; full → canned line, no entry | Picky refusals shine; avoid spamming "still full" | Plan |
| LLM failure (prod) | Degrade: apply stats + canned line + generic entry | Never hard-fail on a flaky model; honor NFR-1 | Plan |
| Dev LLM access | Dev gets a real key → calls live model; key-less → stub | Manual testing hits the real model; CI stays hermetic | Plan |
| Wait UX | Single-block + loading animation (no streaming) | Two-field JSON doesn't stream cleanly; <5s suffices | Plan |
| Energy gate (FR-007) | Out of scope (slice S-06) | Keep the north-star slice focused | Plan |

## Scope

**In scope:** LLM surface (`LlmService` + Mistral client + stub + prompt builder + canned copy + `mistralApiKey`); pure Feed domain logic (clamp, picky, tastiness, gate) with a seeded-RNG seam; the `feed` endpoint + `FeedResult` + journal-pair transaction + degrade + `serverpod generate`; Flutter Feed button/controller/response UI; unit + integration + widget tests.

**Out of scope:** any DB migration/schema change; FR-007 energy gate (S-06); Pet/Cure (S-04/S-05); token streaming; tastiness-driven stat magnitudes; semantic/vector journal search; `test-plan.md` cookbook (created after this slice).

## Architecture / Approach

Bottom-up so each layer is testable before the next depends on it: **LLM surface** (behind an interface, real vs stub chosen by `mistralApiKey` presence, with a test-overridable `llmServiceFactory`) → **pure Feed domain** (driven by an injectable `Random` via `feedRandomFactory`) → **endpoint** (composes both in one `session.db.transaction`, LLM call before the transaction so a failure degrades to canned copy without breaking the stat+journal pair) → **Flutter UI**. Both randomness sources flow through seams, so the entire slice is reproducible under a seed + stub; key-less environments auto-select the stub so CI never needs a Mistral key.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. LLM surface + secret | `LlmService`, Mistral client, stub, prompt builder, canned copy, key wiring | Exact `json_schema` envelope; confirm vs Mistral docs at implement time |
| 2. Feed domain + unit tests | Clamp, picky, tastiness, `evaluateFeed` under seeded RNG | Getting the curve direction + RNG draw order right (contract) |
| 3. Endpoint + FeedResult + integration tests | `feed()`, journal-pair transaction, degrade, codegen | Atomicity of stat+journal; degrade branch; owner-scoping |
| 4. Flutter wiring + widget tests | Feed button, controller, loading + response UI | Loading-state test timing; layout overflow on long responses |

**Prerequisites:** S-02 (done); a dev `mistralApiKey` for manual verification (Phases 1/3/4); Postgres sidecar (`docker compose up -d`) for integration tests.
**Estimated effort:** ~3–4 sessions across 4 phases.

## Open Risks & Assumptions

- The riskiest product assumption — that responses feel uniquely in-character given this prompt + model + memory window — is validated here; the prompt will likely need iteration after first manual runs.
- The Mistral `json_schema` envelope is taken from docs; if rejected, fall back to `json_object` + schema-in-prompt.
- A dev API key in the devcontainer is a deliberate, approved exception to the no-secrets rule (which governs DB creds); keep it out of git.

## Success Criteria (Summary)

- A user Feeds and gets an in-character, food-referencing response + a coherent journal entry within ~5s; stats update correctly.
- Refusals (random picky + already-full) read as in-character content, not errors; behavior is reproducible under a seed + stub in tests.
- A model failure degrades gracefully (stats still change, canned line, no crash).
