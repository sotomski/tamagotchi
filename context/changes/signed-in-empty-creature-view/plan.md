# Signed-in Empty-Creature View (S-01) Implementation Plan

## Overview

Deliver roadmap slice **S-01**: a working email+password auth vertical slice that lands a signed-in user on a "no creature yet — hatch one" home screen. The `serverpod_auth_idp` backend (endpoints, JWT, migrations) and the Flutter session manager are **already wired** — this slice is the *wiring + a route guard + an empty-state home* that the F-01 scaffold deliberately left behind. It makes dev sign-up completable without a mailer, writes the real (run-mode-gated) production email path, **deploys to Serverpod Cloud, and configures EmailLabs DNS for `tamagotchi.codecreations.eu`** so that **registration + login work on production with delivered transactional verification emails** — the explicit acceptance gate for this change.

## Current State Analysis

- **Server auth is fully wired but cannot boot.** `server.dart:20-32` calls `initializeAuthServices` with `JwtConfigFromPasswords()` + `EmailIdpConfigFromPasswords(...)`. Those read `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`, `emailSecretHashPepper` from `config/passwords.yaml` — **which is absent** (`git check-ignore` confirms it's gitignored at `.gitignore:15`). The docs source these with `getPassword(...)!`, so a missing key crashes startup. The local dev DB password also normally lives in `passwords.yaml` (the value is already non-secret in `docker-compose.yaml`).
- **Mail callbacks are stubs.** `server.dart:80-102` (`_sendRegistrationCode` / `_sendPasswordResetCode`) only `session.log(...)` the verification code. Registration uses an email-code flow, so without a real delivery path or a dev bypass, sign-up can't complete in the UI. `mailer` is **not** a dependency (`tamagotchi_server/pubspec.yaml:11-13`).
- **No route guard.** `app_router.dart:13-28` is a flat two-route map (`/` → `HomeScreen`, `/sign-in` → `SignInScreen`) with an explicit TODO (`:10-12`): "S-01 adds the redirect via a `refreshListenable` tied to `client.auth.authInfoListenable`." `main.dart:32` already `await client.auth.initialize()` before `runApp`, so boot-time auth state is settled (async-restore race pre-mitigated).
- **Placeholder home.** `home_screen.dart:9-31` is an *anonymous* placeholder with a "Sign in" button; its docstring says S-01 replaces it.
- **Sign-in screen has a review nit.** `sign_in_screen.dart:62-63` navigates inside `SignInWidget`'s `onAuthenticated` — docs warn this causes re-sign-in loops once a router redirect is the gate.
- **Test setup exists.** `flutter_test` is a dev-dependency; only a default `test/widget_test.dart` is present. `riverpod_lint` is inert under CLI/CI in this workspace ([[project_riverpod_lint_inert_in_pub_workspace]]) — rely on manual review for Riverpod-rule violations.

## Desired End State

Two surfaces, both working:

- **Dev:** start the server in `development` (no missing-password crash), open the Flutter web app, **register** with the static dev code, get redirected to the signed-in **text-only empty-creature home**, **log out**, and be bounced back to `/sign-in` by the guard.
- **Production (the acceptance gate):** on the deployed Serverpod Cloud URL, a brand-new user can **register → receive a real verification email** delivered via EmailLabs from a `tamagotchi.codecreations.eu` address → complete registration → **log in** → land on the empty-creature home → **log out**. The change is **done only when this production flow passes end-to-end.**

No real secrets touch this repo or devcontainer — EmailLabs SMTP creds live in scloud; DNS records live in the `codecreations.eu` zone.

### Key Discoveries:

- Auth-gate contract is stated verbatim in code: `app_router.dart:10-12` — add `redirect:` + `refreshListenable: client.auth.authInfoListenable`; unauthenticated → `/sign-in`, authenticated → `/`.
- `SignInWidget` (`sign_in_screen.dart:60`) already covers the **full email lifecycle** — sign-in + registration (email → code → password) + password reset — so **no separate sign-up UI is needed**.
- Sign out is `client.auth.signOutDevice()` (this device) / `signOutAllDevices()` — there is **no** plain `signOut()`.
- Documented dev bypass: `registrationVerificationCodeGenerator` returning a static code in `development` run mode (length must match the production default).
- **The 3 auth peppers are scloud platform-AUTO in production** — empirically `scloud password list` shows `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`, `emailSecretHashPepper` (plus `database`, `serviceSecret`) as AUTO (Platform) for this project ([[project_scloud_auto_manages_secrets_and_db_config]], verified 2026-05-23). So prod does **not** set them manually (overriding a platform value is a regression); only **local dev** needs them in `passwords.yaml`. The **EmailLabs SMTP creds are third-party secrets** and DO need explicit setup via `scloud secret set`.
- **EmailLabs SMTP auth uses a separate "SMTP account" credential** (`1.<panelname>.smtp` + its own password), **not** the REST API AppKey/SecretKey. Host `smtp.emaillabs.net.pl`, STARTTLS on 587. Sending from `tamagotchi.codecreations.eu` requires in-panel Sender Authorization + DNS (SPF `include:_spf.emaillabs.co`, panel-generated DKIM, optional Return-Path/DMARC).
  - **[superseded 2026-06-05 — transport pivoted to REST]** scloud **blocks outbound SMTP egress** (`frame.md`; Phase 5 prod send timed out at TCP connect, errno 110), so the send moves to EmailLabs' `new_sendmail` **REST API over 443** (Phase 6). REST authenticates with the **AppKey/SecretKey**; the `1.<panelname>.smtp` identifier survives only as the `smtp_account` body param and its SMTP *password* is unused. The Sender Authorization + DNS (SPF/DKIM/DMARC) requirement is **unchanged** (Phase 7).

## What We're NOT Doing

- **Not building auth from scratch** — the backend, JWT, and migrations already exist.
- **Not the hatch action or creature/journal data model** — that is S-02. S-01's home is a static empty state with **no Hatch button** (Q1 = A).
- **Not OAuth / third-party sign-in** — PRD §Access Control was corrected to email+password only (`prd.md:104`); OAuth is parked (`roadmap.md:233`).
- **Not** a full automated sign-up integration/e2e (Q4 = B: one guard widget test; the production flow is a **manual acceptance test**).
- **Not** custom email templates / branding, a dedicated sending IP, open/click tracking, or email retry/queue infrastructure — a plain-text verification email over EmailLabs shared IP is enough for the acceptance gate.
- **Not** CI/CD automation of the deploy — Phase 5 is a manual `scloud` deploy, not a pipeline (that is a later Module 1/2 concern).
- **Not** keeping the SMTP transport or switching email providers — scloud's outbound-SMTP block is cleared by moving to EmailLabs' own `new_sendmail` REST API over 443, **not** by changing providers or petitioning scloud to unblock SMTP (`frame.md`). Provider, From-address, and DNS work are unchanged.
- **Not** adding `requireLogin` to creature endpoints (S-02) and **not** adding new password-reset UI (the existing `SignInWidget` covers it).
- **Note:** real secrets are still never committed — they go to scloud (`scloud secret set`) and the DNS zone, not the repo (consistent with [[feedback_no_db_credentials_in_devcontainer]]).

## Implementation Approach

Build server-side first (so the app can boot and dev sign-up works), then the Flutter guard, then the visible home, then **deploy to production**, and finally **configure EmailLabs DNS** and run the production acceptance test. Server-side splits into "make dev work now" (Phase 1) vs "write the prod path activated later" (Phase 2). The Flutter guard (Phase 3) lands before the home replacement (Phase 4): once the guard makes `/` auth-only, the new home can safely assume an authenticated user and drop the "Sign in" button. Phase 5 deploys the built artifact + sets the EmailLabs secrets. **Phase 5's prod test surfaced that scloud categorically blocks outbound SMTP egress** (`frame.md`), so the original "Phase 6 = DNS" is now **two gates**: **Phase 6 pivots the transport** from SMTP to EmailLabs' `new_sendmail` REST API over 443 (same provider, drop `mailer`, two new REST secrets) and proves outbound 443 works; **Phase 7 (final) does the EmailLabs sender authorization + DNS** so the now-reachable send actually delivers, and the production register→email→login→home→logout flow is the definition of done. The privileged/external steps in Phases 5–7 (scloud deploy, `scloud secret set`, EmailLabs panel, registrar DNS) are **user-executed**; this plan prepares the exact commands + records and verifies them.

## Critical Implementation Details

- **Run-mode gating must be consistent across both server edits.** Phase 1 overrides `registrationVerificationCodeGenerator` to a static code **only in `development`**; Phase 2's send callbacks branch on the **same** run mode (`development` → log only; else → SMTP send). In production the default generator produces a random code and the callback emails it; in dev the static code is logged and entered manually. Read run mode via `pod.runMode` at config time and `session.serverpod.runMode` inside the callbacks. The static code length must equal the production default (the docs example uses an 8-char code).
- **`passwords.yaml` must also satisfy the DB password to actually boot.** The 3 auth peppers alone won't boot the server if the local Postgres password isn't otherwise injected. Source the `database` value from the existing `docker-compose.yaml` dev sidecar (already committed, throwaway — not a production credential). Keep `production.yaml`'s DB block a placeholder (scloud injects at runtime).
- **The router provider must read the client.** `appRouter` currently ignores `ref`; it must `ref.watch(serverpodClientProvider)` to obtain `client.auth.authInfoListenable` (for `refreshListenable`) and `client.auth.isAuthenticated` (for the redirect decision).

---

## Phase 1: Server auth secrets + dev verification bypass

### Overview

Make the server boot and make dev registration completable without a mailer.

### Changes Required:

#### 1. Local auth + DB secrets

**File**: `tamagotchi_server/config/passwords.yaml` (new, gitignored)

**Intent**: Provide the three auth peppers so `initializeAuthServices` stops crashing, plus the local dev DB password so the server connects to the Postgres sidecar.

**Contract**: YAML map with keys `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`, `emailSecretHashPepper` (strong random dev-only values, generated locally — **not** placed in this plan), and a `database` key sourced from the existing `docker-compose.yaml` dev value (only if the dev DB password isn't already injected via env). File stays gitignored (`.gitignore:15`). No real/production secrets.

#### 2. Dev verification-code bypass

**File**: `tamagotchi_server/lib/server.dart`

**Intent**: In `development` run mode, make registration's verification code a known static value so sign-up completes in the UI without delivered email.

**Contract**: Add `registrationVerificationCodeGenerator` to the `EmailIdpConfigFromPasswords(...)` call — returns a fixed static code (length == production default) when `pod.runMode == 'development'`, otherwise the default generator. Other params unchanged.

### Success Criteria:

#### Automated Verification:

- `config/passwords.yaml` is valid YAML containing all three pepper keys: parse + key-presence check.
- `git check-ignore tamagotchi_server/config/passwords.yaml` returns the path (file is ignored).
- `dart analyze` passes in `tamagotchi_server/`.

#### Manual Verification:

- With the Postgres sidecar up (`docker compose up -d`), the server starts in `development` and logs "started" with **no** missing-password / null-assertion crash.
- Registering in the Flutter sign-in UI with the static dev code completes; server log shows the `[EmailIdp] Registration code` line and `verifyRegistrationCode` accepts the static code.

**Implementation Note**: After automated verification passes, pause for human confirmation of the manual server-boot + dev-registration check before Phase 2.

---

## Phase 2: Production email callback (mailer + EmailLabs, run-mode-gated)

### Overview

> **Superseded by Phase 6 (2026-06-05):** the SMTP transport written here is replaced by an EmailLabs `new_sendmail` REST call — scloud blocks outbound SMTP egress (`frame.md`). This block remains as the historical record of what shipped in `c38c6fa`; the live transport is defined in Phase 6.

Write the real production email-delivery path as reviewed code that activates only outside `development`. Not exercised in this devcontainer.

### Changes Required:

#### 1. Add the mailer dependency

**File**: `tamagotchi_server/pubspec.yaml`

**Intent**: Bring in the Dart `mailer` package for SMTP sending.

**Contract**: Add `mailer` to `dependencies`; `dart pub get` resolves cleanly.

#### 2. Branch the verification-code callbacks on run mode

**File**: `tamagotchi_server/lib/server.dart`

**Intent**: In non-`development` run modes, send the verification code via EmailLabs SMTP instead of only logging it; keep dev as log-only.

**Contract**: `_sendRegistrationCode` and `_sendPasswordResetCode` branch on `session.serverpod.runMode`: `development` → existing `session.log(...)`; else → build `SmtpServer('smtp.emaillabs.net.pl', port: 587, ssl: false, allowInsecure: false, username:, password:)` with `username`/`password`/from-address read from `session.passwords['emaillabsSmtpUser' | 'emaillabsSmtpPassword' | 'emaillabsSmtpFrom']`, construct a `Message` (From = verified `tamagotchi.codecreations.eu` address, recipient = `email`, subject + body containing `verificationCode`), `await send(message, smtpServer)`, and catch `MailerException` → `session.log(..., level: LogLevel.error)` + rethrow. **No credentials hardcoded.**

```dart
// Non-dev branch shape (EmailLabs = SMTP-account creds, NOT the REST AppKey/SecretKey):
final smtp = SmtpServer('smtp.emaillabs.net.pl',
    port: 587, ssl: false, allowInsecure: false,
    username: session.passwords['emaillabsSmtpUser']!,      // "1.<panelname>.smtp"
    password: session.passwords['emaillabsSmtpPassword']!); // SMTP-account password
```

### Success Criteria:

#### Automated Verification:

- `mailer` present in `pubspec.yaml`; `dart pub get` succeeds.
- `dart analyze` passes with the new imports + branched callbacks.

#### Manual Verification:

- Code review confirms: `development` logs only (no SMTP attempt); non-dev constructs the EmailLabs `SmtpServer` + `send(...)` reading creds from `session.passwords`, with `MailerException` caught/logged.
- No real SMTP credentials are committed anywhere.

**Implementation Note**: This phase's prod branch can't run in this devcontainer — confirm via review here; it is **activated and verified on production in Phases 5–6**. Proceed after review.

---

## Phase 3: Flutter auth gate (route guard) + sign-in cleanup

### Overview

Add the route guard that gates the whole app on auth state, and remove the now-redundant in-screen navigation.

### Changes Required:

#### 1. Auth-gate redirect on the router

**File**: `tamagotchi_flutter/lib/app/app_router.dart` (+ regenerated `app_router.g.dart`)

**Intent**: Redirect unauthenticated users to `/sign-in` and keep authenticated users on the app surface, re-evaluating live on sign-in/sign-out.

**Contract**: `appRouter` reads `final client = ref.watch(serverpodClientProvider)`; the `GoRouter` gains `refreshListenable: client.auth.authInfoListenable` and a `redirect:` that uses `client.auth.isAuthenticated`: unauthenticated + not already on `/sign-in` → `/sign-in`; authenticated + on `/sign-in` → `/`; otherwise no redirect. Provider stays `@Riverpod(keepAlive: true)`. Regenerate via `dart run build_runner build --delete-conflicting-outputs`.

#### 2. Remove redundant onAuthenticated navigation

**File**: `tamagotchi_flutter/lib/auth/sign_in_screen.dart`

**Intent**: Let the router redirect be the single source of post-sign-in navigation (docs warn that navigating in `onAuthenticated` causes re-sign-in loops).

**Contract**: Drop the `context.go('/')` calls driven by `onAuthenticated` / the local `authInfoListenable` listener; rely on the guard. `onError` snackbar behavior unchanged. Screen may simplify toward stateless once the manual listener is gone.

#### 3. Guard widget test

**File**: `tamagotchi_flutter/test/app/app_router_redirect_test.dart` (new)

**Intent**: Pin the redirect logic — the slice's only real branching.

**Contract**: Pump the app inside a `ProviderScope` with `serverpodClientProvider` overridden by a fake/stub client exposing a controllable `auth.isAuthenticated` + `authInfoListenable`. Assert: unauthenticated start → lands on `/sign-in`; authenticated start → lands on `/`; flipping auth state notifies the listenable and re-routes. (Replace/remove the stale default `test/widget_test.dart` if it no longer compiles against the app.)

### Success Criteria:

#### Automated Verification:

- `dart run build_runner build --delete-conflicting-outputs` regenerates `app_router.g.dart` cleanly.
- `flutter test test/app/app_router_redirect_test.dart` passes (both directions + live flip).
- `flutter analyze` passes.

#### Manual Verification:

- Signed-out user hitting `/` is redirected to `/sign-in`; after sign-in lands on `/`; redirect re-evaluates live (no full reload).
- No re-sign-in loop after removing the `onAuthenticated` navigation.

**Implementation Note**: Pause for human confirmation of the manual redirect behavior before Phase 4.

---

## Phase 4: Authenticated empty-creature home + log-out

### Overview

Replace the anonymous placeholder with the signed-in empty state and a log-out affordance.

### Changes Required:

#### 1. Authenticated empty-creature home

**File**: `tamagotchi_flutter/lib/home/home_screen.dart`

**Intent**: Show the authenticated "no creature yet — hatch one" empty state (text only, per Q1 = A) and a log-out action; drop the anonymous "Sign in" button (the guard now guarantees an authenticated viewer).

**Contract**: `HomeScreen` becomes a `ConsumerWidget` (to read `serverpodClientProvider`). Body = centered empty-state copy ("No creature yet — hatch one to begin", final wording at implementer's discretion), **no Hatch button**. `AppBar` gains a log-out action (icon/menu) that calls `client.auth.signOutDevice()`; the guard then bounces to `/sign-in`. Update the docstring (no longer a placeholder).

### Success Criteria:

#### Automated Verification:

- `flutter analyze` passes for the rewritten `home_screen.dart`.
- If a provider is read, `dart run build_runner build --delete-conflicting-outputs` stays clean.

#### Manual Verification:

- Authenticated home shows the text-only empty state — no "Sign in" button, no Hatch button.
- Log-out action calls `signOutDevice()`; user is bounced to `/sign-in`; reloading `/` stays signed out (local session cleared).

**Implementation Note**: Pause for human confirmation of the home + log-out flow before Phase 5.

---

## Phase 5: Deploy to Serverpod Cloud + provision EmailLabs secrets + docs

### Overview

Ship Phases 1–4 plus the prod email branch to the existing scloud `tamagotchi` project, provision the three EmailLabs SMTP secrets (the peppers + DB stay platform-AUTO), and reconcile docs. After this phase prod runs the new code; **email delivery still fails until Phase 6's DNS authorization** — expected.

### Changes Required:

#### 1. Provision the three EmailLabs SMTP secrets on scloud (user-executed)

**File**: scloud project config — no repo file.

**Intent**: Make the EmailLabs SMTP credentials available to the deployed server's password map without committing them.

**Contract**: Provision three secrets named so Serverpod's password map exposes them and `session.passwords['emaillabsSmtp*']` resolves: `SERVERPOD_PASSWORD_emaillabsSmtpUser` (the SMTP-account login `1.<panelname>.smtp` — **not** the REST AppKey/SecretKey), `SERVERPOD_PASSWORD_emaillabsSmtpPassword` (SMTP-account password), `SERVERPOD_PASSWORD_emaillabsSmtpFrom` (a `tamagotchi.codecreations.eu` From address). Use `scloud secret set <name> '<value>'` (confirm exact subcommand/prefix against the current scloud CLI). Do **not** set the peppers/DB — verify they remain AUTO via `scloud password list` ([[project_scloud_auto_manages_secrets_and_db_config]]). Real values never enter the repo.

#### 2. Build + deploy to production

**File**: deploy artifacts — `tamagotchi_server/web/app/` (build output) + scloud deploy.

**Intent**: Run the new auth wiring + prod email branch on production.

**Contract**: Build the Flutter web app (`serverpod run flutter_build` from `tamagotchi_server/`), deploy via scloud, and apply migrations (auth tables already migrated at `migrations/20260521163433251/` — confirm no new migration is pending). Confirm the deployed server boots (peppers AUTO → no missing-password crash). (User-executed; this plan supplies the command sequence.)

#### 3. Docs sync: deploy/secrets runbook + OAuth cleanup + change status

**File**: `context/foundation/infrastructure.md`, `context/changes/signed-in-empty-creature-view/change.md`

**Intent**: Record the deploy + secrets procedure and reconcile stale docs.

**Contract**: Add an `infrastructure.md` section documenting: peppers + DB are scloud platform-AUTO (verify, never set); the three `scloud secret set ... emaillabsSmtp*` commands; the EmailLabs SMTP-account-vs-AppKey nuance; and a pointer to the Phase 6 DNS records. Strike/annotate the stale OAuth client-secret references (`infrastructure.md:92,139-140`) as superseded by the email-only decision (`prd.md:104`). Set `change.md` → `status: in_progress`, `updated: 2026-06-04`. Placeholder values only.

### Success Criteria:

#### Automated Verification:

- Flutter web build succeeds; `tamagotchi_server/web/app/` is populated; scloud deploy completes without error.
- `scloud password list` shows `database` + the three peppers as AUTO; the three `emaillabsSmtp*` secrets are present in scloud.
- `infrastructure.md` documents the peppers-AUTO note + the three `scloud secret set ... emaillabsSmtp*` lines; `change.md` shows `status: in_progress`.

#### Manual Verification:

- The production app loads at the deployed URL and the dev-equivalent flow works up to the email step.
- A registration attempt on prod **reaches** the email-send step (the EmailLabs send is attempted) — its failure due to an unverified sender is **expected and resolved in Phase 6**.
- Review: no real secret values committed; OAuth references reconciled.

**Implementation Note**: After the deploy + secret checks pass, pause for human confirmation before the final DNS phase.

---

## Phase 6: Transport pivot — EmailLabs SMTP → `new_sendmail` REST over 443

### Overview

Replace the SMTP send — categorically blocked by scloud's egress policy — with an HTTPS POST to EmailLabs' `new_sendmail` REST API over 443. Same provider, same verified From-address, different transport. Provision the two REST API credentials as scloud secrets and redeploy. This clears the **upstream transport gate**: every send now *reaches* EmailLabs (an HTTP response) instead of timing out at TCP connect. Deliverability (sender-auth + DNS) is still pending and is Phase 7.

### Changes Required:

#### 1. Swap the mailer dependency for an HTTP client

**File**: `tamagotchi_server/pubspec.yaml`

**Intent**: Drop the now-dead SMTP library and bring in an HTTP client for the REST call.

**Contract**: Remove `mailer: ^7.1.0` (and its comment); add `http` at a version compatible with the Serverpod 3.4.8 dependency set. `dart pub get` resolves cleanly.

#### 2. Rewrite the send transport to `new_sendmail`

**File**: `tamagotchi_server/lib/server.dart`

**Intent**: Replace the SMTP body of `_sendVerificationEmail` (`:161-193`) with a form-encoded HTTPS POST to EmailLabs `new_sendmail`; leave the two run-mode-gated callbacks (`:105-150`) and the dev bypass (`:20,36-46`) untouched.

**Contract**: Drop the two `mailer` imports (`:5-6`) and their prefixing comment (`:3-4`); add `package:http` and `dart:convert`. `_sendVerificationEmail` keeps its signature (`session`, `recipient`, `subject`, `body`) and POSTs to `https://api.emaillabs.net.pl/api/new_sendmail` with header `Authorization: Basic base64(emaillabsApiKey:emaillabsApiSecret)` and an `application/x-www-form-urlencoded` body: `smtp_account` = `session.passwords['emaillabsSmtpUser']`, `to[<recipient>]` = `''`, `from` = `session.passwords['emaillabsSmtpFrom']`, `subject`, `text` = body. Parse the JSON `{code,status,message}`: on `status != 'success'` **or** a non-2xx HTTP status, `session.log(...)` the response body at `LogLevel.error` and **throw** (parity with the prior rethrow — a verification-code flow must fail loudly when no code can be delivered [Q4=A]); wrap network/socket errors the same way. AppKey/SecretKey read from `session.passwords['emaillabsApiKey' | 'emaillabsApiSecret']`. Update the doc comment (REST auth = AppKey/SecretKey; `smtp_account` is only a body param). Body stays **plain text** (the `text` param) — no HTML template (out of scope). **No credentials hardcoded.**

The one non-obvious bit (Basic header + the array-style `to` param) — everything else is a routine `http.post`:

```dart
// EmailLabs REST auth: Basic base64(AppKey:SecretKey) — NOT the smtp_account password.
final auth = base64Encode(utf8.encode(
    '${session.passwords['emaillabsApiKey']}:${session.passwords['emaillabsApiSecret']}'));
// http.post(Uri.parse('https://api.emaillabs.net.pl/api/new_sendmail'),
//   headers: {'authorization': 'Basic $auth'},   // Content-Type set automatically for a Map body
//   body: {'smtp_account': ..., 'from': ..., 'subject': ..., 'text': ..., 'to[$recipient]': ''});
```

#### 3. Provision the two EmailLabs REST secrets on scloud (user-executed)

**File**: scloud project config — no repo file.

**Intent**: Make the REST AppKey/SecretKey available to the deployed server's password map without committing them.

**Contract**: `scloud secret set SERVERPOD_PASSWORD_emaillabsApiKey '<AppKey>'` and `... SERVERPOD_PASSWORD_emaillabsApiSecret '<SecretKey>'` (AppKey/SecretKey from EmailLabs panel → Administrator → API). **Reuse** the existing `emaillabsSmtpUser` (= the `smtp_account` `1.<panelname>.smtp`) and `emaillabsSmtpFrom`; `emaillabsSmtpPassword` is now unused — leave it (harmless) or delete it. Verify peppers + DB stay platform-AUTO via `scloud password list` ([[project_scloud_auto_manages_secrets_and_db_config]]). Real values never enter the repo.

#### 4. Build + redeploy to production

**File**: deploy artifacts — `tamagotchi_server/web/app/` + scloud deploy.

**Intent**: Run the REST transport on production.

**Contract**: Rebuild Flutter web (`serverpod run flutter_build` from `tamagotchi_server/`) and `scloud deploy` (user-executed; this plan supplies the sequence). No new migration is expected — confirm none pending. Confirm the deployed server boots clean (peppers AUTO → no missing-password crash).

#### 5. Docs sync: record the SMTP→REST pivot

**File**: `context/foundation/infrastructure.md`, `context/changes/signed-in-empty-creature-view/change.md`

**Intent**: Supersede the SMTP runbook with the REST transport + new secrets, and resolve the Phase 5 finding.

**Contract**: In `infrastructure.md`'s "S-01 Production Deploy & EmailLabs Secrets" section, mark the SMTP transport superseded; document the two `scloud secret set ... emaillabsApi{Key,Secret}` commands, the `new_sendmail` contract, the AppKey/SecretKey-vs-`smtp_account` distinction, and that `emaillabsSmtpUser`/`emaillabsSmtpFrom` are reused while `emaillabsSmtpPassword` is unused; update "After this deploy" to record that REST-over-443 resolves the SMTP-egress timeout. Add a `change.md` Notes entry for the pivot. Placeholder values only.

### Success Criteria:

#### Automated Verification:

- `mailer` removed and `http` present in `pubspec.yaml`; `dart pub get` succeeds.
- `dart analyze` passes in `tamagotchi_server/` with the REST transport + new imports.
- Flutter web build succeeds; `scloud deploy` completes without error.
- `scloud secret list` shows `emaillabsApiKey` + `emaillabsApiSecret`; `scloud password list` shows `database` + the three peppers still AUTO.
- `infrastructure.md` documents the REST pivot + the two new secret commands; `change.md` has the pivot Notes entry.

#### Manual Verification:

- A prod registration attempt now **reaches EmailLabs over 443** — `new_sendmail` returns an HTTP response (any status, even a pre-DNS `FromError`), **not** a TCP timeout. This proves outbound 443 egress — the frame's one residual risk [Q2=A].
- Server log shows the EmailLabs `{code,status,message}` body, not a `SocketException`.
- Review: no real secret values committed.

**Implementation Note**: After automated checks pass, pause for human confirmation that the prod send **reaches** EmailLabs (a non-timeout HTTP response) before the DNS phase. Delivery is **not** expected to succeed yet — that is Phase 7.

---

## Phase 7: EmailLabs sender authorization + DNS + production acceptance (FINAL)

### Overview

Authorize the `tamagotchi.codecreations.eu` sending subdomain in the EmailLabs panel, publish its DNS records (SPF + DKIM + a monitoring DMARC), wait for verification, then run the **production acceptance test** that defines done.

### Changes Required:

#### 1. EmailLabs Sender Authorization (panel, user-executed)

**File**: EmailLabs panel — no repo file.

**Intent**: Register `tamagotchi.codecreations.eu` as an authorized sender and have the panel generate its account-specific DNS records.

**Contract**: Panel → Administrator → Sender Authorization → Add Domain → enter `tamagotchi.codecreations.eu` → Advanced Settings (DKIM selector ≤7 chars, optional Return-Path + tracking subdomains, DMARC policy) → Save. The panel emits the literal SPF include + DKIM record to publish.

#### 2. Publish the DNS records (codecreations.eu zone, user-executed)

**File**: `codecreations.eu` DNS zone — no repo file.

**Intent**: Authorize EmailLabs to send from the subdomain, pass alignment, and add monitoring-level DMARC [Q3=B].

**Contract**: Publish: SPF `TXT` at `tamagotchi.codecreations.eu` (`v=spf1 include:_spf.emaillabs.co ~all` — use the literal include from the panel); the panel-generated **DKIM** record (CNAME or TXT at `<selector>._domainkey.tamagotchi.codecreations.eu`); a **`_dmarc.tamagotchi.codecreations.eu` TXT at `p=none`** (monitoring only — improves alignment visibility with **zero** bounce risk); Return-Path CNAME optional. Wait for propagation, then click **Check** in the panel → status **Accepted**. Paste the panel's literal SPF include + DKIM selector/target and I'll generate the exact records and verify them via `dig`.

### Success Criteria:

#### Automated Verification:

- `dig TXT tamagotchi.codecreations.eu` returns the EmailLabs SPF include; the DKIM record resolves at `<selector>._domainkey.tamagotchi.codecreations.eu`; `dig TXT _dmarc.tamagotchi.codecreations.eu` returns the `p=none` policy.
- The EmailLabs panel shows the domain status = **Accepted/verified**.

#### Manual Verification (ACCEPTANCE — defines done):

- On the **production** URL, registering a brand-new account triggers a **real verification email** delivered from a `tamagotchi.codecreations.eu` address (check inbox + spam); entering the code completes registration.
- Logging in with those credentials lands on the **empty-creature home**.
- Logging out bounces back to `/sign-in`.

**Implementation Note**: This is the final acceptance gate. The change is **done only when production register → email → login → empty home → logout all pass.** On success, set `change.md` → `status: complete`.

---

## Testing Strategy

### Unit / Widget Tests:

- One Flutter widget test for the route-guard redirect (`test/app/app_router_redirect_test.dart`): unauthenticated → `/sign-in`, authenticated → `/`, and a live auth-state flip re-routes. Uses a stubbed client via `serverpodClientProvider` override.

### Integration Tests:

- No *automated* integration/e2e (Q4 = B). Real email delivery is validated by the **manual production acceptance test** below, not an automated suite.

### Manual Testing Steps:

**Dev (after Phase 4):**
1. `docker compose up -d` (Postgres sidecar), start the server in `development`; confirm it boots with no missing-password crash.
2. Open the Flutter web app; register a new account; enter the static dev verification code; confirm registration succeeds.
3. Confirm post-sign-in landing on the text-only empty-creature home.
4. Trigger log-out; confirm bounce to `/sign-in` and a cleared session on reload.
5. While signed out, navigate directly to `/`; confirm redirect to `/sign-in`.

**Production acceptance (after Phase 7 — defines done):**
6. On the deployed scloud URL, register a brand-new account; confirm a **real verification email** arrives from a `tamagotchi.codecreations.eu` address (check inbox + spam).
7. Enter the emailed code; confirm registration completes and you land on the empty-creature home.
8. Log out, then log back in with the same credentials; confirm you reach the empty-creature home.
9. While signed out on prod, hit `/`; confirm redirect to `/sign-in`.

## Performance Considerations

Negligible. The redirect runs on a `ValueListenable` already constructed at boot; no new network calls beyond the existing auth RPCs. The verification-code callback (prod only) makes a single outbound HTTPS POST to EmailLabs `new_sendmail` inside the existing async callback — one request per registration / reset, no connection pooling concern.

## Migration Notes

No schema changes — auth tables are already migrated (`migrations/20260521163433251/`). No `serverpod generate` needed (no `*.spy.yaml` edits). Deploy (Phase 5/6) applies existing migrations on scloud; confirm none are pending. The prod email path now has **two gates**: Phase 6 makes the send *reachable* (SMTP→REST-over-443 transport pivot — scloud blocks outbound SMTP), and Phase 7 makes it *deliverable* (EmailLabs sender-auth + DNS for `tamagotchi.codecreations.eu`). A deployed prod fails registration at the email step until **both** complete; between Phase 6 and Phase 7 the send *reaches* EmailLabs but is rejected/undelivered pre-authorization (an HTTP error, no longer a TCP timeout).

## References

- Research: `context/changes/signed-in-empty-creature-view/research.md`
- Frame brief (transport pivot): `context/changes/signed-in-empty-creature-view/frame.md`
- EmailLabs `new_sendmail` contract: `POST https://api.emaillabs.net.pl/api/new_sendmail`, header `Authorization: Basic base64(AppKey:SecretKey)`, `application/x-www-form-urlencoded` params `smtp_account` / `to[<email>]` / `from` / `subject` / `text`|`html`; JSON `{code,status,message,data}` (success = `code:200`/`status:"success"`).
- Email transport source: `tamagotchi_server/lib/server.dart:161-193` (`_sendVerificationEmail`), callbacks `:105-150`, dev bypass `:20,36-46`
- Auth-gate contract: `tamagotchi_flutter/lib/app/app_router.dart:10-12`
- Server auth init + stub callbacks: `tamagotchi_server/lib/server.dart:20-32,80-102`
- Sign-in screen (review nit): `tamagotchi_flutter/lib/auth/sign_in_screen.dart:62-63`
- Placeholder home: `tamagotchi_flutter/lib/home/home_screen.dart:9-31`
- PRD oracle: `context/foundation/prd.md:58,80,102-104`; roadmap S-01: `context/foundation/roadmap.md:95-105`
- Memories: [[project_scloud_auto_manages_secrets_and_db_config]], [[feedback_no_db_credentials_in_devcontainer]], [[project_riverpod_lint_inert_in_pub_workspace]]

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Server auth secrets + dev verification bypass

#### Automated

- [x] 1.1 `config/passwords.yaml` is valid YAML containing all three pepper keys — 801ab93
- [x] 1.2 `git check-ignore tamagotchi_server/config/passwords.yaml` returns the path — 801ab93
- [x] 1.3 `dart analyze` passes in `tamagotchi_server/` — 801ab93

#### Manual

- [x] 1.4 Server starts in `development` with no missing-password crash (Postgres sidecar up) — 801ab93
- [x] 1.5 Dev registration completes with the static code; `verifyRegistrationCode` accepts it — 801ab93

### Phase 2: Production email callback (mailer + EmailLabs, run-mode-gated)

#### Automated

- [x] 2.1 `mailer` present in `pubspec.yaml`; `dart pub get` succeeds — c38c6fa
- [x] 2.2 `dart analyze` passes with the new imports + branched callbacks — c38c6fa

#### Manual

- [x] 2.3 Review: `development` logs only; non-dev sends via EmailLabs `SmtpServer` with creds from `session.passwords`, `MailerException` caught/logged — c38c6fa
- [x] 2.4 Review: no real SMTP credentials committed — c38c6fa

### Phase 3: Flutter auth gate (route guard) + sign-in cleanup

#### Automated

- [x] 3.1 `build_runner` regenerates `app_router.g.dart` cleanly — 1efb2c1
- [x] 3.2 `flutter test test/app/app_router_redirect_test.dart` passes (both directions + live flip) — 1efb2c1
- [x] 3.3 `flutter analyze` passes — 1efb2c1

#### Manual

- [x] 3.4 Signed-out `/` redirects to `/sign-in`; post-sign-in lands on `/`; re-evaluates live — 1efb2c1
- [x] 3.5 No re-sign-in loop after removing `onAuthenticated` navigation — 1efb2c1

### Phase 4: Authenticated empty-creature home + log-out

#### Automated

- [x] 4.1 `flutter analyze` passes for the rewritten `home_screen.dart` — 573c972
- [x] 4.2 `build_runner` stays clean (if a provider is read) — 573c972

#### Manual

- [x] 4.3 Home shows text-only empty state — no "Sign in" button, no Hatch button — 573c972
- [x] 4.4 Log-out calls `signOutDevice()`; bounced to `/sign-in`; session cleared on reload — 573c972

### Phase 5: Deploy to Serverpod Cloud + provision EmailLabs secrets + docs

#### Automated

- [x] 5.1 Flutter web build succeeds; scloud deploy completes — bdfa313
- [x] 5.2 `scloud password list` shows DB + 3 peppers AUTO; the 3 `emaillabsSmtp*` secrets present — bdfa313
- [x] 5.3 `infrastructure.md` documents peppers-AUTO + the three `scloud secret set emaillabsSmtp*` lines; `change.md` shows `status: in_progress` — bdfa313

#### Manual

- [x] 5.4 Prod app loads; flow works up to the email step; EmailLabs send attempted (failure pre-DNS is expected) — bdfa313
- [x] 5.5 Review: no real secrets committed; OAuth refs reconciled — bdfa313

### Phase 6: Transport pivot — EmailLabs SMTP → `new_sendmail` REST over 443

#### Automated

- [x] 6.1 `mailer` removed, `http` present in `pubspec.yaml`; `dart pub get` succeeds — 3a64891
- [x] 6.2 `dart analyze` passes with the REST transport + new imports — 3a64891
- [x] 6.3 Flutter web build succeeds; `scloud deploy` completes — 3a64891
- [x] 6.4 `scloud secret list` shows `emaillabsApiKey` + `emaillabsApiSecret`; `scloud password list` shows DB + 3 peppers still AUTO — 3a64891
- [x] 6.5 `infrastructure.md` documents the REST pivot + two new secret commands; `change.md` has the pivot Notes entry — 3a64891

#### Manual

- [x] 6.6 Prod registration reaches EmailLabs over 443 — `new_sendmail` returns an HTTP response (not a TCP timeout); log shows `{code,status,message}` — 3a64891
- [x] 6.7 Review: no real secret values committed — 3a64891

### Phase 7: EmailLabs sender authorization + DNS + production acceptance (FINAL)

> **DEFERRED (2026-06-05)** — blocked on DNS control-panel access for the codecreations.eu zone (operator contacted). Credentials are fixed (prod `new_sendmail` now returns the expected pre-auth `500 "SMTP account is not authorized to send from no-reply@tamagotchi.codecreations.eu"`, not the old 401). The 4 EmailLabs CNAMEs to publish + the resume runbook are recorded in `change.md` Notes (Option B, panel-exact). Resume here when DNS access is restored.

#### Automated

- [ ] 7.1 `dig` shows the EmailLabs SPF include + DKIM record + `_dmarc` `p=none` for `tamagotchi.codecreations.eu`
- [ ] 7.2 EmailLabs panel shows the domain status = Accepted/verified

#### Manual

- [ ] 7.3 Prod register → real verification email from `tamagotchi.codecreations.eu` → code accepted → registration completes
- [ ] 7.4 Prod login lands on the empty-creature home; log-out bounces to `/sign-in`
- [ ] 7.5 On success, `change.md` → `status: complete`
