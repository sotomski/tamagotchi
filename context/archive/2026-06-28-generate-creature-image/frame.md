# Frame Brief: Generated creature image at birth

> Framing step before /10x-plan. This document captures what is *actually*
> at issue, separated from what was initially assumed.

## Reported Observation

When a creature is born (hatch), the user should see a unique, retro pixel-art
creature graphic on screen.

## Initial Framing (preserved)

- **User's stated cause or approach**: Have Mistral *draw* the creature — emit a
  16×16 mirrored char-grid + expression patches as JSON, validate/repair, store
  as a JSONB column, render in Flutter — bundled with a 5-reaction animation
  engine, motion/particle presets, personality modulation, and Pixelify Sans
  typography (the full §1–§16 brief).
- **User's proposed direction**: Build the whole brief as one server-generated
  feature at the birth endpoint.
- **Pre-dispatch narrowing**: Scope = **just the static birth graphic** (not the
  animation engine, not typography). Quality bar = **"varied & colorful is
  fine"** (an abstract shape is acceptable; recognizability is *not* required).
  Evidence that mistral-small can draw = **assumed, not tested** — "we can always
  switch to a larger model if this one produces weak results."

## Dimension Map

The observation could originate / break at any of these dimensions:

1. **Generation quality** — can mistral-small produce *varied, non-degenerate*
   char-grids? ← brief treats "yes" as settled; this is the only empirical unknown
2. **Scope shape** — "a graphic at birth" vs an animation+typography engine ← initial framing bundled them
3. **Generation input (personality vector)** — the brief feeds named 0.0–1.0 axes to the generator
4. **Birth-path coupling** — where image gen hooks into hatch, and what happens on failure/latency
5. **Storage** — "JSONB column" vs the project's typed-model convention
6. **Render surface** — Flutter has no pixel/canvas rendering today

## Hypothesis Investigation

| Hypothesis | Evidence | Verdict |
| --- | --- | --- |
| Animation engine + typography (§4–§6, §12) are the real bulk and are *not* this slice | User scoped to "just the static birth graphic"; §4's faceless-base + expression-patches + face-box + reactions table + motion/particle enums exist solely to enable animation reuse — a static graphic needs only base body + one neutral face composited to one image | **STRONG** |
| The brief's "personality vector" generation input does not exist | `creature_personality.spy.yaml` + `creature_service.dart:53-67` store **7 raw decay/regen multipliers in [0.5,1.5)**; no named 0.0–1.0 axes anywhere; `creature_prompt.dart:262-268` passes raw mods to the LLM, not axes. The named axes would have to be *built* | **STRONG** |
| Hatch already blocks on a no-fallback Mistral call; image gen adds a second one | `creature_endpoint.dart:49-70` — birth narrative is a **blocking pre-transaction LLM call with deliberately NO canned fallback** ("hatch blocks on failure"); no timeout/retry (`mistral_client.dart:95-137`). A second blocking gen call doubles the birth failure/latency surface | **STRONG** |
| "JSONB column" cuts against the storage convention | Project stores complex data as **typed nested serializable models** auto-mapped to a `json` column (e.g. `StatDelta` on `journal_entry.spy.yaml:21` → `"statDelta" json`). Free-form JSONB exists nowhere | **STRONG** (minor) |
| Render path is genuinely new but isolated | No `CustomPainter`/canvas/pixel rendering anywhere (`creature_view.dart` is text/stat-only); `creatureProvider` already fetches the creature — add a field + regenerate client | **STRONG** |
| mistral-small cannot draw well enough | Not testable in this env (no key); **bar lowered to "varied & colorful"** and **model is swappable**, so this is bounded, not fatal | **WEAK / bounded** |

## Narrowing Signals

- "Just the static birth graphic" → the animation/particle/motion/personality-
  modulation/typography machinery (most of the brief's surface) is out of this slice.
- "Varied & colorful is fine" → structural validation (§8) is *sufficient*; the
  recategorized risk is "degenerate/near-identical blobs," not "doesn't look like
  a creature." Variety can come from a **seed**, so personality-as-input isn't
  required for v1.
- "Assumed, can swap models" → generation quality is a de-risk-by-probe, not a
  blocking premise.

## Cross-System Convention

This project already has the *exact* pattern a server-side generator should
follow: an `LlmService` behind a single factory seam (`llmServiceFor` /
`hatchLlmServiceFactory`, `creature_endpoint.dart:702`), a hermetic
`StubLlmService` selected by key-presence, an `e2e` runmode, and complex data
persisted as typed models serialized to a `json` column. The generated-image
feature should reuse all of this — *not* introduce free-form JSONB or a new
ad-hoc client.

## Reframed (or Confirmed) Problem Statement

> **The actual problem to plan around is**: render a *static* generated pixel
> creature at birth — where the real decisions are (a) shrink the generated
> payload to what a static graphic needs (base + one neutral face, seed-driven
> variety), (b) decide the **birth-path failure/latency posture** for a second
> external call, and (c) follow the project's typed-model + factory-seam +
> stub conventions — *not* "can Mistral draw," which the user has already
> bounded (lower bar + model swap).

The initial framing wasn't *wrong* — the brief is a sound design for the full
**animated** feature. But for THIS slice it is over-scoped, and it rests on two
inputs that don't exist as assumed: a named personality vector (reality: raw
mods) and a free-form JSONB column (convention: typed model → `json` column).
Meanwhile the one genuinely load-bearing decision — does image gen **block
hatch** (consistent with today's no-fallback narrative call, but now two LLM
calls can fail a birth), **degrade to a default/template critter** (the brief's
§8 fallback, which hatch deliberately does *not* do today), or **generate async
after birth** — is buried in §16 "open questions" while the existing hatch flow
forces the choice. That decision, plus payload-minimization, is what /10x-plan
should center on.

## Confidence

**HIGH** — every structural claim has file:line evidence and the scope/quality
bars are settled by the user. One item is empirically unverified
(generation quality), but the user has explicitly bounded it. Recommended
(non-blocking) de-risk before building the full pipeline: a small generation
**probe** — N seeds against mistral-small (and one larger model), eyeball for
"varied & non-degenerate." If small is weak, swap the model; the pipeline is
unaffected.

## What Changes for /10x-plan

Plan a **static-only** birth-image slice that: minimizes the generated payload
(base + neutral face, seed-driven variety; defer expression patches / reactions /
personality modulation); reuses the `LlmService` factory-seam + stub +
key-presence pattern; persists via a **typed nested model → `json` column** (not
JSONB); adds an isolated Flutter `CustomPainter` render path off the existing
`creatureProvider`; and **explicitly decides the birth-path failure/latency
posture** (block vs default-template fallback vs async-after-birth) rather than
deferring it. Open the plan with the generation probe as step 0.

## References

- Source files: `creature_endpoint.dart:28-139,702`, `creature_service.dart:53-67`,
  `creature_personality.spy.yaml:4-7`, `creature_prompt.dart:262-268`,
  `mistral_client.dart:95-137`, `llm_service.dart:96-113`,
  `journal_entry.spy.yaml:21`, `creature_view.dart:26-180`,
  `creature_provider.dart:15-22`
- Related research: none yet (`context/changes/generate-creature-image/`)
- Investigation: 3 parallel Explore agents (hatch coupling, personality model, render+storage)
