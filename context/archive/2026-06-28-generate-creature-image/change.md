---
change_id: generate-creature-image
title: Generate creature image
status: archived
created: 2026-06-28
updated: 2026-07-03
archived_at: 2026-07-03T08:46:06Z
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

### Symmetry requirement dropped (2026-06-28)

Follow-on from the full-grid decision: a bilaterally **symmetric** body is no
longer required. Since the model emits the whole 32×32 square (not a mirrored
half), the Phase 3 generation prompt must **not** ask for symmetry, and
asymmetric critters are accepted as-is. The hand-written Phase 2 test sprite is
symmetric only incidentally. Plan updated (Desired End State, Phase 2/3 blocks,
manual steps, Progress 2.3).

### PIVOT: raster image via Gemini, not char-grid (2026-07-02)

The **entire char-grid approach is abandoned.** After extensive paid probing
(Mistral `mistral-large-latest`; Gemini `2.5-flash` / `2.5-pro` / `3.5-flash`
text models, with up to a 24 576-token thinking budget), the visual ceiling of
palette/ASCII grids proved unacceptable ("terrible" / "quite bad"). Native raster
image models are dramatically better. Probing `gemini-3.1-flash-lite-image` at the
final spec (retro pixel-art sprite, single centred creature, pure-white
background) produced clean, on-brand results at ~PLN 0.5/creature. Video (Veo) was
also explored and ruled out — ~PLN 19/creature, minutes of latency, 9:16/720p.

**Decisions (supersede everything above where they conflict):**

1. **Model** — generate a **raster JPEG** once at hatch via
   **`gemini-3.1-flash-lite-image`** (cheapest image model; confirmed on the dev
   key), raw HTTP like the Mistral path. Style is 100% prompt-driven: retro 16-bit
   pixel-art sprite, ONE creature that **fills the square frame** (body nearly
   touching all four edges, thin uniform white margin), pure-white background.
   Request carries `generationConfig:{responseModalities:['IMAGE'],
   imageConfig:{aspectRatio:'1:1', imageSize:'1K'}}` → **square 1024×1024 JPEG**
   (~390 KB), stored as-is (no downscale; 512 is unsupported natively and the user
   opted to keep 1K).
2. **Storage** — bytes go to **Serverpod `public` DB storage**
   (`session.storage.storeFile`), i.e. the `serverpod_cloud_storage` Postgres
   table (durable on scloud). **NOT** the container filesystem (ephemeral on
   scloud → images would vanish on redeploy).
3. **Serving** — `session.storage.getPublicUrl` yields a **no-auth** URL
   (`<apiPublicHost>/serverpod_cloud_storage?method=file&path=…`) served by
   Serverpod's auto-registered `CloudStoragePublicEndpoint`. No `server.dart`
   change, no new route, no extra infra/secret beyond the API key.
4. **Data model** — `Creature.image: CritterSpec?` (json) →
   **`imageUrl: String?`** (text, the resolved public URL). `CritterSpec` +
   `critter_spec_validator` and the Flutter compositor / `CustomPainter` / grid
   render path are **deleted**; client renders `Image.network(imageUrl)`.
5. **Failure posture — UNCHANGED: block the hatch.** A generation/store failure
   raises `CreatureHatchError(imageUnavailable)` and writes no rows (mirrors the
   narrative call). The hermetic **stub** therefore returns a bundled placeholder
   JPEG so `test`/`e2e` hatches still succeed.
6. **Secret** — new **`geminiApiKey`** (already in dev `passwords.yaml`; needs a
   scloud prod secret). `test`/`e2e` omit it → factory selects the stub.
7. **File key** — `creatures/<creatureId>.jpg`; the creature id is pre-generated
   before the transaction (so it names the blob) and set explicitly on the insert.
   Reset deletes the blob.

Superseded commits (kept in git history; their code is removed by this pivot):
`1f92481` (Mistral probe), `a4fe1dc` (CritterSpec model + validator + json
column), `b06c47b` (Flutter compositor/painter render path). The re-planned phases
in `plan.md` renumber around this pivot.
