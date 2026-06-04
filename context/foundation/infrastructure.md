---
project: AI-Tamagotchi
researched_at: 2026-05-23
recommended_platform: Serverpod Cloud (scloud)
runner_up: Railway
context_type: mvp
tech_stack:
  language: Dart 3.8+
  framework: Serverpod 3.4.8 (server) + Flutter 3.32+ (web client)
  runtime: persistent Dart server process (containerized)
  datastore: Postgres 16 with pgvector extension (no Redis — single-instance deployment)
---

## Recommendation

**Deploy on Serverpod Cloud (scloud).** It is the only first-party deployment target for Serverpod 3.4.8, the developer has stated familiarity with it (interview Q3) and has an active account with free credits, the `scloud` CLI is already pre-installed in the devcontainer (v0.29.0), and the CLI's coverage of deploy / log / secret / domain / DB operations is the cleanest agent surface among the four viable candidates.

The three gating risks the anti-bias cross-check surfaced (private-beta access, pgvector availability, Redis availability) were retired on 2026-05-23 — see the **Resolution Log** below. The remaining items in the risk register are operational unknowns rather than go/no-go gates.

If the platform later becomes unavailable, **Railway** remains the documented runner-up: the Dockerfile drops in unchanged, Postgres + pgvector is a one-click template, the Amsterdam region keeps EU latency low, and the official MCP server is a free agent-integration bonus.

## Platform Comparison

Four platforms were evaluated. Three additional platforms in the default candidate pool (Cloudflare Workers, Vercel, Netlify) were eliminated by a tech-stack **hard filter** before scoring: none of them runs a persistent Dart server process, which Serverpod 3.4.8 requires.

| Platform | CLI-first | Managed / Serverless | Agent-readable docs | Stable deploy API | MCP / Agent integration | Verdict |
|---|---|---|---|---|---|---|
| **Serverpod Cloud (scloud)** | Pass | Pass | **Fail** (sparse docs, 404s on key paths, no llms.txt) | Partial (no `rollback`, no `--json`) | **Fail** (only docs-querying MCP exists; no control-plane MCP) | **Recommended** — wins on first-party fit + Q3 familiarity, conditional on risk mitigation |
| **Railway** | Pass (`--json` everywhere, `-y` non-interactive) | Pass-ish (Postgres + Redis are containerized templates, unmanaged) | Pass (markdown-backed, crawlable) | Pass | **Pass** (official `@railway/mcp-server`, 2025-08-10, destructive ops human-gated) | **Runner-up** |
| **Fly.io** | Pass (`flyctl` deploy/rollback/logs/secrets/scale; `--json` broad) | Pass (Fly MPG with pgvector via `--pgvector` flag) | Pass | Pass | **Pass** (first-class `fly mcp server` + Claude/Cursor/VS Code install) | Third |
| **Render** | Pass (`--output json|yaml|text`) | Pass (Postgres 13–18 + pgvector GA; Key Value / Valkey 8 GA) | Pass | Partial (**no rollback CLI cmd** — dashboard/REST only) | Partial (read-mostly MCP, no deploy trigger) | Fourth |

Legend: Pass / Partial / Fail per the criteria in `references/agent-friendly-criteria.md`.

### Shortlisted Platforms

#### 1. Serverpod Cloud (scloud) — Recommended

The only first-party Dart-server deployment target. The `scloud` CLI exposes a comprehensive surface — `launch`, `deploy`, `deployment {build-log,list,show}`, `project`, `db {connection,user,wipe}`, `domain`, `log` (with `--tail` and ISO-date `--since`/`--until`), `password`, `secret`, `variable` — with `--yes`, `--quiet`, `--verbose`, `--dry-run`, `--show-files` available for non-interactive / agent use. Managed Postgres is bundled (price tier–dependent). Migrations are auto-applied at deploy. The single-process model matches the project's serving topology (Serverpod also serves the Flutter web build at `/app/`).

The gaps are real and documented in the cross-check: the service is in private beta, Redis is BYO per the current docs, pgvector enablement on managed DB is unverified, and the documentation site has 404s on key paths. These collectively form the risk surface — but they are knowable risks with concrete mitigations (see the register), not categorical disqualifiers.

#### 2. Railway

Drop-in for a Dockerfile-based Serverpod deploy. The community **hello-serverpod** template proves the path. Postgres with pgvector is a one-click template (Postgres 16 + pgvector, or 18 + pgvector if needed). Managed Redis is also a template (one community-maintained variant tracks upstream more closely than the official). Amsterdam region for EU users. Official MCP server released 2025-08-10 covers projects, services, deployments, logs, env vars, with destructive ops intentionally human-gated. ~$24–25/mo at MVP scale ($5 Hobby plan absorbs $5 usage credit).

The gap vs. the recommendation is that databases are containerized templates (unmanaged) — backups, upgrades, and tuning are on you. Serverpod runs its own migrations so this is workable, but explicit. Also note: the May 19 2026 8-hour platform-wide outage (GCP auto-suspended Railway's account) is a recent single-cloud blast-radius event.

#### 3. Fly.io

Pay-as-you-go pricing eliminates the hobby/launch subscription tier as of October 2024. A small Serverpod VM is ~$2–3/mo, but Fly Managed Postgres (the GA-but-evolving service, distinct from the unmanaged Stolon-based "Fly Postgres") starts at $38/mo for the Basic tier with pgvector enabled via `--pgvector` at cluster creation. Redis is still BYO via the Upstash integration ($10/mo for the 250 MB plan). Frankfurt and Amsterdam regions available. Persistent processes and WebSockets are well-supported (dedicated Fly proxy doc + Serverpod GitHub discussion #2789).

Fly's first-class MCP server (`fly mcp server`, `fly mcp launch`) with install flags for Claude / Cursor / VS Code / Windsurf is the strongest agent-integration story of the four. The gap vs. Railway: higher base cost (MPG Basic = $38/mo vs. Railway's ~$24 total) and Redis is split out to a separate vendor.

## Anti-Bias Cross-Check: Serverpod Cloud

> **Resolution log — 2026-05-23.** The cross-check below is preserved as the audit trail of what was considered before the decision was finalized. Three of the five Devil's Advocate items were retired the same day by the developer:
>
> 1. **Private-beta access** → **RESOLVED**: the developer holds an active scloud account with free credits.
> 2. **Redis BYO contradiction** → **NOT APPLICABLE**: the project does not use Redis. The MVP runs as a single Serverpod instance with no cross-instance pubsub, no distributed session store, and no distributed rate-limiting needs.
> 3. **pgvector on managed DB** → **RESOLVED**: the developer has previously deployed a RAG workload on scloud and verified pgvector works against scloud's managed Postgres.
>
> Items 4 (sparse docs / 404s) and 5 (thin maturity signals) stand. They are slowdown risks, not gating risks. The Pre-Mortem narrative below is now historical fiction; the failure modes it described required items 1–3 to be real.

### Devil's Advocate — Weaknesses

1. **Private beta, no published GA date.** Pricing-page CTAs are "Join Waitlist" / "Book Demo" — self-serve signup is not available. The originally-promised summer-2024 public-beta and fall-2024 GA both slipped. Status as of 2026-05-23 from GitHub Discussion #2444: "Right now you can sign up to participate in the private beta here." The devcontainer ships the CLI, but CLI access does not imply control-plane access; the project's actual scloud account state needs to be verified before the first deploy is attempted.
2. **Redis story is internally contradictory.** Marketing page says "PubSub & caching works out of the box"; `docs.serverpod.dev/cloud` says Redis "currently requires 3rd party service." For Serverpod 3.4.8's documented Redis dependency, that means standing up Upstash or Redis Cloud anyway — which collapses the single-vendor co-location story that drove the choice over Railway / Fly / Render.
3. **pgvector on managed DB is unverified.** Self-hosted Serverpod ships pgvector by default; scloud's managed-DB docs do not explicitly confirm pgvector is enabled. PRD open question 3 ("long-term memory architecture, semantic search over journal history may be explored") is exactly the pgvector use case. If pgvector is not available, the cleanest implementation path for that feature is closed.
4. **Documentation is sparse and 404-heavy.** Research returned HTTP 404 on `/getting-started`, `/cli-reference`, `/deployment`, `/concepts/regions`, `/concepts/project-config` — exactly the pages a solo developer or agent needs on day one. The `scloud.yaml` schema is undocumented; you reverse-engineer it from `scloud launch` output and Discord chatter.
5. **Maturity signals are thin.** `serverpod_cloud_cli` is **v0.29.0** (pre-1.0), the public clients repo has **2 stars**, no published SLA, no `status.serverpod.cloud`, no community write-ups of real-world production experience surfaced in research. You will be one of the first publicly-documented users when something breaks.

### Pre-Mortem — How This Could Fail

Six months later, the AI-Tamagotchi launch slipped twice. Week 1, the project hit the scloud waitlist — the devcontainer had the CLI but the developer's scloud account was dormant from an old signup that never reached invite. Three days of email back-and-forth before any deploy could happen at all. Week 2, the developer discovered the managed Postgres did not have pgvector enabled, so the journal recall feature had to fall back to last-N entries with no semantic search; PRD open question 3 silently closed without resolution. Week 3, Upstash Redis was stood up after re-reading the docs page that said scloud did not manage Redis — the "single-vendor simplicity" rationale was now two-vendor billing with no benefit over Railway. Week 4, a routine `scloud deploy` failed with a generic error; the relevant docs page was 404, the Discord question was unanswered for eight hours, and the 2026-06-30 hard deadline slipped. In retrospect: the project optimized for "the first-party Dart story" when the first-party Dart story was not actually ready for a deadline-driven MVP.

### Unknown Unknowns

- **Flutter `--wasm` MIME types on scloud's edge layer are undocumented.** The self-hosted Serverpod `flutter_build` output (`tamagotchi_server/web/app/`) is served by the Dart server — but scloud's proxy may strip or override headers. WASM requires `application/wasm` to be served correctly, or the browser refuses to instantiate the module. Verify with a real deploy before depending on it.
- **`.scloudignore` controls what gets uploaded.** If the existing `Dockerfile` or `docker-compose.yaml` accidentally ships, the build may use the wrong image or surface dev-only sidecars. Always preview with `scloud deploy --dry-run --show-files`.
- **Dart build-environment version pinning is undocumented.** The stack pins `^3.8.0` but devcontainer/CI drift already exists (3.32.8 vs 3.44.0 noted in `stack-assessment.md`). scloud may default to a different Dart version that surfaces lint or null-safety regressions only at build time. Pin explicitly via `scloud deploy --dart-version` if available.
- **No published incident page / SLA / historical uptime data.** When scloud has an outage, you find out by watching your deploy hang. There is no `status.serverpod.cloud` to subscribe to.
- **Closed-source clients repo, no community PRs accepted.** If the CLI has a bug that blocks a deploy, self-patching is not an option — wait for an upstream fix from a small team.

## Operational Story

How the chosen platform operates day to day. One concrete answer per axis.

- **Preview deploys**: scloud has no documented per-PR / per-branch preview-deploy primitive in the public docs as of 2026-05-23. The practical preview path is `scloud deploy` against a second project (e.g. `ai-tamagotchi-staging`) — the `scloud project create` / `scloud project link` commands exist. Branch-based automatic preview URLs are NOT a feature today; expect to wire this yourself in GitHub Actions if needed before launch.
- **Secrets**: `scloud secret set <name>` / `scloud secret list` / `scloud secret unset <name>`. Secrets live in the scloud project, scoped per environment. Application reads them via Serverpod's existing `config/passwords.yaml` override mechanism (`SERVERPOD_PASSWORD_*` env vars). Rotation = `scloud secret set <name> <new-value>` + redeploy. Do NOT commit the local `tamagotchi_server/config/passwords.yaml` with real values.
- **Rollback**: There is **no `scloud rollback` command**. The pattern is `scloud deployment list` (find a prior successful build ID) then re-`scloud deploy` against that build — verify with `scloud deployment show <id>` before. Typical time-to-revert: 1–3 minutes for build pull, plus a fresh container start. **DB migrations do not roll back automatically** — if a Serverpod migration was applied as part of the bad deploy, you'll need a forward-fix migration; do not assume reverting the app reverts the schema.
- **Approval**: Human-only operations for this project: (1) first `scloud launch` (creates the project; double-check name + region intent), (2) `scloud db wipe` (irreversible, drops project DB), (3) any rotation of the GoogleSignIn / Apple OAuth client secrets (production identity provider), (4) custom-domain configuration once acquired. The agent may run unattended: `scloud deploy` against an existing project, `scloud log --tail`, `scloud secret set` for non-primary secrets, `scloud deployment list/show`.
- **Logs**: `scloud log --tail` for live tail; `scloud log --since 1h` / `--since 2026-05-23T08:00:00Z --until 2026-05-23T10:00:00Z` for time-bounded reads. Output is human-formatted (no `--json` flag observed). For agent-side filtering, pipe to `grep` / `awk` — and note this as an MCP candidate: read-only log access via MCP would benefit this stack if/when a control-plane MCP ships.

## Risk Register

Every row names the lens that surfaced it. Verify gating risks before 2026-06-15; if any fails, swap to Railway.

| Risk | Source | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| ~~Scloud account is on waitlist, blocking deploy~~ | Devil's advocate | — | — | **RESOLVED 2026-05-23**: developer holds an active scloud account with free credits. |
| ~~pgvector not enabled on managed Postgres~~ | Devil's advocate | — | — | **RESOLVED 2026-05-23**: developer has previously deployed a RAG on scloud; pgvector is confirmed available on the managed DB. |
| ~~Redis is BYO per docs; "out of the box" claim is wrong~~ | Devil's advocate | — | — | **NOT APPLICABLE 2026-05-23**: project does not use Redis. Single Serverpod instance + no cross-instance pubsub/session/rate-limit needs. Update `config/production.yaml` to disable Redis-backed features explicitly; remove Redis sidecars from production planning. |
| Docs sparse / 404 on key paths during first deploy | Devil's advocate | **H** | M (slows iteration, not fatal) | Before first deploy, run `scloud --help` and every subcommand's `--help` and capture output as a local reference. Join Serverpod Discord. Time-box doc searches to 30 minutes before escalating to community. |
| Pre-1.0 CLI may have undocumented regressions | Devil's advocate | M | M | Pin `serverpod_cloud_cli` version in the devcontainer (already pinned to 0.29.0). Do not auto-upgrade mid-MVP. Watch the changelog before pulling a newer version. |
| Build hangs / generic deploy error with no docs | Pre-mortem | M | **H** | Always run `scloud deploy --dry-run --show-files` first to validate the upload manifest. Capture full output of failed deploys (stderr + `scloud deployment show <id>`) before re-trying. Maintain a known-good build ID for rollback. |
| Free-credit balance runs out mid-MVP, forcing a billing decision | Research finding | M | M | Watch the credit-balance UI in scloud's dashboard before each non-trivial deploy. The Starter tier is $19/mo + $10/mo DB = $29/mo realistic cost — small enough to absorb if needed, but plan the billing event before the credits expire so it doesn't surface as a deploy-blocking surprise. |
| WASM MIME types not served correctly by scloud edge | Unknown unknowns | M | M | First deploy: load the Flutter web app at `/app/` and check browser DevTools Network tab for `application/wasm` Content-Type on `.wasm` responses. If wrong, file with Serverpod support; interim mitigation is fallback to non-WASM Flutter web build (`--no-wasm`). |
| `.scloudignore` accidentally ships dev-only files | Unknown unknowns | L | M | Every deploy: `scloud deploy --dry-run --show-files` and visually verify the file list. Pre-populate `.scloudignore` with `docker-compose.yaml`, `.devcontainer/`, `test/`, `tamagotchi_flutter/build/` (if standalone Flutter dev). |
| Dart build-env version differs from devcontainer / CI | Unknown unknowns | M | M (analyzer/lint regressions at deploy time) | Use `scloud deploy --dart-version 3.8.0` (if supported by 0.29.0; verify with `--help`) to pin. Track the canonical Dart version in CLAUDE.md and align devcontainer + CI + scloud build to it. |
| No scloud status page; outage discovered by hanging deploy | Unknown unknowns | L | M | Monitor Serverpod Discord #cloud channel for outage chatter. For critical pre-launch deploys, run them in a window where the developer is online and can react. |
| Closed-source CLI: cannot self-patch a blocking bug | Unknown unknowns | L | **H if it happens** | Maintain Railway as the documented runner-up; if scloud blocks for >48h on a CLI-side bug, executing the swap is the contingency. |
| Single-cloud blast radius (Serverpod team is a small org) | Research finding | L | **H if it happens** | Keep an offline backup of `migrations/` and a known-working Dockerfile + docker-compose, so a same-day swap to Railway is mechanically possible. |

## Getting Started

The following commands assume Serverpod 3.4.8, Dart 3.8.0, `scloud` CLI v0.29.0 (already pre-installed in the devcontainer). Run from `tamagotchi_server/` unless noted. **Validate against the installed CLI's `--help` before running — exact flag names on `scloud` v0.29.0 may differ from any general scloud documentation, and the docs site has 404s on key paths.**

1. **Confirm the existing scloud session is active** in the devcontainer:
   ```bash
   scloud auth login    # only if not already authenticated; idempotent
   scloud me            # confirms account + remaining free credits visible
   ```

2. **First-deploy preflight**:
   ```bash
   cd tamagotchi_server
   scloud launch                         # generates scloud.yaml; provisions project + managed DB
   scloud deploy --dry-run --show-files  # verify the upload manifest before sending bytes
   scloud deploy                         # actual deploy
   scloud log --tail                     # confirm boot
   ```

3. **Disable Redis-backed features in the production config.** The project ships with `tamagotchi_server/config/production.yaml` that likely includes a `redis:` block from the Serverpod scaffold. Either remove the block or explicitly set `redis.enabled: false` so the server uses in-memory session storage and skips PubSub init. The single-instance topology means no functionality is lost.

4. **Set production secrets**:
   ```bash
   scloud secret set SERVERPOD_PASSWORD_DATABASE "<db-pass>"
   # OAuth client secrets for the IDP flow (Google / Apple):
   scloud secret set GOOGLE_OAUTH_CLIENT_SECRET "<value>"
   ```

5. **Build and deploy the Flutter web client into the server's `/app/`**:
   ```bash
   # from tamagotchi_server/ — Serverpod's own build script handles wasm + copy
   serverpod run flutter_build
   scloud deploy
   ```
   After deploy, load `/app/` in a browser and confirm DevTools shows `application/wasm` Content-Type on `.wasm` responses.

6. **Establish a known-good baseline build ID for rollback**:
   ```bash
   scloud deployment list
   # note the latest successful build ID and pin it in your project notes
   ```

## Out of Scope

The following were not evaluated in this research:
- Docker image configuration (the existing `Dockerfile` is used unchanged by scloud's build pipeline).
- CI/CD pipeline setup (no GitHub Actions workflow is wired to scloud yet; that is a follow-up task).
- Production-scale architecture — multi-region failover, HA, DR, SLA commitments. Out of MVP scope per `prd.md` target_scale.
- Long-term cost projections beyond MVP scale.
- Custom-domain acquisition and DNS provisioning (the Starter tier is subdomain-only; custom domains require Growth at $58/mo + $49/mo DB, so this lands post-MVP unless scope changes).
