# Empty Energy Gate (FR-007) — Plan Brief

> Full plan: `context/changes/empty-energy-gate/plan.md`

## What & Why

Implement FR-007: at empty energy, all interactions except Cure are blocked and the creature returns a pre-written "exhausted" response. This closes the interaction model's energy economy — Feed/Play cost energy (FR-004/005), so there must be a floor where they stop being available, creating the natural pacing rhythm the PRD calls for and bounding the cost of LLM-generated responses.

## Starting Point

Feed and Play already deduct energy and clamp it to 0, but nothing stops an interaction the creature can't afford — energy just bottoms out. Cure already costs no energy. The full-refusal path (a stuffed creature declining food with a canned line, no LLM, no journal) is the exact pattern this gate mirrors.

## Desired End State

When a creature can't afford Feed or Play, the app disables that button and shows an "out of energy" hint; Cure stays available. The server enforces the gate authoritatively and, if a click slips through, returns a pre-written exhausted line rendered as distinct in-character flavor (never an error). Energy regenerates over time, so buttons re-enable on their own.

## Key Decisions Made

| Decision | Choice | Why | Source |
| --- | --- | --- | --- |
| Gate threshold | Block when `energy < interaction cost` (per-interaction) | No interaction ever partially lands; matches the real cost the creature must pay | Plan |
| Button behavior | Disable unaffordable Feed/Play + show "out of energy" hint | Prevents the wasted click; communicates the block proactively | Plan |
| Journal on block | No entry | A blocked attempt is a non-event; mirrors the full-refusal path | Plan |
| Exhausted visual | Visually distinct state via a dedicated `exhausted` flag | Differentiates "out of energy" from a food refusal | Plan |
| Affordability signal | Server-computed `canFeed`/`canPlay` on `CreatureStatus` | Play cost is personality-derived; keep cost logic server-side, single source of truth | Plan |
| Exhausted copy | Per-interaction pools (`feedExhaustedLines`, `playExhaustedLines`) | Tailored flavor ("too tired to chew" vs "to romp") | Plan |

## Scope

**In scope:** server energy gate on Feed/Play (Cure exempt); `canFeed`/`canPlay` + `exhausted` model fields (codegen, no migration); per-interaction exhausted copy pools + RNG selectors; client button disabling, hint, and distinct response styling; server integration + Flutter widget tests.

**Out of scope:** DB migration (models are non-table); changes to costs/decay rates; energy gate on Cure; LLM/personality-flavored exhausted copy; journal entries for blocked attempts; e2e/patrol tests.

## Architecture / Approach

Backend-first. The server adds a `_statusFor` helper computing affordability for every `CreatureStatus`, and two early-return gates in `feed()`/`play()` keyed on post-decay `base.energy` vs the existing cost functions (`feedEnergyCost`, `playEnergyCost(loveRegenMod)`) — each returns a canned exhausted line with no LLM, no stat change, no journal, no persistence (mirroring full-refusal). The regenerated client models then drive the UI: `canFeed`/`canPlay` disable buttons + show the hint, and the `exhausted` flag styles the backstop response.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Server (`/10x-tdd`) | Model fields + codegen, exhausted copy pools + selectors, `_statusFor` helper, Feed/Play gates | Touching every `CreatureStatus` site; keeping Play's stat math RNG-free while adding a cosmetic RNG |
| 2. Client (`/10x-implement`) | Button disabling, energy hint, distinct exhausted styling | Hint placement/visual polish; threading `exhausted` through the shared outcome record |

**Prerequisites:** Phase 2 depends on Phase 1's `serverpod generate`. Integration tests need the Postgres sidecar (`docker compose up -d`).
**Estimated effort:** ~1–2 sessions across 2 phases.

## Open Risks & Assumptions

- Exhausted early-return deliberately does not persist decay; safe because the decay anchor isn't advanced and re-accrues idempotently next poll. (Documented in the plan's Critical Implementation Details.)
- The exhausted backstop response is rarely seen once buttons disable correctly — but it remains the authoritative enforcement and satisfies FR-007's "returns a pre-written response."
- Adding a `Random` to `PlayService` is for cosmetic line variety only; `playDelta` stays deterministic per `prd.md:39`.

## Success Criteria (Summary)

- A creature too tired to Feed/Play has those buttons disabled with a visible hint; Cure still works.
- Blocked interactions change nothing (no stats, no journal) and never call the LLM.
- Buttons re-enable automatically as energy regenerates.
