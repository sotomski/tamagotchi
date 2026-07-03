# Retro-game UI Revamp — Plan Brief

> Full plan: `context/changes/ui-retro-revamp/plan.md`
> Frame brief: `context/changes/ui-retro-revamp/frame.md`

## What & Why

The creature sprites are already retro 16-bit pixel-art, but the app chrome around
them is stock Material 3 — the two clash and the app reads "generic modern Flutter
app," not "retro game." We restyle the chrome to match the sprite: a pixel font,
a dark CRT/LCD palette, flat hard-edged larger controls, segmented stat bars, an
adaptive desktop/mobile layout, and a bigger/crisper sprite — plus one server
prompt tweak so new sprites are born on a dark background that blends in.

## Starting Point

The entire theme is one line (`ThemeData(useMaterial3: true)` at
`app_widget.dart:15`) — default palette, no custom font, 100% Material. Home is a
fixed side-by-side `Row` (no responsive breakpoint), stats are plain text numbers,
the sprite renders at 128px unfiltered, and the Gemini birth-prompt pins a pure
white sprite background.

## Desired End State

Desktop or phone shows a coherent dark retro game: VT323 type everywhere, a
limited dark palette, flat larger buttons/panels, stats as chunky segmented bars
(with their numbers), the creature shown large (256px) and crisp on a dark screen
it blends into. Narrow windows split Creature/Journal into tabs; wide windows keep
them side-by-side. New creatures are born on the dark background.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Scope | Chrome only… then +server prompt | Sprites are already retro; but the white-bg constraint made the user opt into a prompt change | Frame / Plan |
| Build mechanism | Material `ThemeData` factory | Minimal per-file diff, central + testable, breaks no existing tests | Plan |
| Font | VT323 (bundled OFL) | Retro-computer look that stays readable for long journal prose under "full retro everywhere" | Plan |
| Palette | Dark CRT/LCD + one accent | Most "retro game", high contrast, pairs with VT323 | Plan |
| Sprite background | Solid dark bg via prompt, keep JPEG | Just a prompt+test edit — no PNG/storage/stub plumbing or model alpha risk | Plan |
| Stats | Segmented bar + keep the number | Iconic retro element; keeping the number leaves ~15 widget + 2 e2e finders green | Plan |
| Sprite render | 256px + `FilterQuality.none` | Bigger + crisp; 256 cuts the downscale 8×→4× to limit aliasing | Plan |
| Mobile layout | Tabs (Creature/Journal) | Both panes stay fully usable on a phone; wide keeps two-pane | Plan |

## Scope

**In scope:** VT323 font asset; `buildRetroTheme()` (palette, font, flat shapes,
larger controls); `RetroStatBar`; adaptive home layout (tabs↔two-pane); 256px +
crisp sprite; server prompt dark background + its test.

**Out of scope:** PNG/transparency; regenerating existing sprites; shadcn adoption;
pixel-icon replacement; CRT scanline overlays; the external sign-in widget internals.

## Architecture / Approach

Material `ThemeData` factory is the spine — one `buildRetroTheme()` at
`app_widget.dart:15` restyles all six chrome surfaces at once. On top: three
focused client changes (stat bars, adaptive layout, sprite size/filter) and one
server change (prompt background). Phase 1 defines a single shared "screen" colour
constant that Phase 5's server prompt mirrors (duplicated hex, no shared code).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Retro theme foundation | Whole app: dark CRT + VT323 + flat larger controls | Material defaults (ripple/rounding) need explicit override |
| 2. Retro segmented stat bars | Stats as chunky bars + numbers | Must keep numeric text findable (test/e2e finders) |
| 3. Adaptive desktop/mobile | Tabs on phone, two-pane on desktop | Two scrollables + overflow at narrow widths |
| 4. Bigger, crisper sprite | 256px + nearest-neighbour | Downscale can alias — manual spot-check |
| 5. Dark sprite background | New sprites blend into chrome | Shared hex must match; dark outline low-contrast on dark |

**Prerequisites:** download VT323 OFL TTF + OFL licence; a real `geminiApiKey`
(dev) to visually verify Phase 5. Phase 1 precedes all (defines the shared colour).
**Estimated effort:** ~2–3 sessions across 5 small phases.

## Open Risks & Assumptions

- Shared screen-colour hex is duplicated across client theme and server prompt — drift shows as a sprite halo.
- `FilterQuality.none` on an 8×/4× downscale may alias; the 256px size is the mitigation, but it needs a human look.
- A dark sprite background dims the sprite's dark outline — relies on bright creature bodies for contrast; lighten the screen colour if it reads poorly.
- Existing creatures keep white-background sprites until reset+re-hatch (accepted for MVP).
- "Full retro everywhere" puts VT323 on the journal; if prose readability disappoints, revisit size/line-height (not font).

## Success Criteria (Summary)

- App reads as a coherent dark retro game (font + palette + flat larger controls) on both desktop and phone, with no layout overflow.
- Stats render as segmented bars while all existing stat-number tests/e2e stay green.
- A newly-hatched creature appears large, crisp, and blended on the dark background; existing creatures still render.
