---
change_id: cure-the-creature
title: Cure the creature when sick, regardless of energy
status: planned
created: 2026-06-20
updated: 2026-06-20
archived_at: null
---

## Notes

Seeded from `context/foundation/roadmap.md` → **S-05** (`cure-the-creature`).

- **Outcome:** user Cures the creature; illness drops; Cure works regardless of energy level (FR-006); creature response acknowledges the cure; journal gains an entry.
- **PRD ref:** FR-006.
- **Prerequisites:** S-03 (`feed-with-personality-response`) — **shipped (PR #9)**. Reuses S-03's `LlmService` + prompt surface.
- **Parallel with:** S-04, S-06, S-08.
- **Open unknown (decide at `/10x-plan` time):** For Cure to be testable, illness must be non-zero. Either bootstrap illness at hatch, or wait for the decay slice (S-07) to raise it over time. Roadmap note: bootstrap-at-hatch is the cheaper testing path.
- **Risk:** small, mostly-mechanical slice; the FR-006 "always available regardless of energy" rule is mechanical. User-visible distinctiveness from Feed/Pet relies on prompt design (covered by the existing LLM surface).
