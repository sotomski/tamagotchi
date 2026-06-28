# Generated Creature Image at Birth — Implementation Plan

## Overview

When a creature is born (hatch), the server generates a unique, retro pixel-art
body for it via a second blocking Mistral structured-output call, validates and
auto-repairs the result, and persists it as a typed `json` field on the
`Creature` row. The Flutter web client renders it crisp and chunky-scaled with a
new `CustomPainter`. Scope is the **static** birth graphic only — no reaction
animations, motion/particle presets, or typography work.

## Current State Analysis

The hatch flow is a tight, deliberate sequence
(`tamagotchi_server/lib/src/creature/creature_endpoint.dart:28-139`):

1. Roll personality modifiers (`:46`).
2. **Blocking** narrative LLM call *before* the transaction
   (`hatchLlmServiceFactory(session).generateInteraction(...)`, `:55-70`). On
   throw it raises `CreatureHatchError(reason: narrativeUnavailable)` and nothing
   is written — there is deliberately **no canned fallback** (`hatch_copy.dart`
   documents this).
3. A single `session.db.transaction` (`:74-116`) inserts `Creature`,
   `CreaturePersonality`, and a `hatched` `JournalEntry`.
4. Returns `CreatureStatus` via `_statusFor(creature, loveRegenMod)` (`:138`,
   `:685-690`), which nests the persisted `Creature`.

Reusable conventions already in place:

- **Service factory seams**: `hatchLlmServiceFactory = llmServiceFor` (`:702`);
  the same `<x>ServiceFactory = <x>ServiceFor` pattern exists for feed/play/cure
  (`feed_service.dart:172`, `play_service.dart:107`, `cure_service.dart:87`).
  Tests reassign the seam and restore it with `addTearDown`
  (`creature_endpoint_test.dart:119-120`).
- **LLM service**: `LlmService` interface (`llm_service.dart:87-94`);
  `MistralLlmService` already issues structured `response_format`/`json_schema`
  calls and parses `choices[0].message.content` (`mistral_client.dart:51-71`,
  `:95-136`); `StubLlmService` selected by **key absence**
  (`llm_service.dart:96-113`). `test`/`e2e` runmodes omit `mistralApiKey`
  (`config/passwords.yaml`, `server.dart` `_e2eConfigOverride`) so they stay
  hermetic on the stub.
- **Storage**: complex fields are typed nested models auto-serialized to a `json`
  column (e.g. `JournalEntry.statDelta: StatDelta?` →
  `"statDelta" json`, `migrations/.../definition.sql:78`,
  `protocol.dart:314`). **Serverpod 3.4.8 cannot emit `jsonb`** — there is no
  keyword, annotation, or flag for it (see `research.md`). A nullable field on
  `Creature` auto-surfaces through `CreatureStatus` to the client after
  `serverpod generate`.

Client render surface is new:

- `CreatureView` is a text/stat `Column` (`creature_view.dart:32-181`); the
  natural sprite slot is after the mood label (`:68`).
- `creatureProvider` returns `Future<CreatureStatus?>`
  (`creature_provider.dart:15-22`); widget tests override it with canned values
  (`creature_view_test.dart:280`).
- **No `CustomPainter`/`Canvas` exists anywhere** in `tamagotchi_flutter`.
  Default Material theme, no custom fonts.

Personality is stored as **7 decay/regen multipliers in `[0.5, 1.5)`**
(`creature_personality.spy.yaml`, rolled in `creature_service.dart:53-67`) — the
brief's named 0.0–1.0 "personality vector" does not exist and must be derived.
The existing prompt already passes raw mods with textual hints
(`creature_prompt.dart:262-268`).

## Desired End State

Hatching a new creature produces a unique, symmetrical pixel critter that renders
crisp at 128px in `CreatureView` immediately after birth. The critter's look is
loosely informed by its personality. If image generation fails or produces an
un-repairable result, the hatch fails cleanly (`CreatureHatchError`) and nothing
is persisted — the same contract the narrative call already follows. Pre-existing
creatures (no stored image) render gracefully without a sprite.

### Key Discoveries:

- Blocking-before-transaction is the established hatch pattern for external calls
  (`creature_endpoint.dart:55-70`) — the new gen call follows it.
- `json_schema` structured output is already proven here
  (`mistral_client.dart:51-71`) — the new call duplicates the envelope with a
  palette+grid schema.
- A nullable typed field on `Creature` is the entire storage change; it
  propagates to the client through `CreatureStatus` automatically.
- Apply migrations with `serverpod run start`, **not** `--apply-migrations`
  (`context/foundation/lessons.md`).
- Run `dart format .` in both packages before each phase commit — Format CI is
  `--set-exit-if-changed` (`context/foundation/lessons.md`).

## What We're NOT Doing

- No reaction animations, motion presets, particle library, `fps`, `tint`,
  `speed`/`rate`, or the multi-expression/face-box format (brief §4–§6).
- No Pixelify Sans / typography work (brief §12).
- No Flame; pure Flutter `CustomPainter` (brief §11).
- No reject-and-reprompt round-trip; no default-template fallback critter.
- No personality-axis refactor — we derive hints from the existing mods, we do
  not change how personality is stored.
- No regeneration on fetch, no async/background generation, no `jsonb` column.

## Implementation Approach

Build the contract first (the typed `CritterSpec` + validator), then the client
render path against a hand-written spec (so rendering is provable before any
model is involved), then the server generation service behind a factory seam with
a hermetic stub, and finally wire the blocking call into hatch. A throwaway
Phase 0 probe de-risks the no-fallback bet at the chosen 32×32 size before any
shippable code lands.

The 32×32 canvas is a deliberate user override of the brief's 16×16
recommendation (see Open Risks). The `size` field in `CritterSpec` keeps it a
one-value change if production shows the model can't draw reliably at 32.

> **Phase 0 adaptation (2026-06-28, supersedes the mirror references below).** The
> throwaway probe showed every Mistral model draws a *complete, centred* creature
> filling the whole grid — not a true left half — so the original left-half-mirror
> protocol was dropped. The model emits the **full `size`×`size` grid and we accept
> it as-is**; `CritterSpec` has **no `mirror` field**. Image generation also pins
> **`mistral-large-latest`** (not the narrative `mistral-small-2603`), the only
> model that draws cleanly at 32×32. The validator/repair still normalise ±1
> row/column drift. See `change.md` → "Phase 0 probe outcome". The phase blocks
> below have been updated to match; any residual mirror phrasing is historical.

## Critical Implementation Details

- **Timing & lifecycle**: the image-gen call must sit **outside and before** the
  `session.db.transaction` (alongside the existing narrative call,
  `creature_endpoint.dart:55-74`), so a generation failure throws before any row
  is written — preserving the "no half-hatched creature" invariant. Persist the
  validated spec **inside** the transaction as part of the `Creature` insert.
- **Grid geometry** (Phase 0 adaptation): the model emits the **full square** —
  `size` rows of `size` chars (32 rows × 32 chars) — and we accept it as-is. No
  mirroring; symmetry is whatever the model draws. The validator asserts row count
  `== size` and each row length `== size`; repair pads/truncates the ±1 drift.
- **Transparent palette entry**: `.` is always transparent and is **not** stored
  in the palette map (Serverpod `Map<String,String>` values are non-null); the
  compositor treats any char absent from the palette (and `.`) as transparent.

## Phase 0: Generation Probe (throwaway)

### Overview

Confirm `mistral-small-2603` reliably emits a clean, varied, non-degenerate
32×16 (mirrored) char-grid via structured output, before committing to the
no-fallback pipeline. This is a throwaway script/test, not shipped code; its
output also sanity-checks the schema shape chosen in Phase 1.

### Changes Required:

#### 1. Throwaway probe

**File**: `tamagotchi_server/tool/critter_probe.dart` (throwaway; deleted or
gitignored before merge)

**Intent**: Issue ~10 generations against the real Mistral API at 32×16 mirror
with the candidate prompt + `json_schema`, print each grid composited to ASCII so
a human can eyeball "varied" and "non-degenerate" (not mostly-transparent, not
all-identical). Confirms the structured-output call returns parseable
palette+grid content at the chosen size.

**Contract**: Standalone `main()` reading `mistralApiKey` from the dev
`passwords.yaml`; reuses the candidate request body shape from Phase 3. No
production wiring.

### Success Criteria:

#### Automated Verification:

- Probe script runs without error against the dev key:
  `dart run tool/critter_probe.dart`

#### Manual Verification:

- Across ~10 seeds, grids are visibly varied (not near-identical) and
  non-degenerate (a recognizable filled body silhouette, not noise or near-empty).
- The structured-output response parses cleanly at 32×16 every time, or the
  failure rate is low enough to accept under "block hatch".
- Decision recorded: proceed at 32×32, or fall back to 16×16 / a larger model
  before Phase 1.

**Implementation Note**: After completing this phase, pause for human
confirmation of the probe results (and the size decision) before proceeding.

---

## Phase 1: Data Model + Validator

### Overview

Define the typed `CritterSpec` model, attach it as a nullable field on
`Creature`, regenerate, migrate, and write the pure validator + auto-repair that
both the server pipeline (Phase 3) and any consumer rely on.

### Changes Required:

#### 1. CritterSpec model

**File**: `tamagotchi_server/lib/src/creature/critter_spec.spy.yaml`

**Intent**: A serializable (non-table) model describing one static critter: the
versioned, full-square grid + palette. Nested onto `Creature`, so it lands in a
single `json` column and crosses the RPC boundary to the client.

**Contract** (Phase 0 adaptation — no `mirror` field): Fields — `v: int`,
`size: int`, `palette: Map<String, String>` (char → `#RRGGBB`; `.`/absent =
transparent), `base: List<String>` (exactly `size` rows of `size` chars — the
full square the model draws). No `table:` key (serialized model only).

#### 2. Creature field

**File**: `tamagotchi_server/lib/src/creature/creature.spy.yaml`

**Intent**: Add a nullable `image` field so existing rows remain valid and the
sprite surfaces through `CreatureStatus` automatically.

**Contract**: `image: CritterSpec?`. Nullable is required (legacy creatures +
the migration's existing rows have none).

#### 3. Regenerate + migrate

**File**: `tamagotchi_server/` (codegen + migration output)

**Intent**: Produce the Dart models (server + generated client) and a migration
adding the `image` `json` column to `creature`.

**Contract**: `serverpod generate` then `serverpod create-migration`; the new
column is `"image" json` (nullable). Apply locally with `serverpod run start`.

#### 4. Validator + auto-repair

**File**: `tamagotchi_server/lib/src/creature/critter_spec_validator.dart`

**Intent**: Pure functions that assert a generated spec is well-formed and
auto-repair fixable issues, so Phase 3 can gate on them with no reprompt.

**Contract** (Phase 0 adaptation — full grid, no `mirror`):
`validateCritterSpec(CritterSpec) -> List<String>` (empty = valid) and
`repairCritterSpec(CritterSpec) -> CritterSpec`. Asserts: `base` has exactly
`size` rows; each row exactly `size` chars; every non-`.` cell char exists in
`palette`; every palette value matches `^#[0-9A-Fa-f]{6}$`; palette keys are
single non-`.` chars; `v` and `size` match the expected contract. Repair:
pad/truncate rows to `size`, pad/truncate row count to `size`, replace unknown
cell chars with `.`, drop malformed palette entries, pin `v`/`size`. No
`Session`, no I/O.

### Success Criteria:

#### Automated Verification:

- Code generation is clean: `serverpod generate` (no errors)
- Migration created and applies: `serverpod run start` boots and applies it
- Validator unit tests pass: `dart test test/creature/critter_spec_validator_test.dart`
- Analyze + format clean: `dart analyze` and `dart format --set-exit-if-changed .`

#### Manual Verification:

- The `creature` table has a nullable `image` json column; existing creatures are
  unaffected (null image).

**Implementation Note**: After completing this phase and all automated
verification passes, pause for human confirmation before proceeding.

---

## Phase 2: Flutter Render Path (static, hand-written spec)

### Overview

Render a `CritterSpec` crisp and chunky-scaled in `CreatureView`, proven against
a hand-written spec so the render path is correct before any model output exists.

### Changes Required:

#### 1. Grid compositor

**File**: `tamagotchi_flutter/lib/creature/critter_compositor.dart`

**Intent**: Turn a `CritterSpec` into a `dart:ui.Image`: read the full
`size`×`size` grid directly (no un-mirroring — Phase 0 adaptation), map palette
chars to RGBA (`.`/absent = transparent), and decode to a `ui.Image`. Cache per
creature so it rebuilds only when the spec changes.

**Contract**: `Future<ui.Image> compositeCritter(CritterSpec)` using
`ui.decodeImageFromPixels` over a `Uint8List` RGBA buffer. Each `base[r][c]` maps
straight to pixel `(c, r)`; no column mirroring.

#### 2. Critter painter

**File**: `tamagotchi_flutter/lib/creature/critter_painter.dart`

**Intent**: A `CustomPainter` that draws the cached `ui.Image` nearest-neighbor
into an integer-multiple box for the retro look.

**Contract**: `canvas.drawImageRect(...)` with
`Paint()..filterQuality = FilterQuality.none`; destination box an integer
multiple of `size` (32 → 128 = 4×). `shouldRepaint` keyed on the image identity.

#### 3. Critter view widget + slot

**File**: `tamagotchi_flutter/lib/creature/critter_image.dart` and
`creature_view.dart`

**Intent**: A widget that composites + paints `status.creature.image`, slotted
into `CreatureView` after the mood label. Renders nothing (or a small neutral
placeholder) when `image == null` (legacy creatures).

**Contract**: New `CritterImage({required CritterSpec? spec})`; inserted around
`creature_view.dart:68`. Null spec → `SizedBox.shrink()` (or placeholder). Uses a
`FutureBuilder`/cached image off `compositeCritter`.

### Success Criteria:

#### Automated Verification:

- Render/compositor unit + widget tests pass: `flutter test test/creature/`
- Analyze + format clean: `dart analyze` and `dart format --set-exit-if-changed .`

#### Manual Verification:

- A hand-written spec renders as a crisp, symmetrical critter at 128px with no
  blur/shimmer (sharp pixel edges).
- An existing creature with `image == null` renders the rest of `CreatureView`
  with no layout break.

**Implementation Note**: After completing this phase and all automated
verification passes, pause for human confirmation before proceeding.

---

## Phase 3: Server Generation Pipeline (Mistral)

### Overview

Generate a `CritterSpec` from a personality-informed prompt via a structured
Mistral call, behind a factory seam with a hermetic stub, gated by the Phase 1
validator + repair (no reprompt).

### Changes Required:

#### 1. CritterImageService interface + stub + real impl

**File**: `tamagotchi_server/lib/src/llm/critter_image_service.dart`,
`stub_critter_image_service.dart`, `mistral_critter_image_service.dart`

**Intent**: Mirror the `LlmService`/`MistralLlmService`/`StubLlmService` trio for
image generation: a single-method service that returns a validated `CritterSpec`.
Stub returns a fixed, valid hand-authored spec (hermetic for `test`/`e2e`); real
impl calls Mistral with a palette+grid `json_schema`.

**Contract**: `abstract interface class CritterImageService` with
`Future<CritterSpec> generateImage(Session, CritterImageRequest)`. Factory
`critterImageServiceFor(Session) -> StubCritterImageService` when
`mistralApiKey` absent else `MistralCritterImageService` (copy
`llm_service.dart:96-113`). Real impl duplicates the `_responseFormat` envelope
(`mistral_client.dart:51-71`) with a schema of `palette` + `base` (and parses
`choices[0].message.content`); pins **`mistral-large-latest`** (Phase 0
adaptation — the only model that draws cleanly at 32×32, not the narrative
`mistral-small-2603`); runs result through `repairCritterSpec` then
`validateCritterSpec` — on remaining errors it **throws** (block-hatch posture).

#### 2. Personality → visual hints + prompt

**File**: `tamagotchi_server/lib/src/llm/critter_image_prompt.dart`

**Intent**: Translate the 7 decay/regen mods into a short list of visual
descriptors (e.g. high `energyRegenMod` → "lively, spiky"; low `loveRegenMod` →
"shy, rounded") and build the system+user messages, restating dims explicitly
("emit exactly 32 rows of 32 chars — the full square critter", Phase 0
adaptation) with a fixed palette and 1–2 few-shot example critters.

**Contract**: `CritterImageRequest` (server-internal plain class, like
`InteractionRequest`) carrying the personality mods + name + a random seed for
variety. `buildCritterImageMessages(CritterImageRequest) -> List<Map>`. Pure,
unit-testable.

#### 3. Stub spec asset

**File**: `tamagotchi_server/lib/src/llm/critter_image_copy.dart`

**Intent**: The fixed, valid 32×32 full-grid `CritterSpec` the stub returns
(Phase 0 adaptation) — distinct enough to be asserted in tests, analogous to
`hatch_copy.dart`.

**Contract**: `const`/builder returning a schema-valid `CritterSpec` that passes
`validateCritterSpec`.

### Success Criteria:

#### Automated Verification:

- Service + prompt + mapping unit tests pass: `dart test test/llm/`
- Stub returns a spec that passes the validator (asserted in test)
- Analyze + format clean: `dart analyze` and `dart format --set-exit-if-changed .`

#### Manual Verification:

- With a real dev `mistralApiKey`, `generateImage` returns a spec that passes
  validation (after repair) and renders as a plausible critter via the Phase 2
  path.
- Personality differences produce visibly different prompts (spot-check the
  mapping output).

**Implementation Note**: After completing this phase and all automated
verification passes, pause for human confirmation before proceeding.

---

## Phase 4: Wire Into Hatch + End-to-End

### Overview

Insert the blocking generation call into hatch, persist the spec, and prove the
full birth→render path, including the block-on-failure contract.

### Changes Required:

#### 1. Factory seam + blocking call

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Add a `critterImageGenFactory = critterImageServiceFor` seam (next to
`hatchLlmServiceFactory`, `:702`) and call it in `hatch()` before the
transaction, after the narrative call. On throw, map to a `CreatureHatchError`.

**Contract**: New seam field; new call between `:70` and `:74`:
`final spec = await critterImageGenFactory(session).generateImage(session, _imageRequest(name, mods));`
wrapped so failure raises `CreatureHatchError`. Add a reason
`imageUnavailable` to `creature_hatch_error_reason.spy.yaml` (or reuse
`narrativeUnavailable` — prefer a distinct reason for diagnosability).

#### 2. Persist the spec

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Set `image: spec` on the `Creature(...)` insert inside the
transaction (`:77-84`).

**Contract**: Add `image: spec` to the constructor; everything else unchanged.

#### 3. Tests

**File**: `tamagotchi_server/test/creature/creature_endpoint_test.dart`

**Intent**: Cover the two contracts: a successful hatch returns a `CreatureStatus`
whose `creature.image` is non-null and valid; a generation failure blocks the
hatch with `imageUnavailable` and writes no rows.

**Contract**: Reassign `critterImageGenFactory` to a fake (valid spec) and to a
throwing fake, each with `addTearDown` restore (copy `:119-120`). Assert empty
creature/personality/journal tables on the failure path.

### Success Criteria:

#### Automated Verification:

- Hatch integration tests pass: `dart test test/creature/creature_endpoint_test.dart`
- Full server suite passes: `dart test`
- Flutter suite passes: `flutter test`
- Analyze + format clean in both packages

#### Manual Verification:

- Hatching a new creature in the running app shows a unique pixel critter at
  birth, rendered crisp.
- Inducing a generation failure (e.g. revoke key / force-throw fake) blocks the
  hatch with no half-written creature.
- A second hatch produces a visibly different critter.

**Implementation Note**: After completing this phase and all automated
verification passes, pause for human confirmation before proceeding.

---

## Testing Strategy

### Unit Tests:

- `critter_spec_validator`: row count/length, palette membership, hex validity,
  repair idempotence (repair of valid = identity; repair of broken = valid).
- `critter_image_prompt` mapping: distinct mods → distinct descriptors; message
  shape includes the full-grid dims restatement.
- Compositor: full-grid geometry (`base[r][c]` → pixel `(c, r)`), transparent
  handling.

### Integration Tests:

- Hatch success: `creature.image` non-null and validator-clean (stub spec).
- Hatch block-on-failure: throwing image fake → `CreatureHatchError`, no rows
  (mirrors the existing narrative-failure test).

### Manual Testing Steps:

1. Hatch a creature in the app; confirm a crisp, symmetrical critter renders.
2. Hatch again; confirm the critter differs.
3. View a pre-existing (pre-feature) creature; confirm no layout break with a
   null image.
4. Force a generation failure; confirm the hatch fails cleanly.

## Performance Considerations

Hatch now makes **two** sequential blocking external calls (narrative + image),
roughly doubling worst-case birth latency and failure probability. No timeout
exists on the Mistral call today (`mistral_client.dart`); consider adding a
modest timeout to both calls so a hung request fails fast rather than hanging the
birth. The spec is ~1–2 KB of `json`; negligible storage/transfer.

## Migration Notes

One additive, nullable `json` column (`creature.image`). Existing creatures get
`null` and render without a sprite. No data backfill. Apply with
`serverpod run start` (not `--apply-migrations`).

## References

- Frame brief: `context/changes/generate-creature-image/frame.md`
- Research (jsonb): `context/changes/generate-creature-image/research.md`
- Hatch flow: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:28-139,685-702`
- Structured output precedent: `tamagotchi_server/lib/src/llm/mistral_client.dart:51-71,95-136`
- Service seam + stub: `tamagotchi_server/lib/src/llm/llm_service.dart:87-113`
- json-column precedent: `tamagotchi_server/lib/src/creature/journal_entry.spy.yaml:21`
- Render slot + provider: `tamagotchi_flutter/lib/creature/creature_view.dart:32-181`, `creature_provider.dart:15-22`
- Test seam pattern: `tamagotchi_server/test/creature/creature_endpoint_test.dart:119-120`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 0: Generation Probe

#### Automated

- [x] 0.1 Probe script runs without error against the dev key — 1f92481

#### Manual

- [x] 0.2 Grids visibly varied and non-degenerate across ~10 seeds — 1f92481
- [x] 0.3 Structured output parses cleanly at 32×16 (acceptable failure rate) — 1f92481
- [x] 0.4 Size decision recorded (proceed at 32×32, or fall back) — 1f92481

### Phase 1: Data Model + Validator

#### Automated

- [x] 1.1 `serverpod generate` is clean
- [x] 1.2 Migration created and applies via `serverpod run start`
- [x] 1.3 Validator unit tests pass
- [x] 1.4 Analyze + format clean

#### Manual

- [ ] 1.5 `creature.image` nullable json column present; existing creatures unaffected

### Phase 2: Flutter Render Path

#### Automated

- [ ] 2.1 Compositor + widget tests pass
- [ ] 2.2 Analyze + format clean

#### Manual

- [ ] 2.3 Hand-written spec renders crisp, symmetrical at 128px
- [ ] 2.4 Null-image creature renders with no layout break

### Phase 3: Server Generation Pipeline

#### Automated

- [ ] 3.1 Service + prompt + mapping unit tests pass
- [ ] 3.2 Stub spec passes the validator (asserted)
- [ ] 3.3 Analyze + format clean

#### Manual

- [ ] 3.4 Real-key generation returns a validator-clean, renderable spec
- [ ] 3.5 Personality differences produce visibly different prompts

### Phase 4: Wire Into Hatch + End-to-End

#### Automated

- [ ] 4.1 Hatch integration tests pass (success + block-on-failure)
- [ ] 4.2 Full server suite passes
- [ ] 4.3 Flutter suite passes
- [ ] 4.4 Analyze + format clean in both packages

#### Manual

- [ ] 4.5 New creature shows a unique crisp critter at birth
- [ ] 4.6 Generation failure blocks the hatch with no half-written creature
- [ ] 4.7 A second hatch produces a visibly different critter
