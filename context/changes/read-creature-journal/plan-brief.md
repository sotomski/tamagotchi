# Read Creature Journal (S-08 / FR-011) — Plan Brief

> Full plan: `context/changes/read-creature-journal/plan.md`
> Frame brief: `context/changes/read-creature-journal/frame.md`
> Research: `context/changes/read-creature-journal/research.md`

## What & Why

S-08 is **not** a read-plumbing slice. The journal entries on disk are real but
**not a clean narrative** — a blank hatch opener, a silent gap where a full feed-refusal
wrote no entry, "+0 +0 +0" zero-delta non-events, and verbatim-repeated fallback prose.
The slice's job (and its PRD success criterion — "journal feels like a story", `prd.md:35`)
is to turn that raw, uneven stream into **one creature's coherent story**. That spans
**read + write + prompt + UI**, not read-only.

## Starting Point

The write path is fully built: every interaction persists a `JournalEntry`
(`timestamp/event/statDelta/prose`) in one transaction, so the data is coherent. What's
missing: any read endpoint or screen, a real birth entry (hatch is deterministic and writes
`prose: ''`), a trace for full refusals (they early-return and write nothing), and any
narrative memory beyond a flat last-10 prose window assembled identically in three places.

## Desired End State

The owner opens `/journal` and reads a newest-first, **day-grouped** history that opens with a
personalized **"Day one"** birth card naming the creature and its character, where every
performed interaction — including full refusals and zero-delta moments — leaves a softened,
in-voice trace, and where narration references earlier moments and recalls the creature's own
birth.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Reading order | Newest-first, **day-grouped**, distinct "Day one" origin | Honors owner's feed instinct while day-scaffolding clears "feels like a story" | Frame |
| Edge-entry curation | **Relabel/soften, keep all** (no "+0" chips, muted "nothing changed") | Honors FR-009 traces and stays consistent with the full-refusal entry we're adding | Plan |
| Birth entry | **LLM-generated** intro (name + character), **blocks hatch on failure** | Owner wants a real personalized opener, not a canned line | Plan |
| Full-refusal gap | **Route through the LLM** + explicit severity field; write zero-delta entry | A performed interaction must leave a trace; full ≠ picky needs its own narration | Plan |
| Memory window | **Structured** (event + relative age via clock) + **birth pinned permanently** | Enables specific backward callbacks and lifelong origin recall | Plan |
| Endpoint / folder | `readJournal` on `CreatureEndpoint`; Flutter in `lib/creature/` | Co-locate with the ownership pattern and existing creature providers | Research |

## Scope

**In scope:** read endpoint (IDOR-scoped) + `/journal` screen; day-grouped newest-first UI
with origin card + softened zero-delta rendering + "Pet" label; LLM birth entry (block-on-fail);
full-refusal-through-LLM trace; structured pinned-birth memory window + callback prompt reword.

**Out of scope:** pagination; semantic/vector long-term memory; new `JournalEndpoint`;
`lib/journal/` folder; `intl`; canned hatch fallback; enum rename; dedup of repeated prose.

## Architecture / Approach

`readJournal` mirrors the existing last-10 query (IDOR-scoped, keeps the hatched marker) and
flows to a `@riverpod` provider + a `ListView` screen. On the write/prompt side: hatch gains an
LLM call before its transaction (a new `hatched` prompt branch; failure throws
`CreatureHatchError`); the full-refusal path drops its early-return and writes a zero-delta entry
narrated via a new severity field; the 3× duplicated memory assembly is extracted into one
helper that emits a structured window (event + clock-derived age + prose) with the birth entry
pinned. `InteractionRequest` is a plain server-internal class, so all field additions are
codegen-free — only `readJournal` and one new enum value trigger `serverpod generate`. **No DB migration.**

## Phases at a Glance

| Phase | Workflow | What it delivers | Key risk |
| --- | --- | --- | --- |
| 1. Read floor | `/10x-tdd` | `readJournal` endpoint + IDOR integration test | IDOR — must deny non-owner, not just allow owner |
| 2. Journal screen | `/10x-implement` | Provider, `/journal` route, day-grouped UI, origin card, soften, "Pet" | First list UI; render branches via provider-override tests |
| 3. LLM birth | `/10x-tdd` | LLM-generated birth, block-on-failure, hatch test inversion | Blocks creature creation on real-key LLM outage |
| 4. Full-refusal trace | `/10x-tdd` | Severity field + prompt branch; zero-delta entry; test inversion | Inverting the "writes no entry" test; widening scripted RNG |
| 5. Memory window | `/10x-tdd` | Structured window + pinned birth + callback reword + helper extract | Contract change to `recentEntries`; clock-deterministic tests |

**Workflow split:** Phase 2 is `/10x-implement` (UI-dominant; pure helpers TDD'd within). Phases 1, 3, 4, 5 are `/10x-tdd` — each has a crisp behavioral contract to drive red→green (IDOR denial, block-on-failure, the full-refusal test inversion, and pure pinning/dedup/clock-age logic).

**Prerequisites:** branch `feat/read-creature-journal`; sidecars up; test DB password for integration runs. Phase 3 before Phase 5 (pinning needs birth prose).
**Estimated effort:** ~5 sessions across 5 phases (Phases 3–5 are the LLM-heavy bulk).

## Open Risks & Assumptions

- **Block-on-failure puts an LLM call on the app's single most critical action.** A Mistral
  outage prevents creature creation. Mitigated: the no-key `StubLlmService` always succeeds, so
  only real-key production can fail; surfaced as a distinct `CreatureHatchErrorReason`.
- **Repeated degrade prose still reads samey** — "keep all" doesn't dedup; acceptable for MVP.
- **Prose-only birth constant in the pinned window** mildly anchors early voice across creatures
  (only on stub/degrade paths; real births are unique).
- **Pinned-birth dedup**: must not double-render the birth when it's also within the last-N window.

## Success Criteria (Summary)

- A non-owner cannot read another user's journal (integration-proven).
- `/journal` reads as a day-grouped story opening with a personalized origin card; full refusals
  and zero-delta moments leave softened, in-voice traces (no "+0" noise).
- Narration references earlier moments and recalls the creature's birth even after >10 interactions.
