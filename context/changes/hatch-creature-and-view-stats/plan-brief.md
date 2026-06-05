# Hatch a creature and view its stats (S-02) — Plan Brief

> Full plan: `context/changes/hatch-creature-and-view-stats/plan.md`
> Frame brief: `context/changes/hatch-creature-and-view-stats/frame.md`
> Research: `context/changes/hatch-creature-and-view-stats/research.md`

## What & Why

S-02 lets a logged-in user **hatch one creature and view its stats + mood**. It is
the first first-party persisted slice, and the roadmap flags its risk as *"it fixes
the data model for creature + journal"* — the schema laid down here is load-bearing
for S-03–S-09. The frame settled the shape: lay down a forward-compatible persisted
trait model and a deterministic, stats-only, derived-on-read mood — **not** a live
trait↔stat↔mood engine.

## Starting Point

S-01 delivered the auth vertical slice: a route-guarded `/` home (`ConsumerWidget`)
showing "No creature yet" with no Hatch button, the `serverpodClientProvider`, and a
widget-test harness. No first-party DB table, endpoint, or async provider exists
yet — the only `.spy.yaml` has its `table:` commented out.

## Desired End State

A signed-in user with no creature sees a name field + **Hatch** button. Hatching
creates the creature (baseline stats, random personality modifiers), writes a
"hatched" journal marker, and shows the stats view: name, four raw stat numbers
(0–100), and a derived mood (`content` at birth). The creature persists across
reloads; a second hatch is rejected.

## Key Decisions Made

| Decision | Choice | Why | Source |
| --- | --- | --- | --- |
| Personality model | Per-stat decay/regen modifiers (4 stats × 2 = 8 doubles), **separate 1:1 table**, inert at S-02 | User wants traits expressed as stat-change modifiers; clean separation, room to grow | Plan (refines Frame) |
| Modifier scope | Decay/regen only — interaction mods (picky/extravert) deferred to S-03/S-04 | Stays in the frame's deferral boundary; later additions are additive | Plan |
| Stats | 0–100 int; hatch baseline hunger 0 / energy 100 / love 50 / illness 0 | Conventional scale; leaves headroom for the S-07 floor; yields a clear newborn mood | Plan |
| Mood | Enum {happy, content, sad, sick}, derived-on-read; illness-priority then worst-stat (thresholds 50/25/55) | Human-readable, pure, deterministic; un-stored = consistent through S-07 decay | Plan |
| Journal | Table defined now + a non-narrative "hatched" marker written at hatch | Roadmap requires the schema now; marker exercises the write path; prose deferred to S-03 | Plan |
| Naming | Required name at hatch — `hatch(session, name)` | Core to the genre; drives attachment; matches research's example signature | Plan |
| Owner scoping | `ownerUuid` scalar + unique index | Mirrors how auth stores `authUserId`; no `modules:` nickname exists for FK shorthand | Research |
| Mood location | Pure fn in `creature_service.dart`, returned via a `CreatureStatus` DTO | Determinism guardrail; isolates RNG; keeps mood un-stored | Frame/Research |

## Scope

**In scope:** creature + personality(1:1) + journal tables, two enums, a
`CreatureStatus` DTO, `hatch`/`myCreature` endpoint, pure mood function, randomized
modifiers, hatched journal marker, Flutter async provider + hatch action + stats
view + empty state, backend + Flutter tests.

**Out of scope:** decay/regen logic (S-07), AI responses + narrative journal (S-03),
Feed/Pet/Cure + interaction modifiers (S-03–S-05), mood icons, reset/re-hatch (S-09),
journal reading screen (S-08), trait-roll constraints, journal vector column.

## Architecture / Approach

Server-first so `serverpod generate` produces the RPC client before Flutter
compiles. Three tables (creature, personality 1:1, journal) + two enums + a
non-table DTO bundling creature with computed mood. Thin endpoint; pure mood +
randomized seeding in `creature_service.dart`. One-creature-per-user enforced by an
app pre-check **and** a DB unique index (race-safe backstop), with the three inserts
in one transaction. Flutter establishes the `AsyncValue.when` +
provider-override-in-tests pattern later slices reuse; both empty and stats states
live under `/`.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Backend model & migration | 3 tables, 2 enums, DTO, applied migration | First first-party migration — schema must be forward-compatible |
| 2. Backend service, endpoint & tests | Pure mood fn, hatch/view endpoint, RPC client, tests | Mood oracle correctness; race-safe one-per-user |
| 3. Flutter provider, action & UI | Async provider, hatch flow, stats + empty states | First async surface; home rewire breaks S-01 assertions |
| 4. Flutter tests & S-01 updates | Updated home test + creature-view tests + cookbook | Hermetic overrides instead of RPC round-trips |

**Prerequisites:** S-01 (auth slice) merged; local Postgres sidecar (`docker compose up -d`).
**Estimated effort:** ~3–4 sessions across 4 phases.

## Open Risks & Assumptions

- Mood thresholds (50/25/55) are a design choice, not source-derived — tune if
  play-testing surfaces odd labels.
- Modifier randomization range (0.5–1.5) is a default; inert at S-02, so low risk.
- The 1:1 personality table adds a join now for data nothing reads yet — accepted
  for cleaner separation and AI-generation-friendliness later.

## Success Criteria (Summary)

- A user can hatch a named creature and immediately see four stats + a `content`
  mood; it persists across reloads.
- A second hatch attempt is rejected; the journal holds one `hatched` marker.
- Mood is deterministic and unit-tested; the one-per-user invariant is
  integration-tested against a real DB.
