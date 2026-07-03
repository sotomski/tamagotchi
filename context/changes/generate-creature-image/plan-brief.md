# Generated Creature Image at Birth — Plan Brief

> Full plan: `context/changes/generate-creature-image/plan.md`
> Frame brief: `context/changes/generate-creature-image/frame.md`
> Research: `context/changes/generate-creature-image/research.md`

## What & Why

When a creature is born, the server generates a unique retro pixel-art body for
it via Mistral, persists it, and the Flutter client renders it crisp. Per the
frame: render a **static** generated pixel creature at birth — the real work is
shrinking the payload to what a static graphic needs, deciding the birth-path
failure posture, and following existing conventions; "can Mistral draw" is
bounded (lower bar + swappable model).

## Starting Point

Hatch already makes a **blocking, no-fallback** narrative LLM call before its
insert transaction, behind a `…ServiceFactory` seam with a hermetic stub; complex
data persists as typed models in `json` columns; and `CreatureStatus` already
carries the `Creature` to the client. The client has **no** pixel/canvas
rendering yet, and personality is stored as 7 raw decay/regen mods (not named
axes).

## Desired End State

Hatching a creature shows a unique, symmetrical pixel critter rendered crisp at
128px, its look loosely informed by personality. If generation fails or can't be
repaired, the hatch fails cleanly (nothing persisted) — same contract as the
narrative call. Pre-existing creatures render fine with no sprite.

## Key Decisions Made

| Decision | Choice | Why | Source |
| --- | --- | --- | --- |
| Storage column | Typed `CritterSpec` → `json` (not `jsonb`) | Serverpod 3.4.8 cannot emit `jsonb`; typed model is the convention | Research |
| Scope | Static birth graphic only | Frame narrowed it; animations/typography deferred | Frame |
| Birth-path posture | **Block hatch**, no fallback | Consistent with existing narrative call; every creature unique or none | Plan |
| Payload | Single **mirrored 32×32** grid, neutral face baked in | Smallest still-symmetric payload; user override of brief's 16×16 | Plan |
| Personality | Personality-informed prompt (mods→hints) | Matches the "Charakter" pillar | Plan |
| Attempt budget | Validate + auto-repair, **no reprompt** | One round-trip; keeps birth latency down | Plan |
| Canvas size | 32×32 (configurable `size`) | User chose detail over the brief's reliability argument | Plan |
| Render | Pure Flutter `CustomPainter` | One critter; Flame deferred | Frame |

## Scope

**In scope:** typed `CritterSpec` + nullable `Creature.image`; validator +
auto-repair; Mistral generation service (stub + real, factory seam); mods→hints
mapping; `CustomPainter` render path in `CreatureView`; blocking wire-in at hatch.

**Out of scope:** reaction animations, motion/particle presets, typography
(Pixelify Sans), Flame, reprompt loop, default-template fallback, async
generation, `jsonb`, personality-storage refactor.

## Architecture / Approach

Contract-first: define `CritterSpec` + validator → build the client render path
against a hand-written spec → build the server generation service behind a
factory seam with a hermetic stub → wire the blocking call into hatch. The image
is a nullable typed field on `Creature` that auto-surfaces through
`CreatureStatus` to `creatureProvider` after `serverpod generate`. Generation
mirrors the existing `MistralLlmService` structured-output pattern.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 0. Probe | Throwaway: confirm mistral-small draws 32×16 reliably | Model weak at 32× → revisit size/model |
| 1. Model + validator | `CritterSpec`, nullable `Creature.image`, migration, validator+repair | Serverpod codegen/migration friction |
| 2. Render path | Compositor + `CustomPainter`, hand-written spec renders crisp | First canvas code in the app; mirror geometry |
| 3. Generation | `CritterImageService` (stub+real), prompt, mods→hints | Structured output drift at 32× |
| 4. Wire-in | Blocking gen at hatch, persist, end-to-end + tests | Two blocking calls → birth latency/failure |

**Prerequisites:** dev `mistralApiKey` for the probe + manual checks; Serverpod
codegen toolchain.
**Estimated effort:** ~4–5 sessions across 5 phases.

## Open Risks & Assumptions

- **32×32 overrides the brief's explicit reliability warning** (16×16 is "markedly
  more reliable for an LLM"). With block-hatch/no-fallback, weak generation =
  failed births. Mitigation: Phase 0 probe; `size` is one value to change;
  swappable model.
- Hatch now makes **two** sequential blocking external calls — higher latency and
  failure probability; consider adding timeouts (none exist today).
- Generation quality at the "varied & colorful" bar is assumed, not yet verified
  (Phase 0 closes this).
- Personality→visual-hints mapping is new and its payoff is fuzzy at the chosen
  quality bar.

## Success Criteria (Summary)

- A new creature shows a unique, crisp, symmetrical critter at birth; a second
  hatch looks different.
- Generation failure blocks the hatch with no half-written creature.
- Pre-existing (null-image) creatures render without a layout break.
