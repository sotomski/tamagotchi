// Patrol seed test (lever #1, playwright-for-flutter Phase 2).
//
// THIS IS THE EXEMPLAR. Every patrol test generated for this app is modeled on
// it — *what the seed shows is what gets generated* (see
// .claude/skills/10x-e2e/references/seed-test-pattern.md). It is the patrol/Dart
// translation of that reference's Playwright `seed.spec.ts`. Read it alongside
// integration_test/E2E_RULES.md before authoring a new e2e test.
//
// Protected risk: the cross-boundary creature lifecycle (S-03). A hatch must
// travel auth → routing → API → DB and re-render on the home. The Phase 4
// persistence test (feed_persistence_test.dart) extends this exact shape with a
// page reload — this seed is the model it clones.
//
// The four patterns it demonstrates (the reference's checklist, in patrol idiom):
//   1. Key + visible-text finders — `$(#hatchButton)`, `$(Key('statRow-Hunger'))`,
//      `$('No creature yet…')`; NEVER `$(ElevatedButton)` / widget-tree index
//      (that is the "brittle selector" anti-pattern on a renderer with no DOM).
//   2. A full self-contained cycle — setup → action → assertion → cleanup — with
//      a unique timestamped identifier so re-runs and parallel runs never collide.
//   3. Wait for state, not time — `waitUntilVisible()` (finder auto-wait);
//      NEVER a fixed `Future.delayed` / `pump(Duration(...))`.
//   4. A risk-tied test name — it names the behavior it protects, not `test 1`.
//
// Boundaries (see E2E_RULES.md): auth, routing, and the DB stay REAL — that is
// where the integration risk lives. The only mock is the server-side Mistral
// call, and it is NOT mocked here in the browser: the `e2e` runmode boots
// without `mistralApiKey`, so `llmServiceFor` returns the deterministic
// StubLlmService. A browser-level `page.route()` could never reach that
// server-side call — mock it where the server actually calls out.
//
// Run (sidecars are always up; boot the API with `serverpod run e2e` in
// tamagotchi_server/ — see lessons.md and the Phase 6 cookbook):
//   patrol test --target integration_test/seed_test.dart \
//     -d chrome --web-headless true --web-port 7357 --web-locale en-US
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/app/app_widget.dart';
import 'package:tamagotchi_flutter/app/client_provider.dart';
import 'package:tamagotchi_flutter/app/server_config.dart';

void main() {
  patrolTest('hatched creature persists to the server and renders on the home', (
    $,
  ) async {
    // ── setup ────────────────────────────────────────────────────────────
    // A unique identifier per run: a fresh email → a fresh user → a fresh
    // creature (creatures are unique-per-owner in the DB), so re-runs and
    // parallel runs never collide on the seeded rows (anti-pattern #5).
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'e2e-seed-$stamp@tamagotchi.test';
    final creatureName = 'Seedling-$stamp';

    // Reach the authenticated state programmatically through the real auth
    // endpoints. The `e2e` runmode's fixed verification code ('12345678') lets
    // sign-up complete with no mailer, so this exercises the REAL auth/JWT path
    // without coupling the seed to the third-party SignInWidget black box. The
    // Phase 3 login-once helper hardens this into a shared setup step.
    final serverUrl = await getServerUrl();
    final client = Client(serverUrl)
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authSessionManager = FlutterAuthSessionManager();
    await client.auth.initialize();

    final accountRequestId = await client.emailIdp.startRegistration(
      email: email,
    );
    final registrationToken = await client.emailIdp.verifyRegistrationCode(
      accountRequestId: accountRequestId,
      verificationCode: '12345678',
    );
    final authSuccess = await client.emailIdp.finishRegistration(
      registrationToken: registrationToken,
      password: 'e2e-seed-Passw0rd!',
    );
    // Persist the real JWT into the session manager so the app boots
    // authenticated and the router's auth gate lands on the home (not /sign-in).
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

    // A fresh user has no creature: the home shows the hatch empty state. Wait
    // for that state (a text finder) rather than guessing a fixed delay.
    await $('No creature yet — hatch one to begin').waitUntilVisible();

    // ── action ───────────────────────────────────────────────────────────
    // Drive the hatch via stable finders: the Key on the name field + the Key on
    // the Hatch button. enterText/tap auto-pump, so no explicit settle between.
    await $(#hatchNameField).enterText(creatureName);
    await $(#hatchButton).tap();

    // ── assertion ────────────────────────────────────────────────────────
    // The business outcome: the hatch round-tripped to the DB and the re-fetched
    // creature now renders the stats view. Wait for a Key that exists only in
    // CreatureView (a stat row), then assert the creature's own name is on
    // screen. This FAILS if the hatch did not persist (the empty state would
    // remain) — it is not a decorative title check.
    await $(const Key('statRow-Hunger')).waitUntilVisible();
    expect($(creatureName), findsOneWidget);
    expect($(#feedButton), findsOneWidget);

    // ── cleanup ──────────────────────────────────────────────────────────
    // Sign out to reset the browser session for the next test. The seeded
    // user+creature rows live in tamagotchi_test; the unique ids above keep
    // re-runs from colliding, and the Phase 3 e2e_seed.dart teardown will remove
    // the rows by id once that harness lands (there is no creature-delete
    // endpoint today, so row-level teardown is deferred to that script — see
    // E2E_RULES.md, "Cleanup").
    await $('Log out').tap();
    await $('Sign in').waitUntilVisible();
  });
}
