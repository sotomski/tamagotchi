# Lessons Learned

> Append-only register of recurring rules and patterns. Re-read at start by /10x-frame, /10x-research, /10x-plan, /10x-plan-review, /10x-implement, /10x-impl-review.

## Apply Serverpod migrations via `serverpod run start`, not `--apply-migrations`

- **Context**: Any phase that creates or applies a Serverpod migration locally in `tamagotchi_server/` (the `serverpod generate` → `create-migration` → apply cycle).
- **Problem**: Plans/research keep prescribing `dart bin/main.dart --apply-migrations`, which is not how this project applies migrations and wastes a step.
- **Rule**: To apply pending migrations locally, run `serverpod run start` — it boots the server and applies migrations automatically. Do not use `dart bin/main.dart --apply-migrations`.
- **Applies to**: research, plan, implement
