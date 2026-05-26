---
project: AI-Tamagotchi
version: 1
status: draft
created: 2026-05-26
updated: 2026-05-26
prd_version: 1
main_goal: learn
top_blocker: decisions
---

# Roadmap: AI-Tamagotchi

> Derived from `context/foundation/prd.md` (v1) + auto-researched codebase baseline + 2026-05-26 framing interview.
> Edit-in-place; archive when superseded.
> Slices below are listed in dependency order. The "At a glance" table is the index.

## Vision recap

The MVP exists to test whether AI-driven personality — coupled to a structured journal that gives each creature real continuity — can make a virtual pet feel uniquely alive rather than a clickable stat dashboard. The personas are adult hobbyists (virtual-pet enthusiasts, AI-curious tinkerers); success is whether the creature's character is recognizable from its responses alone, and whether two creatures with opposite traits, given the same care, end up measurably different.

## North star

**S-03 — user Feeds the creature once after hatching and receives a personality-driven AI response paired with a narrative journal entry** is the **north star**: the smallest end-to-end slice that, if it ships and works, proves the product's *core hypothesis* (the claim the MVP exists to test — that AI-driven personality plus a structured journal makes a virtual pet feel uniquely alive). It is placed as early as Prerequisites allow because everything else only matters if this works. The slice maps to US-01 verbatim and is the "MVP proof moment" named explicitly in `shape-notes.md`.

## At a glance

| ID   | Change ID                              | Outcome (user can …)                                                              | Prerequisites | PRD refs                       | Status   |
| ---- | -------------------------------------- | --------------------------------------------------------------------------------- | ------------- | ------------------------------ | -------- |
| F-01 | `frontend-state-mgmt-routing-scaffold` | (foundation) Riverpod + router scaffold replaces the bootstrap counter UI         | —             | NFR-1                          | ready    |
| F-02 | `llm-client-prompt-surface`            | (foundation) Server-side LLM client + prompt with last-10 journal entries (FR-009) | —             | FR-009                         | ready    |
| S-01 | `signed-in-empty-creature-view`        | sign in (email+password) and land on a "no creature yet" home                     | F-01          | FR-001                         | proposed |
| S-02 | `hatch-creature-and-view-stats`        | hatch a creature with randomized traits and see its current stats + mood          | S-01          | US-01, FR-002, FR-003          | proposed |
| S-03 | `feed-with-personality-response`       | Feed the creature once and receive a personality-driven response + journal entry  | S-02, F-02    | US-01, FR-004, FR-009, FR-011  | proposed |
| S-04 | `pet-with-personality-response`        | Pet the creature and receive a personality-driven response + journal entry        | S-03          | FR-005                         | proposed |
| S-05 | `cure-the-creature`                    | Cure the creature when sick, regardless of energy                                 | S-03          | FR-006                         | proposed |
| S-06 | `empty-energy-gate`                    | hit the empty-energy gate and receive a pre-written exhausted line (no AI call)   | S-03          | FR-007                         | proposed |
| S-07 | `real-time-stat-decay`                 | leave and return to see stats decayed (with a floor) and energy regenerated       | S-02          | FR-008                         | proposed |
| S-08 | `read-creature-journal`                | open the journal and read the full history of narrative entries                   | S-03          | FR-011                         | proposed |
| S-09 | `reset-and-rehatch`                    | reset the current creature and hatch a fresh one                                  | S-02          | FR-010                         | proposed |

## Streams

Navigation aid — groups items that share a Prerequisites chain. Canonical ordering still lives in the dependency graph below; this table is the proposed reading order across parallel tracks.

| Stream | Theme                          | Chain                                                       | Note                                                                                                          |
| ------ | ------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| A      | Account & creature lifecycle   | `F-01` → `S-01` → `S-02` → `S-09`                           | Sets up state management, auth handoff, hatch+view, and reset. `S-09` forks late off `S-02`.                  |
| B      | AI loop                        | `F-02` → `S-03` → (`S-04` / `S-05` / `S-06` / `S-08`)       | Joins Stream A at `S-03` (which also needs `S-02`). `F-02` is `blocked` on ORQ-1 (memory architecture).        |
| C      | Background decay               | `S-07`                                                      | Joins Stream A at `S-02`; runs parallel with Stream B once `S-02` lands.                                      |

## Baseline

What's already in place in the codebase as of 2026-05-26 (auto-researched + user-confirmed).
Foundations below assume these are present and do NOT re-scaffold them.

- **Frontend:** partial — Flutter Web client lives at `tamagotchi/tamagotchi_flutter/lib/main.dart`; vanilla `setState`, no router; `SignInScreen` exists but is commented out in `main.dart:70–76`; only `GreetingsScreen` (echo demo) is wired by default.
- **Backend / API:** partial — Serverpod 3.4.8 wired; endpoints present: `greeting.hello`, `emailIdp.*`, `jwtRefresh.refreshAccessToken`. No creature / journal / stat endpoints. No future-call scaffolding. No AI / LLM client.
- **Data:** partial — Postgres 16 with pgvector image declared in `docker-compose.yaml`; pgvector NOT yet referenced in any SQL. Only Serverpod model on disk: `greeting.spy.yaml`. One initial migration (`20260521163433251`). No seed data.
- **Auth:** partial — `serverpod_auth_idp_server/flutter 3.4.8` wired both sides; email+password configured via `EmailIdpConfigFromPasswords`; Flutter `authSessionManager` + `client.auth.initialize()` set up; `SignInScreen` exists but commented out. **No OAuth provider configured** (deferred per 2026-05-26 framing interview; see `## Parked`).
- **Deploy / infra:** present — Dockerfile (two-stage), five GitHub Actions workflows including `deploy.yml` running `scloud deploy` (auto-on-tests-success and manual dispatch), `production.yaml` filled for public hosts with DB block intentionally placeholder (scloud injects creds at runtime). Project was successfully deployed once on 2026-05-23 (see `context/deployment/deploy-plan.md`).
- **Observability:** absent — only Serverpod's built-in `Session.log()`. No error tracking (Sentry et al.), no metrics / OpenTelemetry, no health-check endpoint. Staying minimal for MVP per 2026-05-26 framing interview.

## Foundations

### F-01: Frontend state management + routing scaffold

- **Outcome:** (foundation) Riverpod (or equivalent) plus GoRouter (or equivalent) scaffold replaces the bootstrap counter UI in `main.dart`; subsequent feature slices can each ship a screen + state container without re-arguing the framework.
- **Change ID:** `frontend-state-mgmt-routing-scaffold`
- **PRD refs:** NFR-1 (the 5-second perceived response with continuous progress relies on having a real state container, not local `setState`)
- **Unlocks:** S-01, S-02, S-03 (and transitively every user-facing slice)
- **Prerequisites:** —
- **Parallel with:** F-02 (independent layer; can run alongside as soon as F-02 unblocks)
- **Blockers:** —
- **Unknowns:** —
- **Risk:** introducing state management plus routing upfront costs one slice with no user-visible outcome; the payoff is consistent state and navigation across every later slice. The alternative (let each slice grow its own pattern) is the failure mode this foundation exists to prevent.
- **Status:** ready

### F-02: LLM client + prompt-rendering surface

- **Outcome:** (foundation) A server-side `LlmService` (Mistral per `shape-notes.md` §Forward: tech-stack) is callable from endpoint code; a prompt-rendering surface produces a single prompt from {personality traits, current stats, interaction performed, **last 10 journal entries**} and returns a paired (user-facing response, journal-entry prose) in one call — the FR-009 contract. Semantic-search-as-AI-tool is deferred to post-MVP (see `## Parked`).
- **Change ID:** `llm-client-prompt-surface`
- **PRD refs:** FR-009
- **Unlocks:** S-03 (north star), S-04, S-05 (every AI-response-producing slice)
- **Prerequisites:** —
- **Parallel with:** F-01, S-01 (independent layers)
- **Blockers:** —
- **Unknowns:**
  - Which specific Mistral model + temperature + prompt schema produces consistently in-character responses? Owner: user. Block: no. (Prompt-engineering iteration during planning.)
- **Risk:** F-02 sits in unfamiliar tech (no prior AI / LLM integration in the codebase). The memory-architecture decision the user had named as the top blocker resolved 2026-05-26 to "simple last-10 journal entries in the prompt, with semantic search as a deferred AI-callable tool post-MVP" — so the open call now is product-shaped (does the prompt feel in-character?), iterated at `/10x-plan` time.
- **Status:** ready

## Slices

### S-01: Signed-in empty-creature view

- **Outcome:** user can sign in with email+password and land on a "no creature yet — hatch one" home screen.
- **Change ID:** `signed-in-empty-creature-view`
- **PRD refs:** FR-001
- **Prerequisites:** F-01
- **Parallel with:** F-02
- **Blockers:** —
- **Unknowns:** —
- **Risk:** the auth scaffold already exists (`emailIdp.*` endpoints, `serverpod_auth_idp_flutter` wired) and `SignInScreen` is commented out in `main.dart:70–76`. The slice is mostly wiring + a route guard + an empty-state home — the lowest-cost first vertical slice on the way to the north star.
- **Status:** proposed

### S-02: Hatch a creature and view its stats

- **Outcome:** user can hatch one creature (randomized personality traits as continuous values) and see hunger / energy / love / illness plus a derived mood. Stats are mechanical at this point — no AI involved yet.
- **Change ID:** `hatch-creature-and-view-stats`
- **PRD refs:** US-01 (partial — the "hatch" half), FR-002, FR-003
- **Prerequisites:** S-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:**
  - Trait constraint guardrails — should personality randomization have constraints to prevent degenerate combos (all-max, all-min)? Owner: user. Block: no. (PRD §Open Questions #1; acknowledged risk for MVP, tune if play-testing surfaces unplayable creatures.)
- **Risk:** this slice fixes the data model for creature + journal. Now that ORQ-1 has resolved to "last-10 narrative entries, semantic search as a future AI tool", the journal model is a plain timestamp + narrative-prose + state-change record — no vector column needed at hatch time. A future post-MVP slice can add a vector column + ANN index without disturbing the data this slice produces.
- **Status:** proposed

### S-03: Feed the creature once and get a personality-driven response (NORTH STAR)

- **Outcome:** user Feeds the creature; receives a personality-shaped, in-character AI response; the journal gains a narrative prose entry produced in the same call; stats update per FR-004's energy-cost + personality-modifier rules.
- **Change ID:** `feed-with-personality-response`
- **PRD refs:** US-01, FR-004, FR-009, FR-011
- **Prerequisites:** S-02, F-02
- **Parallel with:** S-07
- **Blockers:** —
- **Unknowns:**
  - Streaming vs single-block response — NFR-1 says "continuous visible progress during the wait"; this slice must decide whether the LLM call streams tokens or whether a loading animation is acceptable. Owner: user. Block: no. (Pick at `/10x-plan` time.)
- **Risk:** north star — the slice that validates the entire product hypothesis. The *riskiest assumption* (that AI responses feel uniquely in-character given the chosen prompt + model + memory window) is tested here. Mitigation: scope to one interaction (Feed) only; defer Pet / Cure to follow-on slices so the prompt + response shape can iterate without coupling.
- **Status:** proposed

### S-04: Pet the creature and get a personality-driven response

- **Outcome:** user Pets the creature; receives a personality-shaped response (introvert / extravert modifier per FR-005); love stat increases; journal gains an entry.
- **Change ID:** `pet-with-personality-response`
- **PRD refs:** FR-005
- **Prerequisites:** S-03
- **Parallel with:** S-05, S-06, S-08
- **Blockers:** —
- **Unknowns:** —
- **Risk:** depends on S-03's LLM-call shape being right; if S-03's prompt schema needs rework, S-04 inherits the cost. Mitigation: ship S-03 first, iterate to a working prompt, then S-04 reuses the validated surface.
- **Status:** proposed

### S-05: Cure the creature when sick

- **Outcome:** user Cures the creature; illness drops; Cure works regardless of energy level (FR-006); creature response acknowledges the cure; journal gains an entry.
- **Change ID:** `cure-the-creature`
- **PRD refs:** FR-006
- **Prerequisites:** S-03
- **Parallel with:** S-04, S-06, S-08
- **Blockers:** —
- **Unknowns:**
  - For Cure to be testable, illness must be non-zero. Either bootstrap illness at hatch, or wait for the decay slice (S-07) to raise it over time. Owner: user. Block: no. (Pick at `/10x-plan` time; bootstrap-at-hatch is the cheaper testing path.)
- **Risk:** small slice; the FR-006 rule "always available regardless of energy" is mechanical, and user-visible distinctiveness from Feed / Pet relies on the prompt design — covered by F-02's surface.
- **Status:** proposed

### S-06: Empty-energy gate

- **Outcome:** when energy=0, Feed and Pet return one of a small set of pre-written exhausted lines (no AI call). Cure remains available.
- **Change ID:** `empty-energy-gate`
- **PRD refs:** FR-007
- **Prerequisites:** S-03
- **Parallel with:** S-04, S-05, S-08
- **Blockers:** —
- **Unknowns:** —
- **Risk:** small slice; the rule is mechanical (gate before the LLM call), and exhausted lines are static text. This gate is also the first mitigation against PRD §Open Question #5 (cost scaling), which is otherwise parked for MVP — every call this gate blocks is a call the AI vendor never sees.
- **Status:** proposed

### S-07: Real-time stat decay and energy regen

- **Outcome:** when the user returns after a period away, stats reflect personality-driven decay (with a floor — never unrecoverable) and energy reflects in-real-time regeneration (FR-008).
- **Change ID:** `real-time-stat-decay`
- **PRD refs:** FR-008
- **Prerequisites:** S-02
- **Parallel with:** S-03 (and everything downstream of S-03, since this slice doesn't touch AI)
- **Blockers:** —
- **Unknowns:**
  - Personality-driven decay rates — exact formula or table per trait. Owner: user. Block: no. (Pick during `/10x-plan`; tunable later.)
  - Whether decay is computed lazily on read or pushed via Serverpod future-calls. Owner: user. Block: no. (Both work; future-call is more conventional, lazy-on-read is cheaper; pick at `/10x-plan` time.)
- **Risk:** stretches the unfamiliar future-call API of Serverpod (per `main_goal: learn`, this is a feature, not a bug). The floor mechanic is critical — without it, returning users hit a "starving creature" state and bounce; the guilt-cap is the PRD's revised resolution to FR-008's counter-argument.
- **Status:** proposed

### S-08: Read the creature's full journal

- **Outcome:** user opens a dedicated journal screen and reads every narrative prose entry plus its state-change record, in chronological order (FR-011).
- **Change ID:** `read-creature-journal`
- **PRD refs:** FR-011
- **Prerequisites:** S-03
- **Parallel with:** S-04, S-05, S-06
- **Blockers:** —
- **Unknowns:** —
- **Risk:** small slice; the journal entries already exist on disk after S-03 (FR-009 produces them); this slice adds a list view. The PRD's secondary success criterion ("journal feels like a story") is validated here — pacing, formatting, and entry-density choices deserve at-edit-time tuning.
- **Status:** proposed

### S-09: Reset and re-hatch

- **Outcome:** user can wipe their current creature (and its journal) and hatch a fresh one (FR-010).
- **Change ID:** `reset-and-rehatch`
- **PRD refs:** FR-010
- **Prerequisites:** S-02
- **Parallel with:** S-03, S-07
- **Blockers:** —
- **Unknowns:** —
- **Risk:** small slice; just a delete + re-trigger of S-02's hatch path. Scheduled late because no user can reset before they hatch, but content-wise it is trivial.
- **Status:** proposed

## Backlog Handoff

| Roadmap ID | Change ID                              | Suggested issue title                                          | Ready for `/10x-plan` | Notes                                                                        |
| ---------- | -------------------------------------- | -------------------------------------------------------------- | --------------------- | ---------------------------------------------------------------------------- |
| F-01       | `frontend-state-mgmt-routing-scaffold` | Frontend state management + routing scaffold                   | yes                   | No prereqs, no blocking unknowns. Run `/10x-plan frontend-state-mgmt-routing-scaffold`. |
| F-02       | `llm-client-prompt-surface`            | LLM client + prompt-rendering surface (FR-009)                 | yes                   | ORQ-1 resolved 2026-05-26 (last-10 entries; semantic search post-MVP). Plannable now. |
| S-01       | `signed-in-empty-creature-view`        | Signed-in empty-creature view (FR-001)                         | no                    | Needs F-01 done first.                                                       |
| S-02       | `hatch-creature-and-view-stats`        | Hatch creature + view stats (US-01 partial, FR-002, FR-003)    | no                    | Needs S-01. Journal schema is now unblocked (ORQ-1 resolved to last-10).      |
| S-03       | `feed-with-personality-response`       | Feed + personality response + journal (US-01, FR-004, FR-009)  | no                    | NORTH STAR. Needs S-02 + F-02 done first.                                    |
| S-04       | `pet-with-personality-response`        | Pet + personality response (FR-005)                            | no                    | Needs S-03.                                                                  |
| S-05       | `cure-the-creature`                    | Cure interaction (FR-006)                                      | no                    | Needs S-03.                                                                  |
| S-06       | `empty-energy-gate`                    | Empty-energy gate + pre-written responses (FR-007)             | no                    | Needs S-03.                                                                  |
| S-07       | `real-time-stat-decay`                 | Real-time stat decay + energy regen (FR-008)                   | no                    | Needs S-02. Parallel with S-03 chain once S-02 lands.                        |
| S-08       | `read-creature-journal`                | Full journal screen (FR-011)                                   | no                    | Needs S-03.                                                                  |
| S-09       | `reset-and-rehatch`                    | Reset and re-hatch (FR-010)                                    | no                    | Needs S-02.                                                                  |

## Open Roadmap Questions

_None currently open._

- **ORQ-1 — Memory architecture for FR-009.** **Resolved 2026-05-26**: MVP uses the literal **last 10 journal entries** in the LLM prompt (no retrieval). A semantic-search-over-the-full-journal capability is deferred to post-MVP as an AI-callable tool the model can invoke when last-10 is insufficient (see `## Parked`). Closes PRD §Open Questions #3 and #4.

## Parked

- **Semantic-search-as-AI-tool over the full journal.** — Why parked: 2026-05-26 ORQ-1 resolution. MVP ships with the simple last-10-journal-entries prompt strategy. The semantic-search capability is intentionally designed as a *tool the LLM can call when it judges last-10 is insufficient* (agent-style retrieval), rather than as a base prompt-stuffing strategy. Re-open as a follow-on slice once US-01 is validated and a real signal exists on whether deeper continuity is needed. Closes PRD §Open Questions #3 as a deferred enhancement (not a v2 unknown).
- **OAuth sign-in.** — Why parked: PRD §Access Control declares email+password AND OAuth, but the user explicitly chose to defer OAuth during the 2026-05-26 framing interview to keep MVP scope small. Re-open post-launch.
- **No social features.** — Why parked: PRD §Non-Goals #1 — social features require multi-creature infrastructure that doesn't exist yet and dilute the personality hypothesis the MVP is built to prove.
- **No visual evolution or permadeath.** — Why parked: PRD §Non-Goals #2 — long-term mechanics require months of play data to tune; MVP proves personality, not progression.
- **No native mobile apps.** — Why parked: PRD §Non-Goals #3 — web covers the hobbyist audience for validation; native builds are post-validation.
- **No speech synthesis.** — Why parked: PRD §Non-Goals #4 — audio adds a full production pipeline that doesn't prove the personality hypothesis.
- **No multiple creatures per account.** — Why parked: PRD §Non-Goals #5 — dilutes emotional investment and complicates the UI.
- **Stat-display redesign (expressive icons / text vs raw numbers).** — Why parked: PRD §Open Questions #2; PRD itself notes "Resolution: v2". MVP uses raw numbers and accepts the dashboard-feel risk.
- **AI cost-scaling instrumentation and protections.** — Why parked: PRD §Open Questions #5; not a concern at MVP scale (handful of users). FR-007's empty-energy gate (S-06) already caps per-user cost. Revisit if usage grows.

## Done

(Empty on first generation. `/10x-archive` appends entries here — and flips that item's `Status` to `done` — when a change whose `Change ID` matches a roadmap item is archived.)
