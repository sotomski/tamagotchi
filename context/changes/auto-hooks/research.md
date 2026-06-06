---
date: 2026-06-06T00:00:00+00:00
researcher: Claude (claude-sonnet-4-6)
git_commit: 346a1236f9cd0bd1b5871fd9636828cbcdf7138c
branch: main
repository: nabrudno
topic: "Claude Code write/edit hook (dart format + analyze) and Lefthook pre-push test gate"
tags: [research, hooks, claude-code, lefthook, dart-format, dart-analyze, pre-push, testing]
status: complete
last_updated: 2026-06-06
last_updated_by: Claude (claude-sonnet-4-6)
---

# Research: Claude Code write/edit hook + Lefthook pre-push gate

**Date**: 2026-06-06
**Researcher**: Claude (claude-sonnet-4-6)
**Git Commit**: 346a1236f9cd0bd1b5871fd9636828cbcdf7138c
**Branch**: main
**Repository**: nabrudno

## Research Question

Add two hooks to the project:
1. A **Claude Code PostToolUse hook** that runs `dart format` and `dart analyze` whenever Claude writes or edits a `.dart` file — so formatting and analysis errors are caught immediately and GH workflows stay green.
2. A **Lefthook pre-push hook** that runs all unit tests (Flutter + server) before any `git push`, with integration tests as an opt-in gate.

## Summary

Both hooks are straightforward to implement with no blockers:

- **Claude Code hook**: Add a `hooks.PostToolUse` entry to a new `.claude/settings.json` (project-level, committed). A small shell script reads the written file's path from stdin JSON, skips non-`.dart` files, runs `dart format` on that file, then runs `dart analyze` on the owning package directory. The existing `settings.local.json` has no hooks section — safe to introduce `settings.json` alongside it.

- **Lefthook**: The right tool for this project (no Node.js, single Go binary). Install via APT in the devcontainer or homebrew. A committed `lefthook.yml` drives the pre-push hook: Flutter tests first, then server unit tests, then server integration tests opt-in via `RUN_INTEGRATION=1`. Run `lefthook install` once per clone (should go in `devcontainer` postCreateCommand).

One meaningful design choice: `dart analyze` on every Write/Edit fires synchronously in Claude's tool loop — it takes ~2–5 s on this codebase. This is acceptable as it prevents the Format/Analyze CI failures documented in the lessons. If it proves too slow, the analyze step can be deferred to the pre-push gate instead.

## Detailed Findings

### 1. CI Workflows — What the Hooks Must Replicate

Four CI workflows exist under `.github/workflows/`:

| File | Package dir | Commands |
|------|-------------|----------|
| `format.yml` | `tamagotchi_server/` | `dart format --set-exit-if-changed .` |
| `analyze.yml` | `tamagotchi_server/` | `dart analyze --fatal-infos` |
| `flutter.yml` | `tamagotchi_flutter/` | `flutter pub get`, `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test` |
| `tests.yml` | `tamagotchi_server/` | `docker compose up -d`, `dart pub get`, `serverpod generate`, `dart test` |
| `deploy.yml` | — | Triggers after Tests; scloud deploy |

**Key env vars in `tests.yml`:**
```
SERVERPOD_PASSWORD_database: CDm3BOYJ8Z4lhCj_Wvzum3UPoMHF2NVU
SERVERPOD_DATABASE_HOST: localhost
SERVERPOD_DATABASE_PORT: 9090
```

The Format and Analyze CI failures have already bitten this project (Lesson: "Run `dart format` before committing — the Format CI gate is `--set-exit-if-changed`"). The Claude Code hook directly addresses that root cause.

### 2. Existing Claude Code Settings

**File**: `.claude/settings.local.json`

Currently holds only `permissions.allow` and `enabledMcpjsonServers`. **No `hooks` section.** No `settings.json` exists at project level — we need to create one.

```jsonc
// .claude/settings.local.json (excerpt)
{
  "permissions": {
    "allow": [/* existing allowlist */]
  },
  "enabledMcpjsonServers": ["context7"]
}
```

Hooks belong in **project `.claude/settings.json`** (committed, shared) — not in `settings.local.json` which is personal/local. Claude Code merges both files: `settings.json` for team rules, `settings.local.json` for personal overrides.

### 3. Claude Code Hook — Configuration Format

**Hook event: `Stop`** (not `PostToolUse`). Fires once when Claude finishes a turn — after all writes and edits are done. This is better than per-file `PostToolUse` because it runs once per turn, operates on the full package, and can block the turn end to trigger an auto-fix loop.

**Two distinct roles:**
- **`dart format .`** — silently rewrites files in place across both packages. Always exits 0. No agent involvement; formatting is mechanical and idempotent.
- **`dart analyze`** — reports errors to stdout. If errors exist, hook exits 2, blocking the turn end. Claude reads the output and fixes the issues. Loop repeats until analyze is clean.

```json
// .claude/settings.json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/dart-format-analyze.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

`Stop` hooks have no `matcher` (no tool to match against). `timeout: 60` gives analyze enough time on a cold run.

**How exit codes work for `Stop`:**
- Exit 0 → turn ends normally.
- Exit 2 → blocks the turn; Claude sees the hook's stdout as feedback and starts a new sub-turn to address it.

**Hook script draft** (`.claude/hooks/dart-format-analyze.sh`):
```bash
#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
SERVER="$PROJECT_ROOT/tamagotchi_server"
FLUTTER="$PROJECT_ROOT/tamagotchi_flutter"

# Format silently — rewrites in place, always succeeds.
dart format "$SERVER" > /dev/null 2>&1 || true
dart format "$FLUTTER" > /dev/null 2>&1 || true

# Analyze — report errors; exit 2 if any found so Claude fixes them.
server_out=$(dart analyze --fatal-infos "$SERVER" 2>&1)
flutter_out=$(dart analyze "$FLUTTER" 2>&1)

server_ok=$?; flutter_ok=$?

if [[ $server_ok -ne 0 || $flutter_out == *"error"* ]]; then
  echo "=== dart analyze: tamagotchi_server ==="
  echo "$server_out"
  echo "=== dart analyze: tamagotchi_flutter ==="
  echo "$flutter_out"
  exit 2
fi
```

**Loop termination:** `dart format` is idempotent — it never triggers a second cycle. `dart analyze` errors are finite; Claude fixes them and the hook exits 0. The only infinite-loop risk is an unfixable analyze error (e.g. a broken pub dependency), which Claude would surface rather than loop on.

**Generated code:** `lib/src/generated/` and `lib/src/protocol/` are excluded from the analyzer via `analysis_options.yaml`, so `dart analyze` ignores them automatically. `dart format` running on them is harmless (they're already formatted by codegen).

### 4. Test Structure — What Lefthook Runs

**Flutter tests** (`tamagotchi_flutter/test/`):
```
test/
  app/   app_router_redirect_test.dart
  home/  home_screen_test.dart
  creature/  creature_view_test.dart
```
No external dependencies. `flutter test` in `tamagotchi_flutter/` runs them all.

**Server tests** (`tamagotchi_server/test/`):
```
test/
  unit/        feed_service_test.dart
  integration/ greeting_endpoint_test.dart, feed_endpoint_test.dart
  llm/         creature_prompt_test.dart, feed_copy_test.dart, llm_service_test.dart
  creature/    creature_service_test.dart, creature_endpoint_test.dart
  helpers/     scripted_random.dart
```

- `test/unit/` — no DB, safe for pre-push.
- `test/integration/` — needs Postgres on port 9090 (`postgres_test` container from `docker-compose.yaml`).
- `test/llm/` and `test/creature/` — unclear DB dependency; likely integration-level. Play safe and include in the DB-gated group.

`dart_test.yaml` in `tamagotchi_server/` tags tests as `integration: {}`. This means `dart test --tags integration` / `dart test --exclude-tags integration` can be used to select layers.

**Decision: all tests always run on every push (including integration).** Developers must have `docker compose up -d` running in `tamagotchi_server/` before pushing. The Lefthook pre-push hook starts the test compose stack itself via `docker compose up -d` so it's idempotent (no-op if already running).

### 5. Lefthook — Installation and Configuration

**Installation — goes in `.devcontainer/Dockerfile`**, alongside Flutter, Serverpod CLI, and scloud CLI. The existing `RUN apt-get ...` block runs as root; Lefthook is a standalone binary that can be downloaded in the same root layer:

```dockerfile
# .devcontainer/Dockerfile (add to existing apt-get RUN block)
ARG LEFTHOOK_VERSION=2.1.9

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl git unzip xz-utils zip libglu1-mesa ca-certificates postgresql-client \
    && curl -sL "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_Linux_x86_64" \
         -o /usr/local/bin/lefthook \
    && chmod +x /usr/local/bin/lefthook \
    && rm -rf /var/lib/apt/lists/*
```

This mirrors how `postgresql-client` is installed — system binary, available to the `vscode` user on `$PATH` without any pub activation.

**`lefthook install`** creates thin stubs in `.git/hooks/` (e.g. `pre-push`) that delegate to `lefthook run pre-push`. Must run once per clone. Update `postCreateCommand` in `devcontainer.json`:

```jsonc
// .devcontainer/devcontainer.json
"postCreateCommand": "flutter doctor || true && lefthook install"
```

**Complete `lefthook.yml`** (all tests, always — no opt-in gate):
```yaml
min_version: "2.0.0"

pre-push:
  piped: true  # sequential; stop on first failure

  commands:
    flutter-tests:
      priority: 1
      root: "tamagotchi_flutter/"
      run: flutter test
      fail_text: "Flutter tests failed. Fix before pushing."

    start-test-db:
      priority: 2
      root: "tamagotchi_server/"
      run: docker compose up -d
      fail_text: "Could not start test database."

    server-tests:
      priority: 3
      root: "tamagotchi_server/"
      env:
        SERVERPOD_PASSWORD_database: "CDm3BOYJ8Z4lhCj_Wvzum3UPoMHF2NVU"
        SERVERPOD_DATABASE_HOST: "localhost"
        SERVERPOD_DATABASE_PORT: "9090"
      run: dart test
      fail_text: "Server tests failed. Fix before pushing."
```

**Developer workflows**:
```bash
# Normal push (all tests run):
git push

# Emergency bypass (use sparingly):
LEFTHOOK=0 git push
# or:
git push --no-verify
```

The `lefthook.yml` is committed. `.git/hooks/pre-push` is not (generated per clone by `lefthook install`). Add `lefthook-local.yml` to `.gitignore` for personal overrides.

### 6. Devcontainer Wiring Summary

| What | Where | Change |
|------|-------|--------|
| Lefthook binary | `.devcontainer/Dockerfile` root `RUN` block | Add curl download + chmod |
| Wire git hooks | `.devcontainer/devcontainer.json` `postCreateCommand` | Append `&& lefthook install` |
| Hook config | `lefthook.yml` (repo root, committed) | New file |
| gitignore | `.gitignore` | Add `lefthook-local.yml` |

## Code References

- `.github/workflows/format.yml` — `dart format --set-exit-if-changed .` (server)
- `.github/workflows/analyze.yml` — `dart analyze --fatal-infos` (server)
- `.github/workflows/flutter.yml` — `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`
- `.github/workflows/tests.yml:12-19` — DB env vars for CI
- `.claude/settings.local.json` — existing permissions; no hooks section yet
- `tamagotchi_server/dart_test.yaml` — `tags: integration: {}` (used by `--tags`/`--exclude-tags`)
- `tamagotchi_server/docker-compose.yaml` — `postgres_test` service on port 9090

## Architecture Insights

1. **Two settings files coexist**: `settings.json` (team, committed) and `settings.local.json` (personal, gitignored). Hooks go in `settings.json`; permissions can stay in `settings.local.json` or be moved to `settings.json` for team sharing.

2. **Generated code must be excluded from the hook**: `lib/src/generated/` (server) and `lib/src/protocol/` (client) are codegen output — the analyzer excludes them per config. The hook script must also skip them to avoid spurious format noise.

3. **Integration test DB password exposure**: The CI workflow commits the test DB password in plain text (`tests.yml:16`). This is an existing pattern — the test password is considered non-sensitive (throwaway test infra). The Lefthook `env:` block replicates this. Do NOT use the production password.

4. **`piped: true` + `priority:` vs `parallel: false`**: Lefthook's `piped: true` makes commands sequential AND stops on first failure, respecting `priority:` ordering. This is the right choice for a test gate: fail fast, don't wait for Flutter tests to finish before reporting a server failure.

5. **`dart analyze` scope**: Running `dart analyze <package_root>` (not `dart analyze <file>`) is important. `dart analyze single_file.dart` checks only that file's direct errors; the CI gate checks the whole package. The hook should match CI behavior.

6. **LLM and creature tests**: `test/llm/` and `test/creature/` test directories are at the same level as `test/integration/` but are not tagged with the `integration` tag (per `dart_test.yaml`). Verify before finalising the Lefthook config whether these hit the DB. If they do, tag them `integration` in test files or wrap them in an opt-in command.

## Historical Context

- `context/foundation/lessons.md` — "Run `dart format` before committing — the Format CI gate is `--set-exit-if-changed`": this lesson is the direct motivation for the Claude Code hook. Several S-03 phase commits landed unformatted; the hook automates the fix.

## Open Questions

1. **`test/llm/` and `test/creature/` DB dependency**: Do these test directories hit the DB? The `dart_test.yaml` only tags `integration:` — the `test/llm/` and `test/creature/` directories may need the DB but aren't tagged. Running full `dart test` in the Lefthook gate covers them regardless. A quick read of one file would clarify whether the `integration` tag needs widening.

**Resolved:**
- ~~Analyze performance~~ → **Decision: `Stop` hook runs once per turn (not per Write/Edit), so performance is not a concern.**
- ~~Opt-in integration tests~~ → **Decision: always run all tests.**
- ~~Lefthook binary placement~~ → **Decision: `.devcontainer/Dockerfile` root RUN block (same pattern as postgresql-client).**
- ~~`settings.json` vs `settings.local.json` for hooks~~ → **Decision: new committed `settings.json` for hooks; existing `settings.local.json` left untouched.**
- ~~`--fatal-infos` parity~~ → **Decision: `dart format .` applies silently; `dart analyze --fatal-infos` (server) and `dart analyze` (flutter) match CI exactly. No agent loop for formatting.**
