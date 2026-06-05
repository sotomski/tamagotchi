---
change_id: hatch-creature-and-view-stats
title: Hatch a creature and view its stats
status: implemented
created: 2026-06-05
updated: 2026-06-05
archived_at: null
---

## Notes

S-02 from context/foundation/roadmap.md

Outcome: user can hatch one creature (randomized personality traits as continuous
values) and see hunger / energy / love / illness plus a derived mood. Stats are
mechanical at this point — no AI involved yet.

- PRD refs: US-01 (partial — the "hatch" half), FR-002, FR-003
- Prerequisites: S-01 (signed-in-empty-creature-view)
- Unknowns: trait constraint guardrails — should personality randomization have
  constraints to prevent degenerate combos (all-max, all-min)? (PRD §Open Questions #1;
  acknowledged risk for MVP, tune if play-testing surfaces unplayable creatures.)
- Risk: this slice fixes the data model for creature + journal. Journal model is a
  plain timestamp + narrative-prose + state-change record — no vector column at hatch
  time (ORQ-1 resolved to last-10 narrative entries, semantic search as future AI tool).
