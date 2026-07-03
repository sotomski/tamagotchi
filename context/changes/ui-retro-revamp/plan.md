# Retro-game UI Revamp Implementation Plan

## Overview

Restyle the AI-Tamagotchi Flutter web app from stock Material 3 into a retro
CRT/LCD "game" aesthetic: a bundled pixel font (VT323), a dark limited palette,
flat hard-edged components with larger controls, chunky segmented stat bars, an
adaptive desktop/mobile layout, and a bigger, crisper creature sprite. One
server-side change comes along: the Gemini birth-prompt switches the sprite
background from pure white to a dark "screen" colour so newly-hatched sprites
blend into the chrome instead of sitting in a white box.

The creature sprites themselves are already retro 16-bit pixel-art — that is the
anchor the chrome is being brought up to match, not something to invent (see
`frame.md`).

## Current State Analysis

- **Theme**: the entire app theme is `ThemeData(useMaterial3: true)` at
  `tamagotchi_flutter/lib/app/app_widget.dart:15` — default M3 purple seed, no
  custom `ColorScheme`, no `textTheme`, no `fontFamily`. The app is **100%
  Material** (`MaterialApp.router`); `shadcn_ui` is a declared but unused
  dependency.
- **Fonts**: no custom font. `pubspec.yaml` has only the commented template
  `fonts:` block; `assets/` holds a single `config.json`. `google_fonts` exists
  transitively (via `shadcn_ui`) but is not a direct dep and is unused.
- **Chrome surfaces** (6): `auth/sign_in_screen.dart`, `home/home_screen.dart`,
  `creature/creature_view.dart`, `creature/journal_view.dart`,
  `creature/hatch_form.dart`, `creature/reset_confirm_dialog.dart`, plus the
  sprite host `creature/critter_image.dart`.
- **Home layout**: fixed two-pane `Row(Expanded(CreatureView) | VerticalDivider |
  Expanded(JournalView))` (`home_screen.dart:96-102`) — desktop-shaped, cramped
  on a phone. No responsive breakpoint anywhere.
- **Stats**: Hunger/Energy/Love/Illness render as plain bold `Text('$value')` in
  `_StatRow` (`creature_view.dart:326-346`), each wrapped in a `Key('statRow-<label>')`.
- **Sprite**: `CritterImage` (`critter_image.dart`) shows `Image.network` at a
  128px default, `BoxFit.contain`, **no `filterQuality`** (bilinear). Source is
  1024². Stored/served as JPEG at `creatures/<id>.jpg`.
- **Server sprite prompt**: `buildCritterImagePrompt` (`tamagotchi_server/lib/src/llm/critter_image_prompt.dart:62`)
  emphatically pins `Background: pure solid white (#FFFFFF)`. Output is JPEG,
  stored as-is.
- **Test couplings** (verified): a font + `ColorScheme` + `ThemeData`-override
  swap breaks **no** existing assertion (no color/icon/golden couplings; the only
  3 style-object checks read `fontStyle`). But stat-value text finders
  (~15 in `creature_view_test.dart`, plus `feed_persistence_test.dart` e2e scoped
  inside `statRow-*` keys) and the sprite default-size box (`critter_image_test.dart`)
  and the prompt's `#FFFFFF`/`white` assertion (`critter_image_prompt_test.dart:50-51`)
  are couplings this plan deliberately touches.

## Desired End State

Opening the app on desktop or phone shows a coherent dark retro game: VT323
pixel type everywhere, a limited dark CRT palette, flat hard-edged buttons/panels
(larger than today), creature stats as chunky segmented bars with their numbers,
the creature sprite shown large (256px) and crisp, sitting on a dark screen it
blends into. On a narrow window the Creature and Journal split into tabs; on a
wide window they stay side-by-side. Newly-hatched creatures are born on the dark
screen colour. Verify by: `flutter analyze`/`test` green in `tamagotchi_flutter`,
`dart analyze`/`test` green in `tamagotchi_server`, a successful web build, and a
manual pass at both phone and desktop widths plus one real-key hatch.

### Key Discoveries:

- Theme is a single line to replace: `app_widget.dart:15`. A central
  `buildRetroTheme()` factory restyles every Material widget at once.
- Widget tests wrap units in a **bare `MaterialApp` with the default theme**
  (`journal_view_test.dart:42-52`), so they do not exercise the new theme — the
  theme is only visually exercised via `AppWidget`/e2e. Test the factory directly
  instead (assert its `ThemeData` invariants).
- Keeping the numeric stat value as findable `Text` inside `statRow-<label>`
  preserves ~15 widget asserts **and** 2 Patrol e2e number-finders — a
  segmented bar can wrap the number rather than replace it.
- Sprite is 1024² shown small → nearest-neighbour on a large *down*scale can
  alias; displaying at 256px (4× not 8×) reduces that risk (`critter_image.dart`).
- JPEG can't be transparent, so the "blend into chrome" goal is a **solid dark
  background** requested in the prompt — a string edit, not a pipeline change.

## What We're NOT Doing

- **Not** switching the sprite pipeline to PNG/transparency (stays JPEG,
  `creatures/<id>.jpg`) — chosen to avoid endpoint/storage/stub churn and model
  alpha-reliability risk.
- **Not** regenerating existing creatures' images. Pre-existing sprites keep
  their white background (a white box on the dark theme); a user can `reset` +
  re-hatch to get a dark-background sprite. Acceptable for the current
  single-user/MVP state.
- **Not** adopting `shadcn_ui` or building a hand-rolled widget kit — Material
  `ThemeData` override only.
- **Not** replacing the 7 Material `Icons.*` with a pixel icon set — they tint
  to the palette and read acceptably; pixel-icon replacement is future polish.
- **Not** adding CRT scanline/curvature overlays — out of scope; can be a later
  request.
- **Not** re-styling the external Serverpod `SignInWidget` internals (sign-in
  form chrome is owned by `serverpod_auth_idp_flutter`); only its surrounding
  `Scaffold`/`AppBar` inherit the theme.

## Implementation Approach

Material `ThemeData` factory is the spine: one `buildRetroTheme()` centralizes
font, palette, shape, elevation, border, and control sizing, so all six chrome
surfaces restyle without per-file edits. On top of that spine, three focused
client changes (stat bars, adaptive layout, sprite size/filter) and one server
change (prompt background) each land as their own phase. Phase 1 defines a single
canonical "screen" colour constant that Phase 5's server prompt must mirror.

## Critical Implementation Details

- **Shared screen colour (client↔server coupling)**: Phase 1 defines one dark
  "screen" colour used as the surface the sprite renders on. Phase 5's server
  prompt must request that **same hex**. Server and client share no code, so the
  value is duplicated intentionally — pick one hex, name it in
  `retro_theme.dart`, and paste the identical hex into the prompt string; a
  comment on each side must point at the other. If they drift, the sprite shows a
  mismatched halo.
- **Sprite blend surface**: the sprite blends only if the widget/surface directly
  behind `CritterImage` is the screen colour. Ensure the creature panel's
  background resolves to the shared screen colour, not a different `ColorScheme`
  surface token.
- **Downscale/aliasing caveat**: `FilterQuality.none` at 256px (4× downscale) is
  a try-and-verify; if edges shimmer, nudge the display size toward a cleaner
  fraction of 1024 or revert to default filtering. This is a manual check, not a
  guaranteed win.
- **Stat-number preservation invariant**: the segmented bar must keep the numeric
  value as a `Text` findable inside `Key('statRow-<label>')`, or ~15 widget
  asserts + 2 e2e finders break. Treat "existing stat tests still green" as the
  phase gate.

## Phase 1: Retro theme foundation

### Overview

Bundle the VT323 pixel font and replace the default theme with a
`buildRetroTheme()` factory producing a dark CRT/LCD look with flat, hard-edged,
**larger** controls. Define the shared screen-colour constant here.

### Changes Required:

#### 1. Bundle the VT323 font

**File**: `tamagotchi_flutter/assets/fonts/VT323-Regular.ttf` (new), `tamagotchi_flutter/pubspec.yaml`

**Intent**: Add the OFL-licensed VT323 TTF as a bundled asset so the app has a
deterministic offline pixel font (no runtime `google_fonts` fetch). Commit the
OFL licence text alongside it.

**Contract**: New `assets/fonts/` dir containing `VT323-Regular.ttf` and `OFL.txt`.
A real `fonts:` entry under the `flutter:` section of `pubspec.yaml` declaring
family `VT323` → the asset. (Place it under `flutter:`, not near the commented
template that sits after `dependency_overrides:`.)

#### 2. Retro theme factory

**File**: `tamagotchi_flutter/lib/app/retro_theme.dart` (new)

**Intent**: One `ThemeData buildRetroTheme()` that every screen inherits: dark
`ColorScheme` (a small limited CRT palette — dark screen background + one/two
phosphor accents), `VT323` as `fontFamily`/`textTheme`, flat hard edges
(zero or beveled corner radius, `elevation: 0`, thick borders on buttons/cards/
inputs/dialogs), and **larger** controls (bigger `minimumSize`, padding, and
label text on the button themes). Export a `const` screen-colour (the shared
constant — see Critical Implementation Details).

**Contract**: `ThemeData buildRetroTheme()` + a top-level
`const Color retroScreenColor` (or similarly named). Configures at minimum
`colorScheme`, `textTheme`/`fontFamily`, `elevatedButtonTheme`, `textButtonTheme`,
`cardTheme`, `dialogTheme`, `inputDecorationTheme`, `appBarTheme`,
`snackBarTheme`, and global shape (no rounded corners, no shadows).

#### 3. Wire the theme

**File**: `tamagotchi_flutter/lib/app/app_widget.dart`

**Intent**: Replace `theme: ThemeData(useMaterial3: true)` with
`theme: buildRetroTheme()`.

**Contract**: `app_widget.dart:15` now references `buildRetroTheme()`; import added.

#### 4. Theme factory unit test

**File**: `tamagotchi_flutter/test/app/retro_theme_test.dart` (new)

**Intent**: Lock the load-bearing theme invariants without pumping every screen
(widget tests use the default theme, so they can't).

**Contract**: Asserts `buildRetroTheme()` returns `ThemeData` with
`textTheme`/`fontFamily` == `VT323`, `colorScheme.brightness == dark`,
flat shape (no positive corner radius), `elevation`/shadows zero on card/button
themes, larger button `minimumSize`, and `retroScreenColor` == the agreed hex.

### Success Criteria:

#### Automated Verification:

- Flutter analyze passes: `cd tamagotchi_flutter && flutter analyze`
- Format clean: `cd tamagotchi_flutter && dart format --set-exit-if-changed .`
- Flutter tests pass (existing suite unaffected + new theme test): `cd tamagotchi_flutter && flutter test`
- Web build succeeds: `cd tamagotchi_server && serverpod run flutter_build`

#### Manual Verification:

- All screens (sign-in, home, creature, journal, hatch, reset dialog) render the dark CRT palette and VT323 font
- Buttons/panels are flat, hard-edged, and visibly larger — no rounded/elevated Material look remains
- Journal prose is legible in VT323 at body size

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Retro segmented stat bars

### Overview

Replace the plain-text stat numbers with chunky segmented pixel bars while keeping
the numeric value as findable text, and make them larger.

### Changes Required:

#### 1. RetroStatBar widget

**File**: `tamagotchi_flutter/lib/creature/retro_stat_bar.dart` (new)

**Intent**: A stateless bar that renders a value/max as N filled hard-edged blocks
out of a fixed total, with the numeric value shown alongside, sized larger than
today's row.

**Contract**: `RetroStatBar({required String label, required int value, int max, ...})`
rendering the block row + a `Text('$value')`. Uses theme colours (filled vs empty
block). No new provider.

#### 2. Rework `_StatRow`

**File**: `tamagotchi_flutter/lib/creature/creature_view.dart`

**Intent**: Swap `_StatRow`'s plain `Text('$value')` for `RetroStatBar`, keeping
the `Key('statRow-<label>')` wrapper and a findable numeric `Text` so existing
widget + e2e finders survive (see invariant).

**Contract**: `_StatRow` (or its four call sites at `creature_view.dart:76-79`)
now composes `RetroStatBar`; `statRow-<label>` keys and numeric text preserved.

#### 3. Widget test

**File**: `tamagotchi_flutter/test/creature/retro_stat_bar_test.dart` (new)

**Intent**: Verify the bar fills the right number of blocks for a value and shows
the number.

**Contract**: Pumps `RetroStatBar` with sample values; asserts filled-block count
and that `find.text('<value>')` resolves.

### Success Criteria:

#### Automated Verification:

- Flutter analyze passes: `cd tamagotchi_flutter && flutter analyze`
- Format clean: `cd tamagotchi_flutter && dart format --set-exit-if-changed .`
- All Flutter tests pass, including the untouched stat-number asserts in `creature_view_test.dart`: `cd tamagotchi_flutter && flutter test`

#### Manual Verification:

- Stats display as large chunky segmented bars with their numbers
- Bars visibly change after Feed/Play/Cure
- No layout overflow in the creature panel

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 3.

---

## Phase 3: Adaptive desktop/mobile layout

### Overview

Make the home screen responsive: two-pane on wide viewports, Creature/Journal
tabs on narrow ones.

### Changes Required:

#### 1. Responsive home body

**File**: `tamagotchi_flutter/lib/home/home_screen.dart`

**Intent**: Replace the fixed `Row` (data state) with a `LayoutBuilder` breakpoint:
at/above a width threshold keep the two-pane `Row`; below it, present Creature and
Journal as tabs so both stay fully usable on a phone. Extract the branch into a
small widget to keep it testable.

**Contract**: New responsive body (e.g. `_HomeBody`) with a `~700`px breakpoint;
narrow branch uses `DefaultTabController` + `TabBar`/`TabBarView` (Creature |
Journal), wide branch preserves `Expanded(CreatureView) | VerticalDivider |
Expanded(JournalView)`. Existing providers reused unchanged.

#### 2. Responsive layout test

**File**: `tamagotchi_flutter/test/home/home_layout_test.dart` (new)

**Intent**: Prove the breakpoint switches layouts.

**Contract**: Pump the extracted body at a narrow and a wide `tester.view`/
`MediaQuery` size; assert `TabBar` present when narrow and the two panes /
`VerticalDivider` present when wide. Follows the `ProviderScope`-override harness
(`journal_view_test.dart:42-52`).

### Success Criteria:

#### Automated Verification:

- Flutter analyze passes: `cd tamagotchi_flutter && flutter analyze`
- Format clean: `cd tamagotchi_flutter && dart format --set-exit-if-changed .`
- All Flutter tests pass incl. the new layout test: `cd tamagotchi_flutter && flutter test`

#### Manual Verification:

- At phone width: Creature/Journal tabs work, both panes usable, no `RenderFlex` overflow
- At desktop width: side-by-side layout unchanged
- Resizing the window transitions cleanly between the two

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 4.

---

## Phase 4: Bigger, crisper sprite

### Overview

Show the creature sprite at 256px with nearest-neighbour filtering, verifying it
stays crisp rather than aliasing.

### Changes Required:

#### 1. Larger, crisp sprite

**File**: `tamagotchi_flutter/lib/creature/critter_image.dart`

**Intent**: Display the sprite at 256px (from 128) and add
`filterQuality: FilterQuality.none` to the `Image.network` so the pixel-art shows
crisp. 256px halves the downscale ratio (8×→4×), reducing aliasing risk.

**Contract**: `CritterImage` default `size` becomes 256 (or the call site in
`creature_view.dart:74` passes `size: 256`); `Image.network(..., filterQuality: FilterQuality.none)`.

#### 2. Update sprite-size test

**File**: `tamagotchi_flutter/test/creature/critter_image_test.dart`

**Intent**: Adjust the default-box assertion to the new 256px default (only if the
widget default is changed rather than the call site).

**Contract**: The "reserves default box" assertion expects 256×256; the custom-64
case stays.

### Success Criteria:

#### Automated Verification:

- Flutter analyze passes: `cd tamagotchi_flutter && flutter analyze`
- Format clean: `cd tamagotchi_flutter && dart format --set-exit-if-changed .`
- All Flutter tests pass incl. updated `critter_image_test.dart`: `cd tamagotchi_flutter && flutter test`

#### Manual Verification:

- Sprite renders at 256px and looks crisp/blocky, not blurred
- No aliasing/shimmer on the pixel edges; if present, display size or filter adjusted per the aliasing note

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 5.

---

## Phase 5: Dark sprite background (server prompt)

### Overview

Change the Gemini birth-prompt so new sprites are generated on the dark screen
colour instead of white, blending into the chrome. Server-only, keeps JPEG.

### Changes Required:

#### 1. Prompt background

**File**: `tamagotchi_server/lib/src/llm/critter_image_prompt.dart`

**Intent**: Replace the `Background: pure solid white (#FFFFFF), completely flat
and empty.` instruction with a request for a solid flat background at the shared
dark screen hex (the same value as Phase 1's `retroScreenColor`). Update the
load-bearing doc comment (`:53-61`) that currently justifies white.

**Contract**: Prompt string now pins the dark hex; add a comment pointing at
`retro_theme.dart`'s `retroScreenColor` as the source of truth. The
tightly-cropped/single-creature/no-shadow constraints stay.

#### 2. Update prompt test

**File**: `tamagotchi_server/test/llm/critter_image_prompt_test.dart`

**Intent**: The existing test asserts the prompt contains `#FFFFFF` and `white`;
retarget it to the new dark hex.

**Contract**: `critter_image_prompt_test.dart:50-51` now expects the dark screen
hex (and drops the `white` expectation); the personality-variation asserts stay.

### Success Criteria:

#### Automated Verification:

- Server analyze passes: `cd tamagotchi_server && dart analyze`
- Format clean: `cd tamagotchi_server && dart format --set-exit-if-changed .`
- Server tests pass incl. the updated prompt test: `cd tamagotchi_server && dart test`

#### Manual Verification:

- Hatch a NEW creature with a real `geminiApiKey` (dev) → sprite is born on the dark screen colour and blends into the panel (no white box)
- The creature still reads clearly on the dark background (outline/contrast acceptable); if not, lighten the screen colour on both sides
- Existing (pre-change) creatures still render without error (white box acceptable; reset+re-hatch regenerates)

**Implementation Note**: Final phase — after automated + manual verification, the revamp is complete.

---

## Testing Strategy

### Unit Tests:

- `retro_theme_test.dart` — theme invariants (font, dark brightness, flat shape, larger buttons, screen colour).
- `retro_stat_bar_test.dart` — filled-block count + numeric text present.
- `critter_image_prompt_test.dart` — dark screen hex requested (updated).

### Widget Tests:

- `home_layout_test.dart` — tabs at narrow width, two-pane at wide width.
- Untouched: `creature_view_test.dart` stat-number asserts must remain green (regression guard for the stat-bar rework).
- Updated: `critter_image_test.dart` default box size (256).

### Integration / e2e (Patrol — heavy; optional per lessons):

- `feed_persistence_test.dart` scopes stat numbers inside `statRow-*` keys — the
  stat-bar rework must keep those findable. Widget tests cover the same invariant,
  so a full Patrol run is optional (Patrol web is toolchain-sensitive — see
  `lessons.md`).

### Manual Testing Steps:

1. Run the app; confirm dark CRT + VT323 across every screen.
2. Feed/Play/Cure; confirm stat bars + numbers update.
3. Resize between phone and desktop widths; confirm tabs ↔ two-pane, no overflow.
4. Inspect the sprite at 256px for crispness.
5. With a real `geminiApiKey`, hatch a new creature; confirm dark-background sprite blends in.

## Performance Considerations

Negligible — a font asset, theme object, one extra widget, and a layout branch.
The sprite stays 1024² source at 256px display; nearest-neighbour is cheaper than
bilinear, not more expensive.

## Migration Notes

No schema/migration changes (no `.spy.yaml` touched). Existing stored sprites keep
their white background; only creatures hatched after Phase 5 use the dark
background. `reset` + re-hatch regenerates an existing creature's image under the
new prompt.

## References

- Frame brief: `context/changes/ui-retro-revamp/frame.md`
- Theme root: `tamagotchi_flutter/lib/app/app_widget.dart:15`
- Sprite host: `tamagotchi_flutter/lib/creature/critter_image.dart`
- Home layout: `tamagotchi_flutter/lib/home/home_screen.dart:96-102`
- Stat rows: `tamagotchi_flutter/lib/creature/creature_view.dart:326-346`
- Server prompt: `tamagotchi_server/lib/src/llm/critter_image_prompt.dart:62-78`
- Prompt test: `tamagotchi_server/test/llm/critter_image_prompt_test.dart:50-51`
- Test harness pattern: `tamagotchi_flutter/test/creature/journal_view_test.dart:42-52`
- Lessons (format gate, dart test harness): `context/foundation/lessons.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Retro theme foundation

#### Automated

- [x] 1.1 Flutter analyze passes — 74a77a8
- [x] 1.2 Format clean (flutter, `--set-exit-if-changed`) — 74a77a8
- [x] 1.3 Flutter tests pass (existing suite + new theme test) — 74a77a8
- [x] 1.4 Web build succeeds (`serverpod run flutter_build`) — 74a77a8

#### Manual

- [x] 1.5 All screens render dark CRT palette + VT323 — 74a77a8
- [x] 1.6 Buttons/panels flat, hard-edged, and larger — no rounded/elevated look — 74a77a8
- [x] 1.7 Journal prose legible in VT323 — 74a77a8

### Phase 2: Retro segmented stat bars

#### Automated

- [x] 2.1 Flutter analyze passes
- [x] 2.2 Format clean (flutter)
- [x] 2.3 All Flutter tests pass incl. untouched stat-number asserts

#### Manual

- [x] 2.4 Stats display as large segmented bars with numbers
- [x] 2.5 Bars change after Feed/Play/Cure
- [x] 2.6 No overflow in the creature panel

### Phase 3: Adaptive desktop/mobile layout

#### Automated

- [ ] 3.1 Flutter analyze passes
- [ ] 3.2 Format clean (flutter)
- [ ] 3.3 All Flutter tests pass incl. new layout test

#### Manual

- [ ] 3.4 Phone width: tabs work, both panes usable, no overflow
- [ ] 3.5 Desktop width: side-by-side unchanged
- [ ] 3.6 Window resize transitions cleanly

### Phase 4: Bigger, crisper sprite

#### Automated

- [ ] 4.1 Flutter analyze passes
- [ ] 4.2 Format clean (flutter)
- [ ] 4.3 All Flutter tests pass incl. updated `critter_image_test.dart`

#### Manual

- [ ] 4.4 Sprite renders at 256px, crisp not blurred
- [ ] 4.5 No aliasing/shimmer (or size/filter adjusted per note)

### Phase 5: Dark sprite background (server prompt)

#### Automated

- [ ] 5.1 Server analyze passes
- [ ] 5.2 Format clean (server)
- [ ] 5.3 Server tests pass incl. updated prompt test

#### Manual

- [ ] 5.4 New real-key hatch: sprite born on dark screen colour, blends into panel
- [ ] 5.5 Creature reads clearly on dark background (or screen colour lightened)
- [ ] 5.6 Existing creatures still render without error
