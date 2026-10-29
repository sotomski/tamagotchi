---
project: AI-Tamagotchi
deployed_at: 2026-05-23
platform: Serverpod Cloud (scloud)
scloud_project_id: tamagotchi
scloud_region: eu-central-1 (Neon Postgres; scloud auto-assigned)
public_domains:
  api: https://tamagotchi.api.serverpod.space
  insights: https://tamagotchi.insights.serverpod.space
  web: https://tamagotchi.serverpod.space
db:
  provider: Neon Postgres (managed by scloud)
  host: ep-rapid-wave-alrwaeys-pooler.c-3.eu-central-1.aws.neon.tech
  port: 5432
  name: default
  ssl: required
  pgvector_verified: true (per scloud db connection success + Insights data observed)
baseline_build_ids:
  local_first_deploy: 949ad516-5174-4ef7-a69c-46022fcdf6ab  # 2026-05-23 11:35-11:39, from devcontainer
  cd_first_deploy: aabb9020-9fa2-4bca-ba9f-667288f7426f      # 2026-05-23 12:48-12:52, from GitHub Actions
ci_provider: GitHub Actions
ci_default_flow: auto-deploy-on-merge (workflow_run after Tests on main + workflow_dispatch)
---

# First Deployment — Audit Trail

This document is the persisted artifact of `/home/vscode/.claude/plans/let-s-perform-our-first-polymorphic-snowglobe.md` after a successful end-to-end first deploy + CD wiring on 2026-05-23. The agent-level plan is at the path above; this file captures what actually happened, deviations from the plan, status per phase, and the baselines downstream sessions can reference.

## Outcome

- **API live**: https://tamagotchi.api.serverpod.space (HTTP 200 GET, health-check response)
- **Flutter web client live**: https://tamagotchi.serverpod.space/app/ (HTTP 200, `application/wasm` MIME confirmed on `main.dart.wasm`)
- **DB integration verified**: scloud `db connection` returns Neon Postgres credentials; runtime data observed via scloud Insights console
- **CI**: 4 workflows (Analyze, Format, Flutter, Tests) green on `main`
- **CD**: `deploy.yml` fires automatically on `workflow_run` after Tests success on `main`; manual `workflow_dispatch` also available
- **Two successful baseline builds** captured for rollback (see frontmatter)

## Phase-by-phase status

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | Host: mint scloud + GitHub tokens | ✅ completed | User minted both on host. SERVERPOD_CLOUD_TOKEN via `scloud auth create-token`; fine-grained GitHub PAT scoped to `sotomski/tamagotchi` with Contents+PR+Workflows+Actions+Secrets perms. User renamed `GITHUB_TOKEN` → `TAMAGOTCHI_GITHUB_TOKEN` on host to avoid collision. |
| 1 | Devcontainer wiring | ✅ completed with deviation | Plan was `${localEnv:...}` passthrough via `devcontainer.json` `remoteEnv`. **devpod doesn't reliably resolve `${localEnv:...}`** — discovered through two failed rebuilds. **Actual fix**: env-var passing via `docker-compose.yml`'s `environment:` block (inherits from compose's calling shell). `devcontainer.json` carries only the `github-cli` feature install; tokens flow `host shell → devpod → docker compose → container`. Resulting container env: `SERVERPOD_CLOUD_TOKEN` (same name), `GH_TOKEN` (from host `TAMAGOTCHI_GITHUB_TOKEN`). |
| 2 | Preflight | ✅ completed | scloud v0.29.0 confirmed. `scloud --help` and `scloud deploy --help` captured. |
| 3 | Image hygiene | ✅ completed | Created `.dockerignore`, `.scloudignore` at `tamagotchi_server/`. **Discovered**: scloud's `.scloudignore` syntax does NOT honor trailing slashes for directory patterns — `test/` doesn't work, `test` does. Server-level `.scloudignore` is the one that takes effect for upload (the workspace-level one auto-created by `scloud project link` is informational). `serverpod run flutter_build` refreshed `web/app/` with 13 files including `main.dart.wasm`. |
| 4 | scloud launch | ✅ completed with deviation | Plan was first-time `scloud launch`. **A `tamagotchi` project already existed** (created in a prior session, no deploys). Used `scloud project link tamagotchi --dart-version 3.8.0` instead — generates `scloud.yaml` against existing project, no irreversible cloud-side action. |
| 5 | Post-launch config | ✅ completed with deviation | Plan called for filling `production.yaml`'s DB block. **Per user policy**: "I don't want this environment to have credentials to connect to the DB." Result: only the three publicHost values updated (`tamagotchi.{api,insights}.serverpod.space` and `tamagotchi.serverpod.space`). Database block left as placeholder. scloud's runtime injection overrides at deploy time (confirmed via Insights showing data despite placeholder values). |
| 6 | Set production secrets | ✅ completed (no action needed) | `scloud password list` showed all 5 SERVERPOD_PASSWORD_* values are **AUTO (Platform)-managed** by scloud: `database`, `serviceSecret`, `emailSecretHashPepper`, `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`. Zero secrets touched this devcontainer. |
| 7 | First deploy from devcontainer | ✅ completed | `scloud deploy --dry-run --show-files` passed after `.scloudignore` `test/` → `test` fix. `scloud deploy` ran 11:35→11:39. Build ID `949ad516-5174-4ef7-a69c-46022fcdf6ab` is the local baseline. |
| 8 | Verification | ✅ completed with caveat | API GET returns `OK <timestamp>`. Flutter /app/ HTTP 200. WASM MIME `application/wasm` confirmed. **Caveat from boot logs**: `TimeoutException: Failed to acquire pool lock` during migration verification. Initially interpreted as DB config failure; user corrected — Insights confirmed runtime DB connection works; pool-lock timeout was Neon cold-start latency on first connection. Server self-recovered. Watch on second deploy. |
| 9 | Move CI workflows | ✅ completed | `git mv tamagotchi/.github .github`. Set the 4 workflows' `working-directory:` to the server/client package dirs. *(Superseded by the 2026-06 workspace flatten: `.github` and the packages now sit directly under the repo root, so `working-directory:` is `tamagotchi_server` / `tamagotchi_flutter`.)* |
| 10 | Add CD workflow | ✅ completed with rework | First `deploy.yml` used `serverpod/serverpod-cloud-deploy@v1` per third-party docs the user shared. **First CD run failed in 6s**: action repository doesn't exist (verified via `gh search repos --owner serverpod` — closest match is `serverpod_cloud_clients` for Dart, not a GitHub Action). PR #2 replaced the action with inline `subosito/flutter-action` + `dart pub global activate serverpod_cli serverpod_cloud_cli` + `serverpod run flutter_build` + `scloud deploy`. |
| 11 | Add GitHub secret | ✅ completed | User set `SERVERPOD_CLOUD_TOKEN` repo secret themselves (no agent path; strictest separation). |
| 12 | PR for CI/CD changes | ✅ completed | **PR #1**: ci move + initial deploy.yml. Fixed three latent CI bugs uncovered when workflows finally ran: (a) `analyze.yml`/`format.yml` only installed Dart → workspace mode hits `tamagotchi_flutter` requiring Flutter → swapped to `subosito/flutter-action`; (b) `tests.yml` `--quiet-build` flag unsupported on runner's compose → dropped; (c) `tests.yml` used `postgres_test:5432` (Docker DNS) which doesn't resolve on runner host → CI-only env override `SERVERPOD_DATABASE_HOST=localhost`, `SERVERPOD_DATABASE_PORT=9090`. All 4 CI checks green before merge. **PR #2**: the deploy.yml action-fix described in row 10. |
| 13 | Merge | ✅ completed | Both PRs squash-merged with branch deletion. Local `main` synced via `git fetch && git reset --hard origin/main` after each. |
| 14 | Verify CD end-to-end | ✅ completed | PR #2 merge triggered Tests on main → on success `workflow_run` triggered `deploy.yml` → scloud build ran 12:48:43 → 12:52:09 → SUCCESS. Build ID `aabb9020-9fa2-4bca-ba9f-667288f7426f` is the CD baseline. API/Flutter re-verified live after CD deploy with fresh timestamp in response body. |
| 15 | Persist artifact | ✅ completed | This file. |

## Risks observed live (vs. infrastructure.md predictions)

| Risk (lens) | Outcome |
|---|---|
| Docs sparse / 404 on key paths (Devil's advocate) | Confirmed — `docs.serverpod.dev/cloud/` returned 404 on a specific subpath. Worked around by reading Serverpod source from pub cache + searching the web. |
| Multi-port routing ambiguity (this session) | Resolved cleanly — scloud auto-assigns three subdomains, one per port. |
| WASM MIME not served correctly (Unknown unknowns) | Verified correct: `Content-Type: application/wasm` on `main.dart.wasm`. |
| `.scloudignore` ships dev-only files (Unknown unknowns) | Caught by dry-run before deploy. Surface bug: directory patterns need no trailing slash. |
| **NEW** — devpod doesn't resolve `${localEnv:...}` | Not in infrastructure.md's register. Worked around via docker-compose env passthrough. Worth recording as a foundation lesson via `/10x-lesson` if it recurs. |
| **NEW** — `serverpod/serverpod-cloud-deploy` GitHub Action doesn't exist | Not in infrastructure.md's register. Workaround inlined into deploy.yml. Worth recording as a foundation lesson — the user's research source claimed it existed; subsequent verification via `gh search` proved it doesn't. |
| **NEW** — `dart pub get` fails in pub workspaces if any sibling needs Flutter SDK | CI bug surfaced by the workspace migration. Workaround: use `subosito/flutter-action` instead of `dart-lang/setup-dart` everywhere. |
| **NEW** — `test.yaml` `postgres_test:5432` works in devcontainer (compose network) but not on GitHub runner host | CI-only env override applied. test.yaml stays as-is for local dev. |
| **NEW** — Neon cold-start can cause `Failed to acquire pool lock` on first migration verify | Self-recovering, not a deploy blocker. Watch on subsequent deploys for whether it repeats with warm pool. |
| Closed-source CLI: blocking bug (Unknown unknowns) | Did not bite this deploy. Railway runner-up plan unused. |

## What's deployed where

- **Application code on main** is what's running at https://tamagotchi.serverpod.space/app/ and /tamagotchi.api.serverpod.space/. Pushed via PR #2 squash-merge → CD pipeline at 12:48:43 UTC.
- **scloud auto-managed**: DB password, serviceSecret, emailSecretHashPepper, jwtHmacSha512PrivateKey, jwtRefreshTokenHashPepper (per `scloud password list` — all "AUTO (Platform)").
- **scloud auto-injected at runtime**: DB host/port/name/user (per the docs and observed behavior — `production.yaml` placeholders don't break runtime DB integration; Insights confirms data flows).
- **Repo secret** `SERVERPOD_CLOUD_TOKEN` set by user on `sotomski/tamagotchi` repo, scoped to CD use.

## Operating handbook

- **Trigger a deploy**: push to `main`. Tests workflow runs first; on success `deploy.yml` fires automatically. Or trigger manually via GitHub Actions UI ("Run workflow" on `deploy.yml`).
- **Watch a deploy**: `gh run list --workflow=deploy.yml --limit 5`; `gh run watch <id>` to tail.
- **Watch runtime logs**: `scloud log --tail` from `tamagotchi_server/`; or `scloud log --since 1h --limit 200` for history.
- **Roll back**: `scloud deployment list` to find the prior good build ID, then re-deploy that build. **Note**: per `infrastructure.md`, DB migrations are NOT auto-rolled back — a bad migration needs a forward-fix migration.
- **Insights dashboard**: https://console.serverpod.dev/project/tamagotchi/insights
- **scloud project**: project ID `tamagotchi`.

## Follow-ups (deferred from this deploy)

- **Custom domain**: Starter tier is subdomain-only. Growth tier ($58/mo + $49/mo DB) needed for custom domains. Post-MVP.
- **Per-PR preview deploys**: no documented scloud primitive. Workaround would be a second `ai-tamagotchi-staging` project + alternate CD workflow.
- **Consolidate 4 CI workflows into one with `needs` chaining**: Tightens `workflow_run` semantics (deploy only when EVERY check passes, not just Tests). Structural CI refactor; defer.
- **Cache `~/.pub-cache` + Flutter SDK in CI**: Lower run times. Defer.
- **Revisit the migration-verify pool-lock timeout**: if it repeats on multiple deploys, file with Serverpod or tune `maxConnectionCount` / connection timeouts.
