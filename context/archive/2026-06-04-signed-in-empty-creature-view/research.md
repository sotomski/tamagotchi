---
date: 2026-06-04T19:53:56+0000
researcher: Karol Sotomski
git_commit: ad05a6717767e6a0e93707cee9d208cc2276344d
branch: signed-in-empty-creature-view
repository: nabrudno
topic: "How to best approach basic auth (sign up, sign in, log out) for the signed-in empty-creature view (S-01)"
tags: [research, codebase, auth, serverpod_auth_idp, go_router, riverpod, S-01]
status: complete
last_updated: 2026-06-04
last_updated_by: Karol Sotomski
---

# Research: Basic auth (sign up / sign in / log out) for `signed-in-empty-creature-view` (S-01)

**Date**: 2026-06-04T19:53:56+0000
**Researcher**: Karol Sotomski
**Git Commit**: ad05a6717767e6a0e93707cee9d208cc2276344d
**Branch**: signed-in-empty-creature-view
**Repository**: nabrudno

## Research Question

This slice is about all basic aspects of auth — sign up, sign in, log out. Research how to best approach this in this project. (Scope corrected mid-research: **email + password only, OAuth dropped** — see PRD change below.)

## Summary

**The auth backend and client plumbing already exist.** This slice is *not* "build auth from scratch" — Serverpod's new `serverpod_auth_idp` module is already wired end-to-end (server endpoints + JWT + migrations; Flutter `FlutterAuthSessionManager` + `SignInWidget` + a go_router/Riverpod scaffold). The roadmap (S-01) and the prior `frontend-state-mgmt-routing-scaffold` change both describe S-01 as **"wiring + a route guard + an empty-state home"** — the lowest-cost first vertical slice.

The concrete work for S-01 is therefore small and well-bounded:

1. **Add the auth gate** to the existing `GoRouter`: a `redirect:` driven by `refreshListenable: client.auth.authInfoListenable` that sends unauthenticated users → `/sign-in` and authenticated users → `/`. This is the explicit hand-off the scaffold left behind (a TODO in `app_router.dart:10-12`).
2. **Make sign-up actually completable in dev.** Registration uses an email verification-code flow, but the mail callbacks are stubs that only `session.log(...)` the code. The documented fix is a one-line dev override: `registrationVerificationCodeGenerator` returning a static code in `development` run mode.
3. **Provision the three auth secrets** in a local (gitignored) `config/passwords.yaml`: `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`, `emailSecretHashPepper`. None exist on disk today.
4. **Add a log-out affordance** on the home screen using `client.auth.signOutDevice()` (there is no plain `signOut()`).
5. **Replace the anonymous placeholder** `home_screen.dart` with the *authenticated* "no creature yet — hatch one" empty-creature home (the hatch action itself is S-02, not S-01).

**Scope correction applied during research:** PRD §Access Control was edited from "two pathways: email+password and OAuth" to **email+password only** (`prd.md:104`). OAuth / IDP provider wiring is out of scope. This matches `roadmap.md:233` ("OAuth … deferred to keep MVP scope small").

## Decision oracle — what the slice must do (from sources, not implementation)

- **PRD FR-001** (`prd.md:58`): "User can register an account and log in." — the entire functional surface of S-01.
- **PRD §Access Control** (`prd.md:102-104`, as corrected): "Authenticated users reach the main game surface; unauthenticated visitors are routed to sign-up / sign-in. Sign-in supports a single pathway: email + password. … **There is no third-party / OAuth sign-in.**"
- **PRD US-01 precondition** (`prd.md:80`): "Given a logged-in user **with no creature**" — confirms the post-sign-in landing is the no-creature home.
- **Roadmap S-01** (`roadmap.md:95-105`): "user can sign in with email+password and land on a 'no creature yet — hatch one' home screen. PRD refs: FR-001. … mostly **wiring + a route guard + an empty-state home**."
- **Roadmap boundary**: the creature data model + hatch action belong to **S-02** (`roadmap.md:107-118`), not S-01. FR-010 (reset) belongs to S-09. S-01 stops at the empty-state home.

## Detailed Findings

### 1. Server-side auth is fully wired (`serverpod_auth_idp_server`)

- Dependency: `serverpod_auth_idp_server: 3.4.8` (`tamagotchi_server/pubspec.yaml:13`).
- Bootstrap in `tamagotchi_server/lib/server.dart:20-32`:
  ```dart
  pod.initializeAuthServices(
    tokenManagerBuilders: [ JwtConfigFromPasswords() ],
    identityProviderBuilders: [
      EmailIdpConfigFromPasswords(
        sendRegistrationVerificationCode: _sendRegistrationCode,
        sendPasswordResetVerificationCode: _sendPasswordResetCode,
      ),
    ],
  );
  ```
- Endpoints (auto-registered):
  - `EmailIdpEndpoint extends EmailIdpBaseEndpoint` — `tamagotchi_server/lib/src/auth/email_idp_endpoint.dart:3-6`. RPC methods (generated in `lib/src/generated/endpoints.dart:45-223`): `login`, `startRegistration`, `verifyRegistrationCode`, `finishRegistration`, `startPasswordReset`, `verifyPasswordResetCode`, `finishPasswordReset`, `hasAccount`.
  - `JwtRefreshEndpoint extends RefreshJwtTokensEndpoint` — `tamagotchi_server/lib/src/auth/jwt_refresh_endpoint.dart:3-5` (`refreshAccessToken`).
- Modules registered: `serverpod_auth_idp` + `serverpod_auth_core` (`lib/src/generated/endpoints.dart:273-276`; `protocol.dart:30-32`).
- **Migrations already include auth tables** (`tamagotchi_server/migrations/20260521163433251/`): `serverpod_auth_idp_email_account` (email + passwordHash + FK to auth user), `..._email_account_password_reset_request`, `..._email_account_request`, plus other (unused) provider tables. Email+password schema is migrated.
- **Mail callbacks are stubs** (`tamagotchi_server/lib/server.dart:80-102`): `_sendRegistrationCode` / `_sendPasswordResetCode` only `session.log('[EmailIdp] Registration code ($email): $verificationCode')`. No mailer.

### 2. Flutter client auth + routing scaffold is in place

- `tamagotchi_flutter/lib/main.dart:25-32`:
  ```dart
  final client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();   // serverpod_auth_idp_flutter
  await client.auth.initialize();                          // restores persisted session BEFORE runApp
  ```
  Root: `ProviderScope` overriding `serverUrlProvider` + `serverpodClientProvider` (`main.dart:34-42`).
- Router: `@Riverpod(keepAlive: true) GoRouter appRouter(Ref ref)` in `tamagotchi_flutter/lib/app/app_router.dart:13-28`. Two routes: `/` → `HomeScreen`, `/sign-in` → `SignInScreen`. **No `redirect` / guard** — explicit TODO at `app_router.dart:10-12`.
- Root widget uses `MaterialApp.router` consuming `appRouterProvider` (`app_widget.dart:7-19`). (Material 3 — **not** ShadApp; shadcn_ui not used in the scaffold.)
- Sign-in screen: `tamagotchi_flutter/lib/auth/sign_in_screen.dart` reuses `serverpod_auth_idp_flutter`'s `SignInWidget` (`:60`), listens to `client.auth.authInfoListenable` (`:30`), and `context.go('/')` on auth (`:42,:52,:63`).
- Home screen: `tamagotchi_flutter/lib/home/home_screen.dart:9-31` is an **anonymous** placeholder ("No creature yet" + a `Sign in` button). Docstring (`:6-8`): "S-01 (FR-001) replaces this with the real signed-in empty-creature view."
- Providers (Riverpod codegen, committed `.g.dart`): `serverpodClientProvider` (`lib/app/client_provider.dart:12`), `appRouterProvider` (`lib/app/app_router.dart:13`), `serverUrlProvider` (`lib/app/server_config.dart:12`). **No auth/session provider yet.**
- Client host from `tamagotchi_flutter/assets/config.json` → `{"apiUrl":"http://localhost:8080"}`.

### 3. Canonical `serverpod_auth_idp` API for the slice (Serverpod 3.4.0 docs)

Citations to `/serverpod/serverpod_docs` `version-3.4.0/06-concepts/11-authentication/*`.

- **Secrets needed** (`01-setup.md`): `JwtConfigFromPasswords` → `jwtHmacSha512PrivateKey` + `jwtRefreshTokenHashPepper`; `EmailIdpConfigFromPasswords` → `emailSecretHashPepper`. Loaded from `config/passwords.yaml` or `SERVERPOD_PASSWORD_*`. Missing keys most likely cause a **startup null-assertion crash** (the docs use `getPassword(...)!`), not an auto-generated dev key — *unconfirmed in docs*, so provide all three locally.
- **Registration without real email (the key question)** — documented dev bypass (`04-providers/02-email/02-configuration.md`, "Bypass Verification Code in Development"):
  ```dart
  EmailIdpConfigFromPasswords(
    registrationVerificationCodeGenerator:
        pod.runMode == 'development' ? () => 'aaaaaaaa' : defaultVerificationCodeGenerator,
  )
  ```
  Then `verifyRegistrationCode` always succeeds with the static code (length must match production default). Alternatives: read the logged code from server logs (works today, awkward), or `admin.createEmailAuthentication(session, authUserId:, email:, password:)` to seed verified test users directly (`04-providers/02-email/04-admin-operations.md`).
- **`SignInWidget`** (`01-setup.md`, `04-providers/02-email/03-customizing-the-ui.md`): auto-renders UI for all configured providers; for email it covers the **full lifecycle — sign-in + registration (email → code → password) + password reset**. So **no separate sign-up UI is needed**. Params: `client`, `onAuthenticated`, `onError`. Doc caveat: do **not** navigate inside `onAuthenticated` (causes re-sign-in loops) — drive navigation off `authInfoListenable` / the router redirect instead. (The repo's `sign_in_screen.dart` currently navigates in `onAuthenticated`; flag for review.)
- **Client auth-state API** (`02-basics.md`): `client.auth.initialize()`; `client.auth.isAuthenticated` (bool); `client.auth.authInfo` (`AuthSuccess?`); `client.auth.authInfoListenable` (`ValueListenable<AuthSuccess?>` — the redirect's `refreshListenable`). **Sign out: `client.auth.signOutDevice()`** (this device) or `signOutAllDevices()`; both `Future<bool>`, both clear local state. No plain `signOut()` alias.
- **Protecting future endpoints** (`02-basics.md`): override `bool get requireLogin => true;` on the `Endpoint`; inside a method `final info = await session.authenticated; final userId = info?.userIdentifier;` (`session.authenticated` is an async getter; `userIdentifier` is a `UuidValue`). Relevant for S-02's creature endpoints, not S-01.

### 4. The auth-gate contract handed off by the scaffold (F-01 → S-01)

Stated verbatim in three places:
- `tamagotchi_flutter/lib/app/app_router.dart:10-12`: "No auth guard yet — **S-01 adds the redirect via a `refreshListenable` tied to `client.auth.authInfoListenable`.**"
- `context/changes/frontend-state-mgmt-routing-scaffold/plan.md:133-135`: auth guard intentionally absent; no `redirect:` callback on `appRouter`.
- `context/changes/frontend-state-mgmt-routing-scaffold/plan.md:34`: "No auth redirect / route guard … S-01 adds the auth gate."

**Contract:** add `redirect:` + `refreshListenable: client.auth.authInfoListenable` to the `appRouter` `GoRouter`; unauthenticated → `/sign-in`, authenticated → `/`.

**Async-restore race already mitigated** (`frontend-state-mgmt-routing-scaffold/reviews/impl-review.md:156-169`, finding F6): `main()` already `await client.auth.initialize()` before `runApp()`, so the boot-time redirect won't misroute a returning signed-in user. Still drive the redirect off the listenable so it re-evaluates on sign-in/sign-out. Path-URL strategy (`usePathUrlStrategy()`) is on (F4).

## Code References

- `tamagotchi_server/lib/server.dart:20-32` — `initializeAuthServices` (JWT + email IDP).
- `tamagotchi_server/lib/server.dart:80-102` — stub mail callbacks (log the code only).
- `tamagotchi_server/lib/src/auth/email_idp_endpoint.dart:3-6` — `EmailIdpEndpoint`.
- `tamagotchi_server/lib/src/auth/jwt_refresh_endpoint.dart:3-5` — `JwtRefreshEndpoint`.
- `tamagotchi_server/lib/src/generated/endpoints.dart:45-247,273-276` — generated RPC connectors + module registration.
- `tamagotchi_server/migrations/20260521163433251/` — auth tables incl. `serverpod_auth_idp_email_account`.
- `tamagotchi_server/config/` — **no `passwords.yaml`** (must be created locally with 3 keys).
- `tamagotchi_flutter/lib/main.dart:25-42` — Client + `FlutterAuthSessionManager` + `client.auth.initialize()` + `ProviderScope`.
- `tamagotchi_flutter/lib/app/app_router.dart:10-28` — router + the auth-gate TODO.
- `tamagotchi_flutter/lib/app/app_widget.dart:7-19` — `MaterialApp.router`.
- `tamagotchi_flutter/lib/auth/sign_in_screen.dart:30,42,52,60-75` — `SignInWidget` + `authInfoListenable` + `onAuthenticated` navigation (review nit).
- `tamagotchi_flutter/lib/home/home_screen.dart:6-31` — anonymous placeholder to replace.
- `context/foundation/prd.md:58,80,102-104` — FR-001, US-01 precondition, corrected Access Control.
- `context/foundation/roadmap.md:32,48,95-118,233` — S-01 / S-02 definitions, stream order, parked OAuth.

## Architecture Insights

- **Group-by-feature placement** (root `CLAUDE.md`; `tamagotchi_server/CLAUDE.md`): server auth → `tamagotchi_server/lib/src/auth/` (exists); Flutter auth → `tamagotchi_flutter/lib/auth/` (exists); the router/redirect is cross-cutting and lives in `tamagotchi_flutter/lib/app/` (sanctioned as a shell dir by the scaffold impl-review).
- **No global `Client`** — read auth state through `serverpodClientProvider` (`lib/app/client_provider.dart`). An S-01 auth/session provider should wrap `client.auth` (e.g. expose `authInfoListenable` / `isAuthenticated`) and live in `lib/auth/` (or `lib/app/` if the redirect consumes it directly).
- **Riverpod codegen baseline**: `@Riverpod(keepAlive: true)`, committed `.g.dart`, `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi_flutter/`.
- **`riverpod_lint` is inert under CLI/CI** in this pub workspace ([[project_riverpod_lint_inert_in_pub_workspace]]) — `flutter analyze` won't catch Riverpod-rule violations; rely on IDE/manual review.
- **Backend comms go through the generated `tamagotchi_client` RPC + Serverpod `SignInWidget`** — never hand-roll HTTP/JSON for auth (root `CLAUDE.md`; the `flutter-use-http-package` / `flutter-implement-json-serialization` skills are explicitly overridden by project convention).
- **Flutter build**: `serverpod run flutter_build` from `tamagotchi_server/` (dart2js; `--wasm` disabled per F-01).

## Historical Context (from prior changes)

- `context/changes/frontend-state-mgmt-routing-scaffold/plan.md` — built the go_router + Riverpod scaffold; deliberately left the auth gate, the `/sign-in` route, and the placeholder home for S-01. `plan.md:34,133-135,255,319-325`.
- `context/changes/frontend-state-mgmt-routing-scaffold/reviews/impl-review.md` — F1 (riverpod_lint inert), F4 (path-URL strategy), F5/F6 (context-mounted guards + the awaited `client.auth.initialize()` that pre-fixes S-01's async-restore race).
- That change has **no `research.md`**; its hand-off lives in `plan.md` / `plan-brief.md` / `reviews/impl-review.md` and the in-code TODOs.
- `context/foundation/roadmap.md:233` (Parked) + `context/foundation/prd.md:104` (corrected) — OAuth deferred.

## Related Research

- None prior for auth. Adjacent: the scaffold change's `plan.md` / `plan-brief.md` / `reviews/impl-review.md` (the routing + state-management foundation S-01 builds on).

## Open Questions

1. **Email verification delivery (must decide for the slice).** Recommended: add the documented `registrationVerificationCodeGenerator` dev override (static code in `development` run mode) so sign-up is completable without a mailer. Real email delivery is deferred — there is **no email-delivery decision in `infrastructure.md`**. Make the deferral explicit. Owner: user.
2. **Auth secrets in dev vs. prod.** Local dev needs a gitignored `config/passwords.yaml` with `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`, `emailSecretHashPepper` (dev-only values; **not** DB credentials, so the no-DB-creds-in-devcontainer rule [[feedback_no_db_credentials_in_devcontainer]] doesn't block these). Production: confirm whether scloud auto-injects these app secrets or they must be set as `SERVERPOD_PASSWORD_*` — [[project_scloud_auto_manages_secrets_and_db_config]] covers the 5 *platform* passwords + DB, not these auth peppers. Owner: user.
3. **`onAuthenticated` navigation in `sign_in_screen.dart`.** Docs advise against navigating there (re-sign-in loops); once the router redirect is the gate, the in-screen `context.go('/')` is redundant and should likely be removed/relied-on-listenable instead. Confirm during planning.
4. **Stale OAuth references in `infrastructure.md:92,139-140`** (Google/Apple client secrets) — now inconsistent with the corrected PRD. Out of scope for S-01 to fix, but worth a cleanup note.
5. **Empty-creature home content.** S-01 shows an authenticated "no creature yet — hatch one" state; the actual hatch affordance wires to a real action in **S-02**. Decide how much of the empty-state UI (and whether a disabled/placeholder "Hatch" button) lands in S-01 vs S-02.
