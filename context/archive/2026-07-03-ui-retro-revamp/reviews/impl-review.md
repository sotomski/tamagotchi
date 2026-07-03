<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Retro-game UI Revamp

- **Plan**: context/changes/ui-retro-revamp/plan.md
- **Scope**: Full plan (Phases 1–5, all complete)
- **Date**: 2026-07-03
- **Verdict**: APPROVED
- **Findings**: 0 critical, 1 warning, 4 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | PASS |
| Architecture | PASS |
| Pattern Consistency | WARNING |
| Success Criteria | PASS |

Highlights: all 14 planned changes MATCH. The load-bearing client↔server colour
coupling is exact — `retroScreenColor = Color(0xFF0E1712)` and the prompt pins
`#0E1712`, byte-for-byte, with reciprocal source-of-truth comments on both sides.
Blend surface correct (scaffold paints `retroScreenColor`; `CreatureView` paints
no background). All six "What We're NOT Doing" guardrails held. Stat-number
invariant preserved. Every automated gate green (flutter analyze/format/test 78;
server analyze/format/test 173; web build ✓).

## Findings

### F1 — Sprite loader is still the round Material spinner

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: tamagotchi_flutter/lib/creature/critter_image.dart:38-42
- **Detail**: The unplanned `RetroLoader` was swapped in across the four other
  loading states (home, journal, hatch, interaction), and its own doc says it
  "Replaces Material's round CircularProgressIndicator across the app." But
  `CritterImage`'s `loadingBuilder` still shows a round `CircularProgressIndicator`
  — the one round modern spinner left against the square retro chrome (it tints
  phosphor via the theme).
- **Fix**: Replace the `loadingBuilder`'s `CircularProgressIndicator` with a
  `RetroLoader` for consistency (or leave it and drop the "across the app" claim
  in `retro_loader.dart`'s doc if the exception is intended).
- **Decision**: FIXED — swapped to `const Center(child: RetroLoader())` (critter_image.dart:38-40)

### F2 — Rounded corners survive the "every corner is square" theme

- **Severity**: 🔭 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: tamagotchi_flutter/lib/creature/creature_view.dart:272-274, 309-313 (+ journal delta chips)
- **Detail**: The interaction-response bubbles and journal delta chips hardcode
  `BorderRadius.circular(12)` locally, so they keep rounded corners even though
  `retro_theme.dart:44` declares "every corner in the app is square." Pre-existing;
  the theme override can't reach a hardcoded local radius. May be an intentional
  talk-bubble affordance.
- **Fix**: If strict square-ness is wanted, swap these to `BorderRadius.zero`.
- **Decision**: FIXED (differently) — replaced `BorderRadius.circular` with zero radius + the theme's 2px `colorScheme.outline` border on both response bubbles (creature_view.dart:272-275, 309-314) and the journal delta chip (journal_view.dart:284-288), matching `_squareShape`.

### F3 — Edge-input guards in the new widgets are order/zero-fragile (unreachable)

- **Severity**: 🔭 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality (Reliability)
- **Location**: tamagotchi_flutter/lib/creature/retro_stat_bar.dart:33-34, tamagotchi_flutter/lib/app/retro_loader.dart:62
- **Detail**: `retro_stat_bar` clamps `value` BEFORE the `max<=0` guard, so a
  negative `max` would trip a debug assert; `retro_loader`'s `% blockCount`
  divides by zero if `blockCount==0`. Both inputs are unreachable in-app (max is
  always 100; blockCount default 4), so this is defensive-only.
- **Fix**: None required; optionally document the `max>0` / `blockCount>0`
  preconditions.
- **Decision**: FIXED — folded the clamp inside the `max<=0` guard (retro_stat_bar.dart:32-36); added `assert(blockCount > 0)` to RetroLoader (retro_loader.dart:18).

### F4 — Theme rebuilt on every AppWidget build

- **Severity**: 🔭 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality (Performance)
- **Location**: tamagotchi_flutter/lib/app/app_widget.dart:16
- **Detail**: `buildRetroTheme()` is called inside `build()`, reconstructing a full
  `ThemeData` each rebuild. Rebuilds are rare (only the router provider changes),
  so impact is negligible.
- **Fix**: Optionally hoist to a top-level `final` ThemeData.
- **Decision**: FIXED — hoisted to a top-level `final ThemeData _retroTheme = buildRetroTheme();`, built once (app_widget.dart:7-9, 18).

### F5 — Unplanned RetroLoader widget + polish tweaks (benign)

- **Severity**: 🔭 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: tamagotchi_flutter/lib/app/retro_loader.dart (+test), tamagotchi_flutter/lib/creature/journal_view.dart, tamagotchi_flutter/lib/creature/hatch_form.dart, tamagotchi_flutter/lib/home/home_screen.dart
- **Detail**: A `RetroLoader` widget (swapped for `CircularProgressIndicator`) and
  the two review-driven polish tweaks (hatch field width, AppBar `actionsPadding`)
  were not in the plan's Changes Required. All are in-spirit theme consistency /
  user-requested polish, committed transparently — no guardrail crossed.
- **Fix**: None; recorded for the audit trail.
- **Decision**: ACCEPTED — benign, in-scope-spirit extras; no action.
