# Auto-hooks — Plan Brief

> Full plan: `context/changes/auto-hooks/plan.md`
> Research: `context/changes/auto-hooks/research.md`

## What & Why

Wire two hooks that enforce the same gates CI already runs. A Claude Code `Stop` hook applies `dart format` silently and runs `dart analyze` / `flutter analyze` at the end of every turn — blocking the turn on errors so Claude fixes them before reporting done. A Lefthook pre-push gate runs all tests (Flutter + server integration) on every `git push`. Both hooks eliminate the category of "CI fails on a commit that felt done locally."

## Starting Point

No `.claude/settings.json` exists. No Lefthook binary is installed. CI already has four workflows (format, analyze, flutter, tests) whose commands define exactly what the hooks must replicate — the credentials and commands are already committed in `tests.yml`.

## Desired End State

Dart files are always formatted after a Claude turn. Any analyze error surfaces as Claude feedback and is fixed before the turn closes. Every push runs the full test suite; bypassing requires an explicit `LEFTHOOK=0` flag. A freshly built devcontainer has Lefthook on PATH and `lefthook install` has run.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|---|---|---|---|
| Hook event | `Stop` (not `PostToolUse`) | Runs once per turn on the whole project — matches CI scope and avoids per-file overhead | Research |
| Format behavior | `dart format .` (apply in place) | Silent, idempotent — no agent loop needed for mechanical formatting | Research |
| Analyze command (flutter) | `flutter analyze` | Matches `flutter.yml` CI gate exactly; catches Flutter-specific lint rules `dart analyze` misses | Plan |
| Integration tests | Always run, never opt-in | Pre-push gate must match CI; `docker compose up -d` is idempotent so the DB cost is already paid | Research |
| Lefthook placement | Dockerfile root `RUN` block | Same pattern as `postgresql-client` — system binary, available to `vscode` user on PATH | Research |
| Hook config location | New committed `settings.json` | Team-shared hook config; `settings.local.json` stays as personal overrides | Research |

## Scope

**In scope:**
- `.claude/settings.json` — Stop hook registration
- `.claude/hooks/dart-format-analyze.sh` — format + analyze script
- `.devcontainer/Dockerfile` — Lefthook binary installation
- `.devcontainer/devcontainer.json` — `lefthook install` in postCreateCommand
- `lefthook.yml` — pre-push gate config
- `.gitignore` — `lefthook-local.yml` entry

**Out of scope:**
- Per-file `PostToolUse` hooks
- Opt-in integration test bypass in Lefthook
- Any CI pipeline changes

## Architecture / Approach

Claude Code's `Stop` event fires once when Claude finishes a turn. The hook script runs `dart format` (always exits 0, no output) then `dart analyze` / `flutter analyze` (captures exit codes, outputs on failure). Exit 2 blocks the turn; Claude receives the stdout as feedback and starts a fix sub-turn. Lefthook is a standalone Go binary that installs thin stubs in `.git/hooks/`; `lefthook.yml` drives the `pre-push` hook with `piped: true` for sequential, fail-fast execution.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|---|---|---|
| 1. Claude Code Stop Hook | Turn-end format + analyze gate; error loop | `flutter analyze` invocation must use path arg correctly |
| 2. Lefthook Pre-Push Gate | Full test suite runs before every push | Dockerfile rebuild needed for Lefthook in new containers; manual `curl` install for current container |

**Prerequisites:** Docker is running (for the pre-push integration test verification)
**Estimated effort:** ~1 session across 2 phases

## Open Risks & Assumptions

- `test/llm/` and `test/creature/` directories are not tagged `integration` in `dart_test.yaml` but may hit the DB. Running full `dart test` (no tag filter) covers them regardless — the risk is only if they need DB and the DB isn't up. Since `start-test-db` runs first, this is mitigated.
- Dockerfile change requires container rebuild for `lefthook` to be on PATH in new devcontainers. The plan includes a manual `curl` install step for the current container.

## Success Criteria (Summary)

- A Claude turn that produces analyze errors does not complete silently — Claude receives the output and fixes the code.
- `git push` is blocked when any test fails; passes when all tests are green.
- A new devcontainer has `lefthook version` on PATH and `.git/hooks/pre-push` wired after `postCreateCommand`.
