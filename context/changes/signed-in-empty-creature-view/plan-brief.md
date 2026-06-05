# Signed-in Empty-Creature View (S-01) — Plan Brief

> Full plan: `context/changes/signed-in-empty-creature-view/plan.md`
> Research: `context/changes/signed-in-empty-creature-view/research.md`

## What & Why

Deliver roadmap slice **S-01**: a user signs in with email + password and lands on a "no creature yet — hatch one" home (PRD FR-001). The auth backend is already built — the core is wiring + a route guard + an empty-state home. Per the user's directive, the slice is **only done when register/login works on production with delivered transactional emails**, so it also covers the scloud deploy and EmailLabs DNS for `tamagotchi.codecreations.eu` (the final phase).

## Starting Point

`serverpod_auth_idp` is fully wired server-side (endpoints, JWT, migrations) and client-side (`FlutterAuthSessionManager`, `SignInWidget`, a go_router/Riverpod scaffold). But the server **can't boot** (no `config/passwords.yaml` → missing-pepper crash), dev sign-up **can't complete** (mail callbacks only log the code), there's **no route guard** (explicit TODO in `app_router.dart:10-12`), and the home is an anonymous placeholder.

## Desired End State

Dev works (register with the static code → guard routes to the empty-creature home → log out). **And on production**: a brand-new user registers, receives a real EmailLabs verification email from `tamagotchi.codecreations.eu`, completes registration, logs in, lands on the empty home, and logs out. **The change is done only when that production flow passes.** No real secrets touch the repo — they live in scloud + the DNS zone.

## Key Decisions Made

| Decision | Choice | Why | Source |
| --- | --- | --- | --- |
| Sign-in pathways | Email + password only | OAuth dropped from PRD; parked in roadmap | Research |
| Empty-home content | Text only, **no Hatch button** (Q1=A) | Hatch action is S-02; cleanest slice boundary | Plan |
| Dev verification | Static code in `development` run mode (Q2) | Sign-up completes with no mailer | Research/Plan |
| Prod email | `mailer` + **EmailLabs** SMTP, **deployed + DNS-verified on prod** | Acceptance gate is prod register/login with a delivered email | User directive (supersedes earlier Q5=A "defer") |
| Prod secrets | Local gitignored `passwords.yaml`; prod peppers are scloud platform-AUTO; only EmailLabs SMTP creds via `scloud secret set` (Q3=A) | scloud auto-manages the auth peppers (verified); only third-party SMTP creds need explicit setup | Research+Memory |
| Testing | One guard widget test + manual flow (Q4=B) | Pins the only branching logic cheaply | Plan |

## Scope

**In scope:** route guard; dev verification bypass; prod `mailer`/EmailLabs callback; authenticated empty home + log-out; one widget test; **scloud deploy + EmailLabs secret provisioning; EmailLabs sender-auth + DNS for `tamagotchi.codecreations.eu`; the production register/login acceptance test;** OAuth-doc cleanup.

**Out of scope:** building auth; hatch action / creature model (S-02); OAuth; custom email templates/branding, dedicated sending IP, open/click tracking, email retry/queue; CI/CD automation of the deploy; automated sign-up e2e; endpoint `requireLogin` (S-02).

## Architecture / Approach

Server-first (boot + dev sign-up), then Flutter guard, then visible home, then **deploy to scloud**, then **EmailLabs DNS (final) + prod acceptance test**. The router provider reads `serverpodClientProvider` and adds `refreshListenable: client.auth.authInfoListenable` + a `redirect:` keyed on `client.auth.isAuthenticated`. Run-mode gating is consistent across both server edits: `development` → static code + log; else → random code + EmailLabs SMTP send (creds from `session.passwords`). The privileged Phase 5–6 steps (scloud deploy, `scloud secret set`, EmailLabs panel, registrar DNS) are **user-executed**; the plan prepares exact commands/records and verifies them (`dig`, `scloud password list`).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Secrets + dev bypass | Server boots; dev sign-up completes | `passwords.yaml` must also satisfy the DB password to boot |
| 2. Prod email callback | Real `mailer`/EmailLabs send path (run-mode-gated) | Prod branch can't be exercised in dev — review here, verify on prod |
| 3. Auth gate + cleanup | Route guard + guard widget test; remove redundant nav | Router must read the client; `riverpod_lint` inert (manual review) |
| 4. Empty home + log-out | Signed-in text-only home; `signOutDevice()` | Must land after the guard so `/` is auth-only |
| 5. Deploy to scloud + secrets | Prod runs new code; 3 EmailLabs secrets set (peppers stay AUTO); docs/OAuth cleanup | Pre-DNS prod registration fails at email step (expected); EmailLabs login ≠ REST AppKey/SecretKey |
| 6. EmailLabs DNS (FINAL) | Sender-auth + SPF/DKIM for `tamagotchi.codecreations.eu`; **prod register/login acceptance test** | DNS propagation/deliverability delay; copy literal SPF/DKIM from panel |

**Prerequisites:** F-01 scaffold (done); local Postgres sidecar (`docker compose up -d`) for dev; **EmailLabs account; scloud deploy access to project `tamagotchi`; DNS control over `codecreations.eu`** (Phases 5–6, user-executed).
**Estimated effort:** ~2–3 sessions across 6 phases; phases 1–4 are small code, phases 5–6 are external ops + verification gated on DNS propagation (can be hours).

## Open Risks & Assumptions

- The prod email path is unverified until Phase 6 — first real send happens after DNS authorization; the deployed-but-pre-DNS window has broken prod registration (intermediate state).
- Email **deliverability + DNS propagation** can take hours and may land in spam before reputation builds; the acceptance test must account for that.
- The literal EmailLabs SPF include + DKIM record are account-specific — must be copied from the panel, not from research.
- Phases 5–6 depend on external systems and access I can't reach from here (EmailLabs, scloud, registrar) — execution is yours; I prepare + verify.
- `riverpod_lint` won't catch Riverpod-rule violations under CLI/CI — rely on manual/IDE review.

## Success Criteria (Summary)

- **Defines done:** on production, a new user registers → receives a real EmailLabs verification email from `tamagotchi.codecreations.eu` → completes registration → logs in → lands on the empty-creature home → logs out.
- Dev: register (static code) → empty home → log out → bounced to `/sign-in`; guard widget test passes; signed-out `/` redirects to `/sign-in`.
- No real secrets in the repo — EmailLabs creds in scloud, DNS in the `codecreations.eu` zone; peppers stay scloud-AUTO.
