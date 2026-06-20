# Auto-hooks Implementation Plan

## Overview

Wire two complementary hooks:
1. A **Claude Code `Stop` hook** that silently applies `dart format` and then runs `dart analyze` / `flutter analyze` across both packages at the end of every Claude turn. Format is idempotent and always exits 0; analyze exits 2 on any error, blocking the turn and triggering a Claude fix loop.
2. A **Lefthook pre-push gate** that runs all tests (Flutter + server, including integration) on every `git push`. The gate starts the test database itself (`docker compose up -d`) so it's idempotent.

## Current State Analysis

- No `.claude/settings.json` exists; hooks must be added there (not in `settings.local.json`).
- No Lefthook binary is installed; it must be added to the devcontainer Dockerfile.
- CI gates that this replicates locally: `format.yml` / `flutter.yml` (dart format `--set-exit-if-changed`), `analyze.yml` / `flutter.yml` (`dart analyze --fatal-infos`, `flutter analyze`), `tests.yml` (`docker compose up -d`, `dart test`).
- Test DB env vars are already committed in `.github/workflows/tests.yml` — non-sensitive throwaway credentials; safe to replicate in `lefthook.yml`.

### Key Discoveries

- `settings.local.json` holds permissions + MCP config only — no hooks section. New `settings.json` (committed) is the right home for hooks.
- `dart analyze "$SERVER"` takes a path; `flutter analyze "$FLUTTER"` also accepts a path argument.
- Shell script bug in research draft: `server_ok=$?` must be captured *immediately after* the server analyze command, before the flutter analyze command runs — fixed in Phase 1.
- `flutter analyze` (not `dart analyze`) matches the CI gate for the Flutter package.
- `docker compose up -d` is idempotent — already-running containers are a no-op.
- `lefthook install` must run once per clone; goes in `postCreateCommand`.

## Desired End State

- Every Claude turn ends with both packages formatted and analyzed. Format changes are applied silently. Any analyze error blocks the turn until Claude fixes it.
- Every `git push` runs the full test suite (Flutter + server unit + server integration). Bypassing requires explicit `LEFTHOOK=0 git push` or `--no-verify`.
- A rebuilt devcontainer includes `lefthook` on PATH and runs `lefthook install` automatically.

## What We're NOT Doing

- Not adding per-file `PostToolUse` hooks — `Stop` runs once per turn on the whole project, matching CI scope.
- Not making integration tests opt-in — all tests always run on push.
- Not modifying `settings.local.json` — hooks are a team concern and belong in committed `settings.json`.
- Not adding Flutter format to the hook separately — `dart format "$FLUTTER"` covers the Flutter package just as `dart format "$SERVER"` covers the server.

## Implementation Approach

Phase 1 is self-contained: create two files, verify the hook fires. Phase 2 requires a Dockerfile change (container rebuild needed for Lefthook to be available) and a `lefthook install` run in the current container (install the binary manually for immediate use without rebuilding).

---

## Phase 1: Claude Code Stop Hook

### Overview

Creates `.claude/settings.json` (project-level, committed) registering a `Stop` hook, and the hook script at `.claude/hooks/dart-format-analyze.sh`.

### Changes Required

#### 1. Hook configuration

**File**: `.claude/settings.json`

**Intent**: Register the Stop hook so Claude Code runs the format+analyze script at the end of every turn.

**Contract**:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/dart-format-analyze.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

#### 2. Hook script

**File**: `.claude/hooks/dart-format-analyze.sh`

**Intent**: Apply `dart format` silently across both packages, then run `dart analyze` (server) and `flutter analyze` (flutter). Exit 2 if either analyze returns non-zero so Claude re-enters and fixes the errors.

**Contract**: Script must be executable (`chmod +x`). Captures each analyze exit code immediately after its command (before the next command runs). Uses `${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}` as a fallback for running outside Claude Code. Outputs both packages' analyze results when blocking so Claude has full context.

```bash
#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
SERVER="$PROJECT_ROOT/tamagotchi_server"
FLUTTER="$PROJECT_ROOT/tamagotchi_flutter"

dart format "$SERVER" > /dev/null 2>&1 || true
dart format "$FLUTTER" > /dev/null 2>&1 || true

server_out=$(dart analyze --fatal-infos "$SERVER" 2>&1)
server_ok=$?
flutter_out=$(flutter analyze "$FLUTTER" 2>&1)
flutter_ok=$?

if [[ $server_ok -ne 0 || $flutter_ok -ne 0 ]]; then
  echo "=== dart analyze: tamagotchi_server ===" >&2
  echo "$server_out" >&2
  echo "=== flutter analyze: tamagotchi_flutter ===" >&2
  echo "$flutter_out" >&2
  exit 2
fi
```

### Success Criteria

#### Automated Verification

- `.claude/settings.json` exists and is valid JSON: `python3 -c "import json,sys; json.load(open('.claude/settings.json'))" && echo ok`
- Hook script is executable: `test -x .claude/hooks/dart-format-analyze.sh && echo ok`
- Hook script exits 0 on a clean codebase: `bash .claude/hooks/dart-format-analyze.sh`

#### Manual Verification

- End a Claude turn that edits a `.dart` file; confirm the hook fires and the turn completes (or blocks with analyze output if there are errors).
- Introduce a deliberate analyze error (`var x;` in any `.dart` file), end a turn, confirm Claude receives the analyze output and fixes it, then the next turn completes cleanly.

**Implementation Note**: After automated verification passes, run the manual smoke test before proceeding to Phase 2.

---

## Phase 2: Lefthook Pre-Push Gate

### Overview

Installs Lefthook in the devcontainer Dockerfile, registers it in `postCreateCommand`, commits `lefthook.yml`, updates `.gitignore`, and runs `lefthook install` locally.

### Changes Required

#### 1. Lefthook binary in Dockerfile

**File**: `.devcontainer/Dockerfile`

**Intent**: Add Lefthook as a system binary in the same root `RUN` block as `postgresql-client`, so it's available to the `vscode` user on `$PATH` without any pub activation.

**Contract**: Add `ARG LEFTHOOK_VERSION=2.1.9` before the `RUN` block. Extend the existing `apt-get` `RUN` block to curl the `lefthook_Linux_x86_64` binary from the evilmartians GitHub releases into `/usr/local/bin/lefthook` and `chmod +x` it — all before `rm -rf /var/lib/apt/lists/*`. Do not create a separate `RUN` layer.

#### 2. postCreateCommand update

**File**: `.devcontainer/devcontainer.json`

**Intent**: Wire `lefthook install` so git hooks are installed automatically in every new container.

**Contract**: Append `&& lefthook install` to the existing `postCreateCommand` value:
`"flutter doctor || true && lefthook install"`

#### 3. Lefthook configuration

**File**: `lefthook.yml` (repo root, new file)

**Intent**: Define the pre-push hook that runs Flutter tests, starts the test DB, then runs all server tests — sequential, stop on first failure.

**Contract**:
```yaml
min_version: "2.0.0"

pre-push:
  piped: true

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

#### 4. gitignore update

**File**: `.gitignore`

**Intent**: Allow per-developer Lefthook overrides without committing them.

**Contract**: Append `lefthook-local.yml` to the `.gitignore` file under a `# Lefthook` comment.

#### 5. Install git hooks locally

**Intent**: Wire `.git/hooks/pre-push` in the current working clone without waiting for a container rebuild.

**Contract**: Run `lefthook install` from the repo root. This requires Lefthook on PATH — if not yet available (container not rebuilt), install the binary manually first:
```bash
curl -sL "https://github.com/evilmartians/lefthook/releases/download/v2.1.9/lefthook_Linux_x86_64" \
     -o /usr/local/bin/lefthook && chmod +x /usr/local/bin/lefthook
lefthook install
```

### Success Criteria

#### Automated Verification

- `lefthook.yml` exists and is valid YAML: `python3 -c "import yaml,sys; yaml.safe_load(open('lefthook.yml'))" && echo ok`
- `.git/hooks/pre-push` exists and is executable: `test -x .git/hooks/pre-push && echo ok`
- Lefthook is on PATH: `lefthook version`
- `.gitignore` contains `lefthook-local.yml`: `grep -q lefthook-local.yml .gitignore && echo ok`
- Dockerfile contains the `LEFTHOOK_VERSION` ARG: `grep -q LEFTHOOK_VERSION .devcontainer/Dockerfile && echo ok`

#### Manual Verification

- `LEFTHOOK=0 git push` (or `git push --no-verify`) skips the gate without running tests.
- `git push` (without bypass) runs flutter tests, starts the test DB, and runs server tests before the push proceeds.
- A failing test causes the push to be blocked with the `fail_text` message.

**Implementation Note**: For the manual push test, a test commit to a scratch branch avoids polluting main. Confirm the gate blocks on a known-failing test, then re-verify it passes on clean main.

---

## Testing Strategy

### Automated

- Exit-code checks for both hook files (settings.json validity, script executability, script dry-run on clean tree).
- Lefthook wiring checks (`.git/hooks/pre-push` exists, `lefthook version` succeeds).

### Manual

- End-of-turn analyze loop: introduce a deliberate error, confirm Claude receives it and fixes it, confirm clean turn after fix.
- Pre-push gate: verify bypass (`LEFTHOOK=0`) works, verify blocking (failing test) works, verify passing (all tests green) allows push.

## References

- Research: `context/changes/auto-hooks/research.md`
- CI format gate: `.github/workflows/format.yml`, `.github/workflows/flutter.yml`
- CI analyze gate: `.github/workflows/analyze.yml`, `.github/workflows/flutter.yml`
- CI test gate: `.github/workflows/tests.yml` (DB env vars at lines 12–19)
- Lefthook docs: https://github.com/evilmartians/lefthook

---

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Claude Code Stop Hook

#### Automated

- [x] 1.1 `.claude/settings.json` exists and is valid JSON — b0c8205
- [x] 1.2 Hook script is executable — b0c8205
- [x] 1.3 Hook script exits 0 on clean codebase — b0c8205

#### Manual

- [x] 1.4 Hook fires at end of Claude turn editing a `.dart` file — b0c8205
- [x] 1.5 Deliberate analyze error blocks turn; Claude fixes it; next turn completes clean — b0c8205

### Phase 2: Lefthook Pre-Push Gate

#### Automated

- [x] 2.1 `lefthook.yml` exists and is valid YAML — 9b3ecec
- [x] 2.2 `.git/hooks/pre-push` exists and is executable — 9b3ecec
- [x] 2.3 `lefthook version` succeeds — 9b3ecec
- [x] 2.4 `.gitignore` contains `lefthook-local.yml` — 9b3ecec
- [x] 2.5 Dockerfile contains `LEFTHOOK_VERSION` ARG — 9b3ecec

#### Manual

- [x] 2.6 `LEFTHOOK=0 git push` skips gate — 9b3ecec
- [x] 2.7 Failing test blocks push with `fail_text` message — 9b3ecec
- [x] 2.8 All-green test suite allows push to proceed — 9b3ecec
