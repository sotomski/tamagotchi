# Real-Time Stat Decay & Energy Regen — Plan Brief

> Full plan: `context/changes/real-time-stat-decay/plan.md`
> Research: `context/changes/real-time-stat-decay/research.md`

## What & Why

Implement FR-008 (roadmap S-07): creature stats change in real time at
personality-driven rates — including while the user is away — never dropping
below a minimum floor, with energy regenerating in real time. This is the
mechanical backbone behind "the creature feels alive": come back later and it's
hungrier, lonelier, and rested.

## Starting Point

The personality dials (`*DecayMod`/`*RegenMod`) already exist, mood is already
"derived on read," and there's one clamp helper for all stat math. What's missing:
a decay anchor timestamp, any wall-clock/time-dependence in the domain, a clock
seam, and any frontend refresh-on-return (`creatureProvider` only re-fetches
after an interaction).

## Desired End State

Whenever the creature is observed, its stats reflect elapsed time (hunger↑,
energy↑ toward 100, love↓ to a floor, illness unchanged), scaled by personality.
A 1×–8× time-acceleration slider lets the user speed up both how fast stats decay
on the server and how often the display refreshes, making decay observable in a
demo without waiting hours.

## Key Decisions Made

| Decision               | Choice                                                        | Why (1 sentence)                                                              | Source |
| ---------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------- | ------ |
| Architecture           | Lazy-on-read (no FutureCall)                                  | Reuses derive-on-read + clamp + a clock seam; deterministic, zero new infra. | Plan   |
| Time control           | Client `timeScale` slider 1×–8×, per-call param (clamped server-side) | Makes decay demoable; scales both server decay and refresh cadence.          | Plan   |
| Rate model             | Quantized **10-minute decay ticks**, integer per-tick deltas | Eliminates fast-poll decay-starvation and per-read rounding drift.           | Plan   |
| Love decay             | `LOVE_PER_TICK × (2 − loveRegenMod)`, floored at 20          | Personality-driven without inventing a `loveDecayMod` field.                 | Plan   |
| Illness drift          | None (Cure only)                                             | Avoids compounding the "punishing return" the PRD deliberately capped.       | Plan   |
| Floor                  | Soft floor on love (20); energy regens to 100; clamp elsewhere | Honors FR-008's floor on the one stat that decays toward zero.               | Plan   |
| Frontend refresh       | Scaled poll timer (`10/timeScale` min) + keep interaction invalidate | Refresh cadence visibly tracks the slider; no regression to instant updates. | Plan   |
| Journal on decay       | No                                                            | Avoids log spam; journal stays interaction-only.                             | Plan   |

## Scope

**In scope:** `lastDecayedAt` migration; clock factory-seam; pure tick-based
decay fn; decay in `myCreature` + before feed/play/cure; `timeScale` params; client
slider + scaled poll timer; unit/integration/widget tests.

**Out of scope:** FutureCall/background scheduler; passive illness drift; a
`loveDecayMod` field; decay journal entries; stats-as-doubles; persisting
`timeScale` server-side; expressive stat-display redesign.

## Architecture / Approach

Pure decay function quantized into 10-game-minute ticks: `effElapsed =
realElapsed × timeScale`, `ticks = floor(effElapsed / 10)`. Apply `ticks` worth
of per-stat deltas via `clampStat`/love-floor; advance `lastDecayedAt` only by
the real time the whole ticks consumed (sub-tick remainder carries over — the
starvation guard). Clock injected via a `clockFactory` seam (mirrors
`feedServiceFactory`). Endpoints take a clamped `timeScale`; the Flutter client
owns the slider and a `Timer.periodic` invalidating `creatureProvider` every
`10/timeScale` minutes.

## Phases at a Glance

| Phase                          | Workflow          | What it delivers                                  | Key risk                                            |
| ------------------------------ | ----------------- | ------------------------------------------------- | --------------------------------------------------- |
| 1. Decay anchor + migration    | `/10x-implement`  | `lastDecayedAt` on `Creature`, migrated           | Migration/generate cycle; backfill of existing rows |
| 2. Server decay engine (read)  | `/10x-tdd`        | Clock seam + pure tick decay in `myCreature`      | Anchor/tick math correctness (starvation guard)     |
| 3. Decay-before-interaction    | `/10x-tdd`        | Decay folded into feed/play/cure transactions     | Preserving atomicity + feed RNG draw-order contract |
| 4. Frontend slider + polling   | `/10x-implement`  | 1×–8× slider, scaled poll timer, `timeScale` wired | Timer lifecycle in Riverpod; cadence scaling tests  |

**Prerequisites:** S-02 (creature exists); interaction slices (feed/play/cure)
landed. Local Postgres sidecars up; `serverpod generate` available.
**Estimated effort:** ~3–4 sessions across 4 phases.

## Open Risks & Assumptions

- Starting per-tick constants (`HUNGER_PER_TICK=2`, etc.) are guesses to tune by
  playtest — chosen so 1× is gentle and the slider makes change observable.
- Changing `timeScale` mid-interval re-scales only the unconsumed remainder;
  acceptable for a demo control, not a precise simulation.
- Assumes Serverpod stores/compares `DateTime` in UTC (seam uses `toUtc()`).

## Success Criteria (Summary)

- Returning to an idle creature shows personality-scaled decay (hunger↑, energy↑,
  love↓ floored at 20, illness flat) — deterministic given inputs.
- The 1×–8× slider visibly scales both decay speed and refresh frequency.
- No journal spam from decay; interactions still update instantly.
