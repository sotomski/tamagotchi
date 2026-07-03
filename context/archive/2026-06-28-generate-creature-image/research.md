---
date: 2026-06-28T14:33:44Z
researcher: Karol Sotomski
git_commit: 76dad6993ab298a36c1cddb22223fb0b4d8eaeea
branch: feat/generate-creature-image
repository: nabrudno
topic: "Column format for the generated creature image — is JSONB supported by Serverpod?"
tags: [research, codebase, serverpod, database, models, json, jsonb, creature]
status: complete
last_updated: 2026-06-28
last_updated_by: Karol Sotomski
---

# Research: Column format for the generated creature image — is JSONB supported by Serverpod?

**Date**: 2026-06-28T14:33:44Z
**Researcher**: Karol Sotomski
**Git Commit**: 76dad6993ab298a36c1cddb22223fb0b4d8eaeea
**Branch**: feat/generate-creature-image
**Repository**: nabrudno

## Research Question

The feature brief proposes storing the generated pixel-art creature blob in a
**JSONB** column. Find out the actual column format Serverpod uses — **is `jsonb`
supported by Serverpod (3.4.8)?**

## Summary

**No — Serverpod 3.4.8 does not support `jsonb`. It emits plain Postgres `json`
for every serialized-JSON field, and there is no `.spy.yaml` keyword,
annotation, or flag to select `jsonb`.**

- Any complex field type (a nested generated model, `List<T>`, `Map<K,V>`,
  `Set<T>`, `Record`) is serialized to a **`json`** column automatically. This is
  documented default behavior and confirmed empirically in this repo's
  migrations.
- This codebase contains **zero `jsonb` columns** and **zero `ColumnType.jsonb`**
  references — all 7 JSON columns across the schema are `json`.
- Getting `jsonb` specifically (e.g. for GIN indexing / JSON-path queries) is
  possible only via **workarounds** (hand-edited migration SQL, scalar `String` +
  `::jsonb` cast, raw SQL, or a post-migration `ALTER`), all of which risk
  migration-diff drift and are unsupported.

**Implication for this change:** the frame brief's recommendation holds and is
now confirmed — store the creature spec as a **typed nested serializable model**
(e.g. a `CritterSpec` class) nested on `Creature`, which Serverpod will persist
to a **`json`** column. Do not write "JSONB" into the plan; for a ~1–2 KB blob
that is read whole and never queried by JSON path, plain `json` is the correct,
convention-matching choice and needs no workaround.

## Detailed Findings

### Serverpod's documented behavior (3.x)

The version-matched skill and official docs agree:

- Field-type vocabulary in `.spy.yaml` is: `bool`, `int`, `double`, `String`,
  `Duration`, `DateTime`, `ByteData`, `UuidValue`, `Uri`, `BigInt`, generated
  classes/enums/exceptions, `List<T>`, `Map<K,V>`, `Set<T>`, `Record`
  (`.claude/skills/serverpod-models/SKILL.md:21`).
- "Complex types like other models, Lists, or Maps are stored as JSON objects in
  the database by default" — official docs `06-concepts/06-database/02-models.md`
  (Serverpod docs v3.4.0, via context7 `/serverpod/serverpod_docs`). The doc's
  own example annotates such a field `# Stored as a json column`.
- **No type-override mechanism exists.** The per-field modifiers are `!persist`,
  `jsonKey=`, `scope=`, `required`, `relation(...)`, and an experimental
  `column=` — but `column=` overrides the column **name only**
  (`06-concepts/22-experimental.md`), not its SQL type. Nothing changes `json`
  to `jsonb`.
- The only typed escape hatch toward a non-default column type is `Vector(N)`
  (pgvector) — a distinct first-class type, not a route to `jsonb`.

### Empirical confirmation in this repo

Every JSON column emitted by Serverpod here is `json`, never `jsonb`:

- `journal_entry.statDelta` → `"statDelta" json`
  (`tamagotchi_server/migrations/20260621115501267/definition.sql:78`), produced
  by the nested-model field `statDelta: StatDelta?`
  (`tamagotchi_server/lib/src/creature/journal_entry.spy.yaml:21`). The generated
  protocol marks it `columnType: _i2.ColumnType.json`
  (`tamagotchi_server/lib/src/generated/protocol.dart:314`).
- Serverpod framework/auth tables use `json` too: `serverpod_runtime_settings`
  (`logSettings`, `logSettingsOverrides`), `serverpod_auth_*`
  (`scopeNames`, `extraData`) — all `json` in the same `definition.sql`.
- **Grep results:** `0` hits for the literal `jsonb` and `0` for
  `ColumnType.jsonb` anywhere under `tamagotchi_server/` (migrations, generated
  code, and `.spy.yaml`). `ColumnType.json` appears once (the `statDelta` field).

### `StatDelta` is the precedent to follow

`StatDelta` (`tamagotchi_server/lib/src/creature/stat_delta.spy.yaml`, four `int`
fields) is a plain serializable model nested onto a table row and auto-stored as
`json`. A `CritterSpec`-style model (palette + grid rows + size/mirror) nested on
`Creature` is the directly analogous pattern and the convention-matching home for
the generated blob.

### If `jsonb` were ever actually needed (it isn't here)

For completeness — none of these are sanctioned config, all carry drift risk:

- **Hand-edit the generated `migration.sql`** to `jsonb` (+ GIN index); next
  `serverpod create-migration` diffs against `definition.sql` and may try to
  revert the drift — would likely need `serverpod create-repair-migration`
  (`.claude/skills/serverpod-database/SKILL.md:94`).
- **Scalar `String`** holding JSON text, cast `::jsonb` in raw SQL for
  queries/indexes.
- **Raw SQL** for jsonb queries/indexes independent of the declared type
  (`.claude/skills/serverpod-database/SKILL.md:96-98`).
- **Post-migration `ALTER TABLE ... ALTER COLUMN ... TYPE jsonb`** as a separate
  maintenance step — same drift caveat.

The creature blob is read whole at render time and never queried by JSON path, so
none of this is warranted — plain `json` via a typed model is correct.

> Note (project lesson): apply migrations locally with `serverpod run start`, not
> `dart bin/main.dart --apply-migrations` (`context/foundation/lessons.md`). The
> skill text mentions `--apply-migrations`; defer to the project lesson.

## Code References

- `tamagotchi_server/lib/src/creature/journal_entry.spy.yaml:21` — `statDelta: StatDelta?` nested-model field (the json-column precedent)
- `tamagotchi_server/lib/src/creature/stat_delta.spy.yaml` — the nested model that becomes a `json` column
- `tamagotchi_server/migrations/20260621115501267/definition.sql:78` — `"statDelta" json`
- `tamagotchi_server/lib/src/generated/protocol.dart:314` — `columnType: _i2.ColumnType.json`
- `.claude/skills/serverpod-models/SKILL.md:21` — supported field types (no jsonb)
- `.claude/skills/serverpod-database/SKILL.md:90-98` — migrations + raw SQL escape hatches

## Architecture Insights

- Serverpod's column type is **derived from the Dart field type**, not
  developer-selectable. JSON-serializable complex types map to `json`; you control
  the *shape* (via a typed model) but not the *Postgres type variant*.
- The project convention is **typed nested serializable models** for complex data
  — never free-form/untyped JSON. A typed `CritterSpec` keeps client/server in
  sync through the generated RPC client and round-trips cleanly through the `json`
  column, matching `StatDelta`.

## Historical Context (from prior changes)

- `context/changes/generate-creature-image/frame.md` — the frame brief already
  flagged "JSONB column cuts against the storage convention (typed model → `json`
  column)"; this research confirms it definitively and adds the reason: Serverpod
  cannot emit `jsonb` at all in 3.4.8.

## Related Research

- None prior under `context/changes/**/research.md` on this topic.

## Open Questions

- **Schema shape of `CritterSpec`** (which fields, how the grid rows are typed —
  `List<String>` vs a nested structure) is a /10x-plan concern, not a storage-type
  question. Storage type is now settled: a typed model → `json`.
