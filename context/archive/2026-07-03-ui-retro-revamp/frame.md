# Frame Brief: Retro-game UI revamp

> Framing step before /10x-plan. This document captures what is *actually*
> at issue, separated from what was initially assumed.

## Reported Observation

The app's look-and-feel is stock **Material 3** — default sans-serif (Roboto),
default M3 purple seed palette, rounded/elevated cards and buttons — while the
creature sprites shown inside it are already retro pixel-art. The chrome and the
centerpiece clash: the app reads "generic modern Flutter app," not "retro game."

## Initial Framing (preserved)

- **User's stated cause or approach**: Go retro — a "retro style font, pixels
  everywhere," modelled on the retro feel of the creature images.
- **User's proposed direction**: Restyle the UI to a retro-game aesthetic.
- **Pre-dispatch narrowing**: Scope = **app chrome only** (Flutter-only; sprite
  *generation* stays as-is). Leading pain = **all of it equally** (font, colours
  & shapes, and crisp pixels — no single element dominates). Fidelity = **full
  retro everywhere** — pixel font on *all* text including the journal,
  authenticity chosen over readability.

## Dimension Map

Where "not retro enough" currently originates:

1. **Typography** — no custom font; `pubspec.yaml` fonts block is empty, no
   `fontFamily` set anywhere → default Roboto (`app_widget.dart:15`). ← initial framing
2. **Colour palette / theme** — `ThemeData(useMaterial3: true)` only; default M3
   seed, no custom `ColorScheme` or `textTheme` (`app_widget.dart:15`).
3. **Component chrome** — 100% Material: `ElevatedButton`, `Card`, `AlertDialog`,
   rounded `BorderRadius.circular(8/12)`, elevation/shadows read "modern"
   (`creature_view.dart`, `journal_view.dart`, `hatch_form.dart`).
4. **Pixel-crisp rendering** — `Image.network` with no `FilterQuality.none`, so
   the pixel-art sprite is bilinear-blurred when scaled to 128px
   (`critter_image.dart:31`).
5. **Creature image *generation*** — the implicit assumption that this needs
   retro-ifying. Investigated and ruled out.

## Hypothesis Investigation

| Hypothesis | Evidence | Verdict |
| --- | --- | --- |
| Typography is default/modern | No `fontFamily`, empty fonts block, no committed `.ttf`; default Roboto (`app_widget.dart:15`, `pubspec.yaml`) | STRONG |
| Palette/theme is default M3 | `ThemeData(useMaterial3: true)`, no seed, no custom `ColorScheme`/`textTheme` (`app_widget.dart:15`) | STRONG |
| Component chrome is modern-Material | 100% Material, `MaterialApp.router`; rounded+elevated buttons/cards/dialogs; `shadcn_ui` declared but **never imported** (dead dep) | STRONG |
| Sprite renders soft, not crisp | `Image.network` lacks `filterQuality: FilterQuality.none` (`critter_image.dart:31`) — pixel-art blurs on upscale | STRONG (scope note below) |
| Creature *generation* needs retro-ifying | Gemini prompt already: "Retro 16-bit pixel-art sprite … chunky hard-edged pixels, bold dark outline, small limited palette, solid white bg" (`critter_image_prompt.dart:67-72`) | NONE — already retro |

## Narrowing Signals

- The creature sprites are **already** 16-bit pixel-art — "like creature images"
  is the existing *anchor*, not a target to build. This ruled out the entire
  server-side image pipeline (user confirmed: **chrome only**).
- `shadcn_ui` (`pubspec.yaml:41`, and its Geist font ships in build assets) is a
  **dead dependency** — zero imports in `lib/`. The app is genuinely 100%
  Material, so there is a real, unforced approach choice for the plan.
- Stats (Hunger/Energy/Love/Illness) render as **plain text numbers**, explicitly
  "raw per MVP — no icons/bars" (`creature_view.dart:14,326-346`) — chunky retro
  stat bars would be a *feature add*, not a restyle.

## Cross-System Convention

Retro-game UIs are driven by four levers, all of which this app currently lacks
in its chrome but its sprite spec already embodies: a **bitmap/pixel font**, a
**small limited palette**, **hard-edged flat components** (no rounded corners, no
shadows), and **nearest-neighbour pixel scaling**. The sprite prompt
(`critter_image_prompt.dart:67-72`) is a ready palette/shape anchor — the chrome
can be derived to match it (limited palette, bold dark outline, flat white
ground) rather than invented from scratch. CLAUDE.md sanctions two build paths:
extend Material's `ThemeData`, or "intentionally add shadcn" (already a dep).

## Reframed (or Confirmed) Problem Statement

> **The actual problem to plan around is**: the app *chrome* (typography,
> palette, and component shapes) is stock Material 3 and clashes with the
> already-retro pixel-art sprite — the revamp is a **Flutter-only theming pass**
> to make the chrome match the sprite, **not** a change to how creatures are
> generated.

The initial framing ("retro font, pixels everywhere") is directionally correct
but under-specified in two ways the evidence makes concrete: (1) it implied the
creature imagery might need changing — it does not, it is the reference; and (2)
"pixels everywhere" must include making the *actual pixels* crisp
(`FilterQuality.none`), or the centerpiece stays soft while the chrome goes
retro. Addressed, the whole surface — one bitmap font, a limited palette, flat
hard-edged Material overrides, and nearest-neighbour sprite scaling — reads as a
single coherent retro game.

## Confidence

**HIGH** — every dimension has file:line evidence; the ruled-out dimension
(generation already retro) is directly confirmed at `critter_image_prompt.dart:67`;
the user's scope/fidelity answers are decisive and consistent with the evidence.

## What Changes for /10x-plan

Plan a **Flutter-only** retro theme pass over the 6 chrome surfaces inventoried
below — do **not** touch the server image pipeline. Two decisions are the plan's
to make (frame does not pick them):

- **Build path**: extend Material `ThemeData` (font + `ColorScheme` + shape/
  border/elevation overrides, app stays Material) vs. adopt the already-present
  `shadcn_ui`. Recommendation to weigh, not a mandate: Material `ThemeData`
  override keeps the 100%-Material app intact and touches fewer files.
- **Font choice under "full retro everywhere"**: the user accepted lower
  readability, but the journal is long prose — the plan should still weigh a more
  legible pixel font (e.g. VT323 / Pixelify Sans) over Press Start 2P, or bump
  size/line-height for body text. Font licensing must allow bundling.

Flags for the plan to fold in, not re-litigate:

- **Include the one-line `FilterQuality.none` fix** (`critter_image.dart:31`).
  It is Flutter-only (display, not generation), so it fits "chrome only," and it
  directly serves the "all of it equally / crisp pixels" signal. The user picked
  "app chrome only" over "chrome + sprite display," so call it out — but it is
  cheap and on-theme; default to including it unless the user drops it.
- **Chunky segmented stat bars** are a *scope-expanding feature add* (stats are
  plain text today), not part of the restyle — offer as optional, don't assume.
- **7 Material `Icons.*`** (`home_screen`, `creature_view`, `critter_image`) may
  clash with a pixel aesthetic — restyle/replace is a minor sub-item.

## References

- Theme root: `tamagotchi_flutter/lib/app/app_widget.dart:15`
- Chrome surfaces: `sign_in_screen.dart`, `home/home_screen.dart`,
  `creature/creature_view.dart`, `creature/journal_view.dart`,
  `creature/hatch_form.dart`, `creature/reset_confirm_dialog.dart`,
  `creature/critter_image.dart`
- Sprite anchor (already retro): `tamagotchi_server/lib/src/llm/critter_image_prompt.dart:67-72`
- Fonts: `tamagotchi_flutter/pubspec.yaml` (empty fonts block; no committed `.ttf`)
- Dead dep: `shadcn_ui` at `pubspec.yaml:41` — unused in `lib/`
- Related research: none (`context/changes/ui-retro-revamp/research.md` absent)
