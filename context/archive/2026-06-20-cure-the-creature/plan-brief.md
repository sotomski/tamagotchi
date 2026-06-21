# Cure the Creature (S-05) — Plan Brief

> Full plan: `context/changes/cure-the-creature/plan.md`

## What & Why

Add **Cure** as the third creature interaction (FR-006). The user taps Cure, the creature's illness drops, it responds in-character, and a `cure` journal entry is written. Cure is the "emergency" interaction: **always available regardless of energy**, and it costs no energy. It rounds out the care loop (Feed → Pet → Cure) using the personality + LLM machinery already shipped.

## Starting Point

Feed (S-03) and Pet (the deterministic `play()`, S-04) are shipped. The LLM surface, the deterministic `StatDelta` pattern, the `cureServiceFactory`-style injection seam, the shared `lastInteractionProvider`, and the illness stat display all already exist. `JournalEvent.cure` is **already in the enum**, and illness is already shown in the UI — so this slice is a near-exact mirror of Pet with no migration.

## Desired End State

A creature with `illness > 0` shows an enabled Cure button; tapping it reduces illness (scaled by personality), leaves energy untouched, shows an in-character response, persists a `cure` journal entry, and refreshes stats. When `illness == 0` the button is disabled. The server never reads energy as a precondition for Cure.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Illness at hatch | Keep `illness: 0` | Cleanest data model; Cure stays demonstrable via seeded creatures in tests/fixtures, real illness arrives with S-07 decay | Plan |
| Energy cost of Cure | None (`energyDelta 0`) | Makes "available regardless of energy" trivially true — the genuine emergency interaction | Plan |
| Cure stat math | Fixed base × `illnessDecayMod`, clamped | Mirrors Pet's `round(15 × loveRegenMod)`; keeps Cure character-driven and deterministic | Plan |
| Already-healthy (`illness==0`) | Disable the Cure button (client-side) | Clearest UX; server still processes gracefully (`illnessDelta 0`) so it never depends on the client guard | Plan |
| FR-007 energy gate | No precondition + invariant note for S-06 | Zero speculative work; the gate is S-06's job | Plan |
| Test surface | Full mirror of Pet (unit + integration + widget), no new e2e | Matches the established bar; Feed's e2e already covers persistence | Plan |
| UI | Third button in the existing row, shared response | Consistent with Pet, minimal new UI | Plan |

## Scope

**In scope:** `cure()` endpoint + `CureResult`/`CreatureCureError` models; deterministic `cureDelta` (illness scaled by `illnessDecayMod`, no energy cost); `cure` branch in the prompt builder + stub + `cure_copy.dart`; `CureController` + Cure button (disabled at `illness == 0`); unit + integration + widget tests.

**Out of scope:** hatch illness bootstrap; FR-007 empty-energy gate (S-06); S-07 decay; any migration; new e2e/patrol test; visually distinct Cure styling; LLM client / selection-seam changes.

## Architecture / Approach

Bottom-up mirror of Pet. **Phase 1** (pure domain + LLM cure branch) → **Phase 2** (endpoint + non-table models + `serverpod generate` + integration tests) → **Phase 3** (Flutter controller + button + widget tests). Cure reuses the LLM surface untouched, adding only a `cure` branch in `creature_prompt.dart` and the stub. Stat math is a deterministic `cureDelta(creature, personality)` returning a `StatDelta` with only `illnessDelta` non-zero.

## Phases at a Glance

| Phase | What it delivers | Workflow | Key risk |
| --- | --- | --- | --- |
| 1. Server domain + LLM branch | `cure_service.dart`, `cure_copy.dart`, prompt + stub cure branches, unit tests | `/10x-tdd` | Picking a base relief that feels right across the `illnessDecayMod` range |
| 2. Endpoint + models | `CureResult`/error models, `cure()` endpoint, regen client, integration tests | `/10x-implement` | Forgetting the "no energy precondition" invariant; codegen ordering |
| 3. Flutter client | `CureController`, Cure button (disabled at illness 0), widget tests | `/10x-implement` | Disabled-state wiring; folding cure into shared loading/response plumbing |

**Prerequisites:** S-03 (Feed) + S-04 (Pet) shipped — both done. Compose test Postgres for integration tests.
**Estimated effort:** ~1 session across 3 phases (small, mechanical slice).

## Open Risks & Assumptions

- With illness 0 at hatch **and** Cure disabled at illness 0, a fresh creature always shows Cure greyed out until S-07 (or seeding). Accepted, documented limitation — manual/e2e verification seeds a sick creature.
- The "regardless of energy" bypass is asserted as "no gate present" until S-06 builds the actual gate; an integration test confirms `cure()` works at `energy == 0`.
- Prompt tone for recovery may need a manual iteration to feel distinct from Feed/Pet (the same risk both prior slices flagged).

## Success Criteria (Summary)

- Curing a sick creature reduces illness (scaled by personality), costs no energy, and writes a `cure` journal entry — verified by integration tests.
- Cure works at `energy == 0` and is disabled at `illness == 0` — verified by integration + widget tests.
- The Cure response renders in the shared area and stats refresh — verified by widget tests.
