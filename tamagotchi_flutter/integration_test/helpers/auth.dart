// Login-once helper (Phase 3 harness lever, playwright-for-flutter).
//
// The storageState equivalent: populate the browser session ONCE so a patrol
// test starts already authenticated, then pump the real app and land on the
// authenticated home. Reused by every test that needs a signed-in creature
// owner — the Phase 4 persistence test is built on it.
//
// PRIMARY PATH (chosen — see plan.md Phase 3 #2, manual item 3.4): programmatic
// login against the REAL auth endpoints. The user (+ its hungry creature) is
// seeded out-of-process by `tamagotchi_server/tool/e2e_seed.dart`; this helper
// signs that user in via `client.emailIdp.login` — the SAME server call the
// third-party `SignInWidget` makes internally — and persists the real JWT with
// `client.auth.updateSignedInUser`. So we exercise the REAL auth → JWT → routing
// → DB path WITHOUT driving the `SignInWidget` black box (sign_in_screen.dart),
// which has no `Key`s we own. Phase 2's `seed_test.dart` already proved this
// exact client transport on patrol web (for registration), so login is safe too.
//
// FALLBACK (documented, NOT used): if `client.emailIdp.login` had proved
// intractable on patrol web, the plan's fallback was to drive `SignInWidget` by
// visible text, or register a fresh user in-browser (as `seed_test.dart` does)
// and DB-seed only the creature by email lookup. The primary path works, so we
// keep it; this comment records the road not taken.
//
// The seeded identity flows in at build time via
// `--dart-define=E2E_EMAIL=… --dart-define=E2E_PASSWORD=…`, matching what
// `e2e_seed.dart` created. The defaults below are the fixed harness fixture —
// seed it with `dart tool/e2e_seed.dart seed --email e2e-harness@tamagotchi.test`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/app/app_widget.dart';
import 'package:tamagotchi_flutter/app/client_provider.dart';
import 'package:tamagotchi_flutter/app/server_config.dart';

/// The seeded email, supplied at build time by `--dart-define=E2E_EMAIL=…` to
/// match the out-of-process fixture from `tool/e2e_seed.dart`. Defaults to the
/// fixed harness fixture.
const e2eEmail = String.fromEnvironment(
  'E2E_EMAIL',
  defaultValue: 'e2e-harness@tamagotchi.test',
);

/// The seeded password, supplied by `--dart-define=E2E_PASSWORD=…`. Defaults to
/// `e2e_seed.dart`'s default password.
const e2ePassword = String.fromEnvironment(
  'E2E_PASSWORD',
  defaultValue: 'e2e-Passw0rd!',
);

/// Signs the seeded user in programmatically, pumps the real [AppWidget], and
/// waits until the authenticated home renders. Returns the [Client] so the
/// caller can reuse it (e.g. to sign out in teardown).
///
/// Mirrors `main()`'s bootstrap (server URL → client → `auth.initialize()` →
/// `ProviderScope` overrides → `AppWidget`), inserting one real login round-trip
/// before the first pump so the router's auth gate lands on the home, not
/// `/sign-in`.
Future<Client> loginOnce(
  PatrolIntegrationTester $, {
  String email = e2eEmail,
  String password = e2ePassword,
}) async {
  final serverUrl = await getServerUrl();
  final client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();
  await client.auth.initialize();

  // The real login round-trip: the server verifies the seeded password (hashed
  // with the same `emailSecretHashPepper` the e2e server uses) and mints a JWT.
  final authSuccess = await client.emailIdp.login(
    email: email,
    password: password,
  );
  // Persist the JWT into the browser session so the app boots authenticated and
  // a later `auth.initialize()` (on a page reload) restores it.
  await client.auth.updateSignedInUser(authSuccess);

  await $.pumpWidgetAndSettle(
    ProviderScope(
      overrides: [
        serverUrlProvider.overrideWithValue(serverUrl),
        serverpodClientProvider.overrideWithValue(client),
      ],
      child: const AppWidget(),
    ),
  );

  // The authenticated home renders the 'AI-Tamagotchi' AppBar title
  // (home_screen.dart) for both the hatch empty state and the creature view.
  await $('AI-Tamagotchi').waitUntilVisible();
  return client;
}

/// Simulates a page reload on patrol web by re-running `main()`'s bootstrap with
/// a BRAND-NEW [Client] whose [FlutterAuthSessionManager] starts signed-out — so
/// `auth.initialize()` must restore the session from browser storage
/// (flutter_secure_storage → localStorage on web), exactly as a real reload's
/// `main()` does. Returns the new [Client].
///
/// Why not a true browser reload: patrol web exposes no `window.location.reload()`
/// to the Dart test (its native reload-style actions are mobile-only; web runs
/// through a Playwright web-runner). This fresh-client re-bootstrap is the
/// faithful equivalent — it drives the SAME persistence-restore path the reload
/// would, in the same browser context where the persisted JWT still lives.
///
/// Asserting the app is still on the authenticated home after this — not bounced
/// to `/sign-in` — is what proves the session survived (Phase 4's core
/// persistence claim, and Phase 3's soft-spot manual check).
Future<Client> reloadAndSettle(PatrolIntegrationTester $) async {
  final serverUrl = await getServerUrl();
  final client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();
  // A fresh manager starts signed-out; initialize() reads the persisted JWT that
  // loginOnce's updateSignedInUser wrote and restores it before first paint.
  await client.auth.initialize();

  await $.pumpWidgetAndSettle(
    ProviderScope(
      overrides: [
        serverUrlProvider.overrideWithValue(serverUrl),
        serverpodClientProvider.overrideWithValue(client),
      ],
      child: const AppWidget(),
    ),
  );
  return client;
}
