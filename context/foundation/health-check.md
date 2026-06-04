---
project: AI-Tamagotchi
checked_at: 2026-05-21T17:35:00Z
health_status: needs-attention
context_type: brownfield
language_family: dart
stack_assessment_available: true
checks_run:
  - lockfile
  - dependency_audit
  - outdated_deps
  - test_runner
  - ci_cd
  - configuration
audit_findings:
  critical: 0
  high: 0
  moderate: 0
  low: 0
test_runner_detected: true
ci_provider: GitHub Actions
recommended_fixes: 6
---

## Dependency Health

### Lockfile

```
Status: present (pubspec.lock, 39 KB)
Package manager: pub (workspace resolution)
```

Lockfile lives at the workspace root and resolves all three member packages (`tamagotchi_server`, `tamagotchi_client`, `tamagotchi_flutter`). Reproducible builds are guaranteed across local and CI as long as the same SDK version is used everywhere — see the toolchain-drift finding below for the caveat.

### Security Audit

```
Tool: skipped — no built-in audit tool for dart
Summary: 0 CRITICAL, 0 HIGH, 0 MODERATE, 0 LOW (not measured)
Direct vs transitive: n/a
```

The Dart ecosystem does not ship a first-party vulnerability scanner equivalent to `npm audit` or `cargo audit`. `dart pub outdated` reports `isCurrentAffectedByAdvisory` flags for each dependency (none flagged in this run), which is the closest signal available without a third-party tool. **The "0 findings" line above is the absence of a scanner, not the absence of vulnerabilities.**

Recommended external tools:

- **OSV-Scanner** (Google) — `osv-scanner --lockfile pubspec.lock`. Cross-ecosystem CVE coverage; fastest path to a real audit on Dart projects.
- **Snyk** — supports Dart/Flutter via `snyk test` if integrated; surfaces direct + transitive findings with severity scoring.
- **Periodic `dart pub outdated --mode=security`** — Pub's own advisory feed; lightweight, no install needed; rerun monthly.

### Outdated Dependencies

```
Direct dependencies: all up-to-date.
Dev dependencies: 1 minor gap (`test` 1.31.0 → 1.31.1).
Transitive dependencies with major version gaps: 4 (advisory only).
```

Transitive gaps (not directly actionable — bounded by what direct deps request):

- **`hooks`**: 1.0.3 → 2.0.0 (1 major behind; pulled by `serverpod`).
- **`native_toolchain_c`**: 0.17.6 → 0.19.0 (pre-1.0 churn; pulled by build tooling).
- **`sign_in_with_apple`**: 7.0.1 → 8.0.0 (pulled by `serverpod_auth_idp_*`).
- **`analyzer`**: 12.1.0 → 13.0.0 (pulled by serverpod_cli / lint stack).

These will update naturally when `serverpod` itself bumps. No action needed today.

## Test Suite

```
Test runner: detected
Tests found: integration tests (greeting_endpoint_test.dart) on server; default widget_test.dart on Flutter
Test execution: passing (server tests load successfully against the docker-compose Postgres/Redis sidecars; Flutter side untested in this run)
```

**Server** — `tamagotchi_server/`:

```
Configuration: dart_test.yaml + analysis_options.yaml exclusion for test_tools/
Framework: package:test ^1.25.5 + serverpod_test 3.4.8
Layout: test/integration/ (the serverpod-generated test scaffold)
```

The server test runner loads correctly (`dart test -n 'noop'` resolves to "no tests match" — the runner is healthy, the filter just excluded everything). The runner depends on the docker-compose test sidecars being up before `dart test` is invoked.

**Flutter** — `tamagotchi_flutter/`:

```
Framework: flutter_test (SDK-bundled)
Layout: test/widget_test.dart (default Flutter scaffold; no project-specific widget tests yet)
```

The Flutter package has only the default counter-app widget test. As soon as real UI work begins, the agent cannot rely on this as a verification surface.

## CI/CD

```
Provider: GitHub Actions
Configuration: .github/workflows/{analyze,format,tests}.yml
```

| Stage      | Status | Notes                                                          |
|------------|--------|----------------------------------------------------------------|
| Lint       | ✓      | `dart analyze --fatal-infos` (server only)                     |
| Test       | ✓      | `dart test` against docker-compose Postgres/Redis (server only)|
| Build      | ✓      | Implicit via `serverpod generate` step in tests.yml            |
| Type check | ✓      | Same step as lint (`dart analyze` is the type checker for Dart)|
| Security   | ✗      | No audit step (no Dart-native audit tool, see Dependency Health)|

All three workflows scope to `working-directory: tamagotchi_server`. **The Flutter package has no CI coverage** — no `flutter analyze`, no `flutter test`, no web build verification. This is a known gap also flagged in the stack assessment.

A second observation in `tests.yml`: the test-environment passwords are inlined as literal strings in the workflow `env:` block rather than referenced from GitHub Actions secrets:

```yaml
env:
  SERVERPOD_PASSWORD_database: 'CDm3BOYJ8Z4lhCj_Wvzum3UPoMHF2NVU'
  SERVERPOD_PASSWORD_redis:    '9U_IkVlC_6M9-AvhxISKd_F_GZjbNoZi'
```

These are ephemeral test-container credentials — the impact today is bounded — but inlining them in a tracked workflow file sets the wrong precedent and means rotation requires a commit.

## Configuration

### High severity

- **Toolchain version drift across devcontainer / CI / pubspec.** `.devcontainer/Dockerfile` pins Flutter `3.44.0`; `.github/workflows/tests.yml` uses Flutter `3.32.8`; `tamagotchi_*/pubspec.yaml` declare `flutter: ^3.32.0`. The devcontainer is ahead of CI by a full minor version, which means analyzer warnings and lint findings can differ between a learner's local run and a PR build. The Dart SDK is consistently `3.8.0` everywhere, so this is Flutter-specific. **Fix**: pick one of the two — either bump CI to `3.44.0` to match the devcontainer, or pin the devcontainer to `3.32.8`. Coordinate with the user before bumping CI; version bumps can surface new lint rules.

### Medium severity

- **No root `.gitignore`.** *Resolved* — the 2026-06 workspace flatten created a root `.gitignore` covering OS noise (`.DS_Store`), editor scratch, logs, `node_modules/`, `.env*`, and Dart/pub + scloud artifacts. Previously only package-level ignore files (e.g. `tamagotchi_server/.gitignore`) existed and the repo root had none.
- **Plaintext test-credential literals in `tests.yml`.** See CI/CD section above. Bounded impact, poor precedent. **Fix**: move both `SERVERPOD_PASSWORD_*` env values into GitHub Actions repository secrets and reference them as `${{ secrets.SERVERPOD_TEST_PASSWORD_DATABASE }}` / `${{ secrets.SERVERPOD_TEST_PASSWORD_REDIS }}`. Keep the literals in `tamagotchi_server/config/passwords.yaml` (correctly gitignored) for local runs.
- **No Flutter CI coverage.** Already noted under CI/CD; restated here because it is a config gap that compounds with the toolchain drift — without Flutter CI, the version skew is unobservable until a learner notices a local-vs-CI difference manually. **Fix**: add `flutter_analyze.yml` and `flutter_tests.yml` modelled on the existing `analyze.yml` / `tests.yml`, using `subosito/flutter-action@v2` and `working-directory: tamagotchi_flutter`.

### Low severity

- **No `.editorconfig`.** Format consistency relies on `dart format` alone; mixed-editor contributors may see whitespace conventions diverge. **Fix**: drop a minimal `.editorconfig` at the repo root.
- **No `.env.example` / `.env.template`.** Serverpod uses `config/passwords.yaml` instead of `.env`, so this is partially mitigated by `tamagotchi_server/config/passwords.yaml` already documenting the password keys. No action required unless future tooling introduces `.env` files.

## Stack Assessment Cross-Reference

```
Stack assessment: context/foundation/stack-assessment.md
Agent readiness (from stack-assess): ready-with-compensation
```

| Quality Gate / Gap (from stack-assess)                                  | Health-Check Finding                                                                                                              | Status     |
|-------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|------------|
| Gate: typed — pass                                                      | `dart analyze --fatal-infos` enforced in CI; sound null safety on by default                                                       | Confirmed  |
| Gate: convention-based — pass                                           | `lib/src/endpoints/`, `lib/src/protocol/`, `migrations/`, runmode configs all present and conventional                              | Confirmed  |
| Gate: training-data popularity — pass\* (Serverpod partial)              | Health-check cannot test agent priors directly, but the gap is structural — addressed by the M1L4 lesson, not by config changes    | Deferred   |
| Gate: documented — pass                                                 | Official docs accessible via WebFetch; no community-wiki dependency                                                                 | Confirmed  |
| Gap 1: Serverpod-specific patterns shallow in training data             | The recommended CLAUDE.md runtime-conventions block is **not yet pasted** — `CLAUDE.md` still contains only bootstrap meta          | Reinforced |
| Gap 2: No runtime-conventions instruction file                          | Same as above; will be authored properly in agent-onboarding lesson rather than as a partial paste now                              | Reinforced |
| Toolchain version drift (devcontainer 3.44.0 / CI 3.32.8 / pubspec 3.32) | Confirmed live across all three files; promoted here from "note" to a high-severity Category A fix                                  | Reinforced |
| Flutter package has no CI                                               | Confirmed — `analyze.yml`, `format.yml`, `tests.yml` all scope to `working-directory: tamagotchi_server`                            | Reinforced |
| No `scloud` project config on disk                                      | Confirmed — `scloud` CLI is in the devcontainer but no `scloud.yaml` exists; addressed in M1L5                                      | Deferred   |

The two reports agree: the stack itself is in good shape, and the gaps are operational rather than architectural.

## Recommended Fixes

### Fix before agent work (Category A)

### 1. Reconcile the Flutter toolchain version pin

**Impact**: Local (`3.44.0`) and CI (`3.32.8`) run different analyzer/lint versions. A learner can fix lints locally that CI never flagged — or vice versa — and lose time chasing phantom failures. The agent's edits compound this: it will format and lint against whatever version the devcontainer ships.
**Severity**: high
**Effort**: moderate (15–30 min, including a CI run to confirm)
**Fix**:

Pick one of the two and align everything else to it. Two paths:

- **Pin devcontainer down to CI** (lowest risk): edit `.devcontainer/Dockerfile` and change `FLUTTER_VERSION=3.44.0` to `FLUTTER_VERSION=3.32.8`. Rebuild the devcontainer (`Dev Containers: Rebuild Container`).
- **Bump CI up to devcontainer** (modernise): edit `.github/workflows/tests.yml` and change `flutter-version: '3.32.8'` to `'3.44.0'`. Run `dart pub get && dart analyze` locally first to surface any new lint warnings.

After either path, also bump the `flutter: '^3.32.0'` constraints in `tamagotchi_flutter/pubspec.yaml` and `tamagotchi_client/pubspec.yaml` if you chose the upgrade path.

### 2. Add a root `.gitignore`

**Impact**: `.DS_Store` is already untracked in `git status`. Without a root ignore file, every contributor either commits OS noise or curates per-subdirectory ignores. The agent will repeatedly ask whether `.DS_Store` should be staged.
**Severity**: medium
**Effort**: quick (< 5 min)
**Fix**:

Create `/workspaces/nabrudno/.gitignore`:

```
# OS noise
.DS_Store
Thumbs.db

# Editor scratch
*.swp
*.swo
.idea/
.vscode/*.local.json

# Logs
*.log

# Node (for any tooling layered later)
node_modules/

# Local env
.env
.env.local
```

### 3. Move CI test credentials into GitHub Actions secrets

**Impact**: Today's literals are ephemeral test-container passwords, so the blast radius is small. But they are tracked in git history (commit `a73a952`), and the pattern teaches "secrets go in env: blocks," which will be wrong the moment a real credential lands.
**Severity**: medium
**Effort**: quick (< 5 min)
**Fix**:

1. In the GitHub repo settings → Secrets and variables → Actions, create two repository secrets: `SERVERPOD_TEST_PASSWORD_DATABASE` and `SERVERPOD_TEST_PASSWORD_REDIS`. Reuse the existing literal values so the test compose stack still authenticates.
2. Edit `.github/workflows/tests.yml`:

```yaml
env:
  VERSION: '3.4.8'
  SERVERPOD_PASSWORD_database: ${{ secrets.SERVERPOD_TEST_PASSWORD_DATABASE }}
  SERVERPOD_PASSWORD_redis:    ${{ secrets.SERVERPOD_TEST_PASSWORD_REDIS }}
```

3. Open a PR; CI should still go green.

### 4. Add Flutter-side CI coverage

**Impact**: The Flutter package is half the codebase and currently has no analyzer, formatter, or test gate. Combined with the toolchain drift, regressions can land on `main` without surfacing until a learner runs `flutter test` locally.
**Severity**: medium
**Effort**: moderate (15–30 min — modelled directly on the existing server workflows)
**Fix**:

Add `.github/workflows/flutter.yml`:

```yaml
name: Flutter

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.8'  # match the Flutter version chosen in fix #1
      - working-directory: tamagotchi_flutter
        run: flutter pub get
      - working-directory: tamagotchi_flutter
        run: flutter analyze
      - working-directory: tamagotchi_flutter
        run: dart format --set-exit-if-changed .
      - working-directory: tamagotchi_flutter
        run: flutter test
```

Wire format/analyze/test in one job rather than three workflows; the Flutter side has a single package and no need for the server's split.

### 5. Run a real security audit via OSV-Scanner

**Impact**: `dart pub outdated` flagged no advisories, but it only knows about advisories Pub publishes. Cross-ecosystem CVEs (especially anything pulled transitively from native toolchain dependencies) won't surface without a dedicated scanner.
**Severity**: medium
**Effort**: quick (< 5 min for a one-shot run; moderate if you wire it into CI)
**Fix**:

One-shot local run (no install — uses the official container):

```
docker run --rm -v $PWD:/repo ghcr.io/google/osv-scanner:latest \
  --lockfile=/repo/pubspec.lock
```

If clean, optionally add as a CI step using `google/osv-scanner-action@v1`. Treat the result as a periodic check, not a blocker.

### 6. Update `package:test` to 1.31.1 in `tamagotchi_server/pubspec.yaml`

**Impact**: Trivial patch upgrade; mentioned only because `dart pub outdated --no-transitive` flagged it. No security advisory attached.
**Severity**: low
**Effort**: quick (< 5 min)
**Fix**:

```
cd tamagotchi_server
dart pub upgrade test
```

### Addressed in upcoming lessons (Category B)

### Runtime-conventions section in `CLAUDE.md` is missing

**Lesson**: [Agent Onboarding: Agents.md, AI Rules i feedback loops (M1L4)](https://platforma.przeprogramowani.pl/external/10xdevs-3/m1-l4)
**What you'll do there**: Author `CLAUDE.md` (and possibly `AGENTS.md`) with project-specific runtime conventions — Serverpod codegen workflow, endpoint discovery, migration commands, runmode configs, the Flutter ↔ server build coupling. The stack assessment already drafted a ready-to-paste block; agent onboarding will help you place it correctly and iterate on it with feedback loops rather than as a one-shot paste today.

### No `scloud` project configuration on disk

**Lesson**: [Sprint Zero z Agentem: infrastruktura, walking skeleton i pierwszy deploy (M1L5)](https://platforma.przeprogramowani.pl/external/10xdevs-3/m1-l5)
**What you'll do there**: Author the `scloud` project config required for the first Serverpod Cloud deploy, set up environment-specific runmodes for staging vs production, and run the walking-skeleton deploy. The `serverpod_cloud_cli` v0.29.0 is already pre-installed in the devcontainer, so the lesson can focus on configuration and the deploy itself rather than tooling setup.

## Summary

Health status: **needs-attention**

The AI-Tamagotchi project is structurally sound — typed end-to-end, conventional layout, working test runner, lockfile present, CI enforcing analyze/format/test on the server. The gaps are operational: a Flutter toolchain version skew between devcontainer and CI, no CI coverage for the Flutter package, plaintext test credentials in a tracked workflow, no root `.gitignore`, and no security scanner running anywhere. None of these block agent work, but the toolchain drift in particular will cause confusing local-vs-CI divergence the moment Flutter changes start landing.

Next step: address fixes 1–4 above (the medium-and-up Category A items — toolchain reconcile, root `.gitignore`, secrets move, Flutter CI). They are achievable in one focused 45-minute session. Fixes 5 and 6 can wait. Category B gaps (`CLAUDE.md` runtime conventions, `scloud` config) are explicitly out of scope for this lesson and will be authored properly in M1L4 and M1L5 respectively — don't be tempted to stub them now.

## Resolution Log

**Session date**: 2026-05-22
**Driver**: Karol Sotomski (with Claude Code, Auto Mode)

### Fix #1 — Flutter toolchain reconcile — **applied**

**Decision**: Bump CI up to match the devcontainer (modernise path).

**Changes**:

- `.github/workflows/tests.yml` — `flutter-version: '3.32.8'` → `'3.44.0'`
- `tamagotchi_flutter/pubspec.yaml` — `flutter: '^3.32.0'` → `'^3.44.0'`
- `pubspec.lock` — solver bumped the Flutter floor from `>=3.38.4` to `>=3.44.0` automatically; no resolved versions changed

**Verification**: `flutter pub get`, `flutter analyze`, `dart format --set-exit-if-changed .`, and `flutter test` all green at Flutter 3.44.0 locally.

**Rationale**: `flutter analyze` surfaced no new issues at 3.44.0, so the modernise path carried no realised lint cost; the older pin was costing local-vs-CI parity for no gain. Flutter 3.44.0 ships Dart 3.12.0, which is compatible with the existing `sdk: '^3.8.0'` constraint across all three packages — no Dart-side changes needed.

**Caveat for future work**: `analyze.yml` and `format.yml` still independently pin `dart-lang/setup-dart@v1` with `sdk: 3.8.0`. That is now divergent from the Dart 3.12.0 that ships inside Flutter 3.44.0 used by `tests.yml` / `flutter.yml`. The pubspec range covers both, so it's not failing today, but it's a future trip-hazard worth a dedicated fix later.

### Fix #2 — Root `.gitignore` — **applied**

**Decision**: Add minimal repo-root `.gitignore`.

**Changes**:

- `/workspaces/nabrudno/.gitignore` — created with OS noise (`.DS_Store`, `Thumbs.db`), editor scratch (`*.swp`, `*.swo`, `.idea/`, `.vscode/*.local.json`), `*.log`, `node_modules/`, `.env`, `.env.local` patterns

**Verification**: `git status --short` no longer reports `.DS_Store` as untracked.

### Fix #3 — CI test credentials → GitHub secrets — **skipped**

**Decision**: Leave the plaintext `SERVERPOD_PASSWORD_*` literals in `tests.yml` for now.

**Rationale**: Ephemeral test-container credentials with bounded blast radius. Revisit the moment real credentials enter the picture, or as part of the M1L5 deploy-config work where `scloud` runmode secrets land.

### Fix #4 — Flutter CI coverage — **applied**

**Decision**: Single combined `flutter.yml` workflow (option A from the research-informed interview).

**Changes**:

- `.github/workflows/flutter.yml` — created. Single `analyze-test` job using `subosito/flutter-action@v2` with `cache: true`. Steps: `flutter pub get` → `flutter analyze` → `dart format --set-exit-if-changed .` → `flutter test`. Pinned to Flutter `3.44.0` to match Fix #1.
- `tamagotchi_flutter/test/widget_test.dart` — empty stub replaced with a real smoke test that pumps `MyApp` and asserts the `Serverpod Example` home-page title renders.

**Why the smoke test was needed**: the workflow's `flutter test` step exited 79 ("No tests were found") against the original empty stub, which would have failed CI on first push. The smoke test passes locally; CI is now expected to go green. The test deliberately avoids tapping the `Send to Server` button so the global `late final client` (initialised only inside `main()` of `main.dart`) is never read.

**Verification**: full local dry-run of every step the workflow runs — `pub get`, `analyze`, `format` check, `flutter test` — all green from `tamagotchi_flutter/`.

### Fix #5 — Security audit via OSV-Scanner — **skipped**

**Decision**: No scan run today.

**Rationale**: Revisit periodically via `dart pub outdated --mode=security`; no concrete signal yet justifying wiring OSV into CI.

### Fix #6 — `package:test` 1.31.0 → 1.31.1 — **skipped**

**Decision**: Leave the lockfile alone.

**Rationale**: Trivial patch bump with no advisory attached; will roll forward naturally on the next deps refresh.

### Health status after this session

Three of the four Category A fixes are applied (#1, #2, #4). #3 is deliberately deferred. Category B items (`CLAUDE.md` runtime conventions, `scloud` config) remain out of scope until M1L4 and M1L5.

Recommended re-check after the next CI run on `main` to confirm `flutter.yml` lands green and the bumped `tests.yml` still passes. If both go green, the Flutter toolchain drift is fully closed and the Flutter side has parity with the server side's CI gates.
