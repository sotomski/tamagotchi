---
change_id: generate-creature-image
title: Generate creature image
status: implementing
created: 2026-06-28
updated: 2026-06-28
archived_at: null
---

## Notes

<!-- Free-form notes for this change: links, ad-hoc context, decisions that don't belong in research/frame/plan. -->

### Phase 0 probe outcome (2026-06-28)

Ran the throwaway probe (`tamagotchi_server/tool/critter_probe.dart`) against the
real Mistral API across small/medium/large, fixed-seed for apples-to-apples
comparison. Findings that override the plan's original assumptions:

- **Model size is the dominant quality lever, not canvas size.** `mistral-small-2603`
  (the text model) produces noise/blobs/dither at 32×32 (1/10 clean). `mistral-large-latest`
  produces clean, centred, non-degenerate critters at the same 32×32 (fill 39–57%).
  "Fall back to 16×16" was solving the wrong variable.
- **The left-half mirror protocol is unreliable on every model** — they draw a
  complete centred creature filling the whole grid, not a true half, so mirroring
  it would seam/double the body.

**Decisions (supersede the plan where they conflict):**

1. Image generation uses **`mistral-large-latest`**, NOT the narrative model's
   `mistral-small-2603`. (Higher per-birth cost/latency accepted; hatch makes two
   blocking calls now.)
2. **Size stays 32×32.**
3. **Drop left-half emission and code-side mirroring** — the model emits the FULL
   `size×size` grid and we **accept its output as-is** (`mirror` semantics removed
   from the contract). Symmetry is whatever the model draws.
4. Validator pad/truncate repair still earns its keep: large drifts ±1 row/column
   (`{32,31}`, 33 rows, etc.) — cosmetically invisible once normalised.

Knock-on edits needed in Phases 1/3/4: `CritterSpec` drops the left-half/mirror
meaning (a `size×size` full grid; `mirror` field optional/removed); the image-gen
service + prompt target the full grid and pin `large`; the probe is throwaway
(delete or gitignore before merge).
