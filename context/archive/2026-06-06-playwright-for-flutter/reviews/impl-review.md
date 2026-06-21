<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Patrol e2e for Flutter web (M3L4 contract)

- **Plan**: context/changes/playwright-for-flutter/plan.md
- **Scope**: All 6 phases (full plan)
- **Date**: 2026-06-07
- **Verdict**: NEEDS ATTENTION → all 3 warnings RESOLVED 2026-06-20
- **Findings**: 0 critical, 3 warnings, 2 observations

> **Resolution (2026-06-20).** F1, F2, F3 fixed and re-verified end-to-end:
> smoke + persistence patrol tests green (headless Chromium), 15 widget tests,
> 57 server tests, `dart analyze` clean. F4/F5 remain observations (no action).
> Note: verifying the patrol run surfaced a *separate* pre-existing issue — the
> working tree carried a broken `serverpod generate` output that dropped the
> auth-module registration from `protocol.dart` (made the seed's
> `getTableForType(EmailAccount)` null). Parked in `git stash` to run the tests
> against the committed protocol; the user needs to decide whether to discard
> that drift or investigate the regeneration. Unrelated to the three warnings.

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | WARNING |
| Scope Discipline | WARNING |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

**Automated re-run during this review**: server + flutter `dart analyze` clean,
`dart format --set-exit-if-changed` clean, 15 widget tests green (Phase 2 Keys +
Phase 5 binding swap didn't break them), Phase-6 doc greps pass. Browser (patrol)
success criteria were accepted from the `## Progress` ledger — they require a
rebuilt devcontainer + a booted e2e server and are not re-runnable inside a review.

## Findings

### F1 — e2e config override keys only on env flag, not the booted run mode

- **Severity**: ⚠️ WARNING (latent — not currently reachable)
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: tamagotchi_server/lib/server.dart:40-55
- **Detail**: `_e2eConfigOverride()` applies whenever `Platform.environment['TAMAGOTCHI_E2E'] == 'true'`, regardless of the run mode actually booted. It stamps `runMode:'e2e'`, which `_isLocalDevMode` treats as dev — enabling the fixed registration code `'12345678'` + log-only email and rebinding the API to :8080. As shipped this is SAFE: the only caller (pubspec `e2e:` alias) always pairs the flag with `--mode test`, overlaying the hermetic test DB/peppers. But there is no guard that the underlying mode IS test. A stray `TAMAGOTCHI_E2E=true` in a `--mode production`/`staging` boot would silently weaken auth (fixed code, no mailer) against the real DB + peppers. Verified against Serverpod 3.4.8 source: passwords/DB/config load under the real runMode first, the override applies last as a pure transform.
- **Fix**: Gate the override on the loaded run mode too — return the config unchanged unless it is `test`: `return (config) => config.runMode == 'test' ? config.copyWith(runMode: 'e2e', apiServer: ...) : config;` (or assert/throw on a non-test base). Test path unchanged; the prod-weakening footgun is removed.
  - Strength: Closes a production-auth weakening path on a security-sensitive seam; one-line, no behavior change for the real e2e caller.
  - Tradeoff: Minor — a small design choice (return-unchanged vs throw) to settle.
  - Confidence: HIGH — flow traced through serverpod.dart override application order.
  - Blind spot: None significant.
- **Decision**: RESOLVED 2026-06-20 — override now returns the config unchanged unless `config.runMode == 'test'` (server.dart). e2e boot still stamps `e2e` + binds :8080 (verified: `serverpod run e2e` → `runMode: e2e`); a stray flag under prod/staging is now a no-op.

### F2 — Runtime lock file committed to version control

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: .claude/scheduled_tasks.lock (added in commit 99196fd, p3)
- **Detail**: A per-session scheduler lock — `{"sessionId":...,"pid":3351,"acquiredAt":...}` — was committed. It is machine/session-local runtime state, not source, and is not gitignored. Unplanned; unrelated to the e2e work it rode in on.
- **Fix**: `git rm --cached .claude/scheduled_tasks.lock` and add `.claude/scheduled_tasks.lock` to .gitignore.
- **Decision**: RESOLVED 2026-06-20 — untracked via `git rm --cached`; `/.claude/scheduled_tasks.lock` added to `.gitignore` (confirmed by `git check-ignore`).

### F3 — e2e seed not transaction-wrapped → orphan rows on mid-seed failure

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: tamagotchi_server/tool/e2e_seed.dart:114-158
- **Detail**: `_seed` creates an auth user, then a Creature, then a CreaturePersonality as separate writes with no transaction. If any step after the first throws, `tamagotchi_test` is left with a partial fixture (user with no creature, etc.). It self-heals on the next run (the leading `_teardown` clears by email), so a single failed seed just leaks rows until rerun — but the in-process exemplar (`feed_endpoint_test.dart`) relies on `withServerpod` rollback the script can't use.
- **Fix**: Wrap the three inserts in `session.db.transaction(...)` so a mid-seed failure commits nothing.
  - Strength: Removes the only partial-fixture path; matches the atomicity the in-process tests get for free.
  - Tradeoff: Negligible — a few lines, test-only tool.
  - Confidence: HIGH — straightforward ORM transaction wrap.
  - Blind spot: None significant.
- **Decision**: RESOLVED 2026-06-20 — the auth-user create, email-account create, and both ORM inserts now run inside one `session.db.transaction` (all four accept the same `Transaction`). Verified: seed → idempotent re-seed → teardown succeed against `tamagotchi_test`, and the persistence patrol test (which depends on the seed) is green.

### F4 — patrol_cli 4.4.0 vs patrol 4.6.1 skew; unpinned Chromium install

- **Severity**: 🔭 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency / Reliability
- **Location**: .devcontainer/Dockerfile (PATROL_CLI_VERSION=4.4.0); .devcontainer/devcontainer.json (npx playwright install)
- **Detail**: `patrol_cli` is pinned two minors behind the resolved `patrol` package (4.6.1), and `npx --yes playwright install` pulls an ambient Chromium rather than patrol's bundled playwright-core 1.56.0. Both are already DISCLOSED in test-plan.md:123 and tech-stack.md:56, and the toolchain was empirically stabilised at these exact versions (see the patrol-web lesson in lessons.md). This is a note, not a defect: aligning blindly risks regressing a hard-won working setup.
- **Fix**: Leave as-is unless a patrol upgrade is undertaken; if bumped, re-run the smoke + persistence tests to confirm the web bundle still discovers. Optionally pin the Chromium install version.
- **Decision**: PENDING

### F5 — plan.md describes an e2e mechanism that was superseded (not rebuilt)

- **Severity**: 🔭 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Adherence
- **Location**: context/changes/playwright-for-flutter/plan.md (Phase 1 #3/#4; Desired End State; §References)
- **Detail**: The plan specified a `config/e2e.yaml` runmode + an `e2e:` passwords section + `dart bin/main.dart --mode e2e`. None exist — correctly, since Serverpod 3.x has no custom run mode. The implementation instead boots `--mode test` + `TAMAGOTCHI_E2E=true` + a `configOverride` (server.dart) and a `serverpod run e2e` alias. This is good, justified drift, fully documented in code comments and the §6.7 cookbook. Two smaller, equally-benign harness drifts: `e2e_seed.dart` creates the user via the admin `createEmailAuthentication` seam (not the verify-code flow the plan implied), and `helpers/auth.dart` logs in via `client.emailIdp.login` rather than driving `SignInWidget` by text (the widget owns no Keys). Both documented as deliberate; a JWT still issues via the shared pepper. Only cost: the change-local plan.md now misleads a future reader — the canonical doc (test-plan §6.7) is correct.
- **Fix**: Add a one-paragraph "implementation note: e2e realised as a test-mode overlay, not a config/e2e.yaml" addendum to plan.md so it matches what shipped (or accept the drift as recorded in §6.7).
- **Decision**: PENDING
