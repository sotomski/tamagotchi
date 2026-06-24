// Reset → re-hatch e2e — THE risk-tied browser test for FR-010 / S-09
// (playwright-for-flutter). Modeled on the seed exemplar
// (integration_test/seed_test.dart) and authored under
// integration_test/E2E_RULES.md (the five anti-patterns + real-vs-mocked
// boundary).
//
// PROTECTED RISK (cross-boundary, browser-only): a signed-in user must be able
// to permanently wipe their creature (and its journal) and hatch a fresh one —
// the user-visible FR-010 loop. It is wired end to end through the rendered UI:
// the conditional AppBar Reset action → the confirm dialog gate →
// ResetController → the `reset()` RPC → the cascade delete in `tamagotchi_test`
// → `invalidate(creatureProvider)` → a re-fetch of `null` → the HatchForm
// fallback → a fresh hatch. No single layer's test sees this whole path; an
// integration test proves the cascade delete (reset_endpoint_test.dart) and a
// widget test proves the dialog gating (reset_flow_test.dart), but only the
// browser proves they compose into a recoverable loop.
//
// WHAT IT ASSERTS — and why each assertion fails if the risk materializes:
//   1. After confirm, the home falls back to the HatchForm empty state
//      ('No creature yet …') and the CreatureView is gone (`#feedButton`
//      findsNothing, `#resetButton` findsNothing). If reset did NOT delete the
//      creature server-side, or the invalidate/fallback didn't fire, the
//      CreatureView would remain and the empty state would never appear — red.
//   2. The re-hatch then renders a NEW creature (a distinct, uniquely-named
//      CreatureView). This is the load-bearing server-side-delete proof: the
//      creature_owner_idx is unique-per-owner, so if reset had only cleared
//      client state and left the row in the DB, this second hatch would fail
//      with `alreadyHatched` and the new name would never render — red. A
//      green here means the row was genuinely deleted.
// These are business outcomes, not decorative title checks (anti-pattern #1):
// the AppBar title 'AI-Tamagotchi' is identical in both the creature and the
// empty state, so it could never distinguish them.
//
// FINDERS (anti-pattern #2): Keys and visible text only — `#hatchNameField`,
// `#hatchButton`, `#resetButton`, `#resetConfirmButton`, `#feedButton`,
// `Key('statRow-Hunger')`, and the empty-state / dialog text. The two 'Reset'
// labels on screen while the dialog is open (the AppBar action and the dialog's
// confirm button) are disambiguated by their distinct Keys, never by widget
// type or tree index (there is no DOM — the index IS the brittle selector).
//
// BOUNDARIES (see E2E_RULES.md): auth, routing, and the `tamagotchi_test` DB
// stay REAL — that is where the reset→re-hatch integration risk lives. The only
// mock is the server-side Mistral call, and it is NOT mocked here: the `e2e`
// runmode boots without `mistralApiKey`, so `llmServiceFor` returns the
// deterministic StubLlmService. (Hatch does not call Mistral at all — the
// personality is randomized server-side — so this loop is fully deterministic.)
//
// ISOLATION & CLEANUP (anti-patterns #3/#5): like the seed, this registers a
// FRESH creatureless user in-browser via the real auth endpoints (the `e2e`
// fixed code '12345678'), keyed by a unique timestamped email, so re-runs and
// parallel runs never collide on the one-creature-per-owner / email-unique
// indexes. The browser cannot delete DB rows, so row-level teardown of the
// registered user + its re-hatched creature is out-of-process via
// `e2e_seed.dart teardown --email` (which deletes by email lookup, so it cleans
// up an in-browser-registered account just as well as a seeded one). The unique
// email keeps re-runs green even if teardown is skipped.
//
// RUN RECIPE (sidecars always up; boot the API with `serverpod run e2e` in
// tamagotchi_server/ — see E2E_RULES.md "Running" and the §6.7 cookbook). No
// out-of-process seed step: this test registers + hatches entirely in-browser.
//   # tamagotchi_flutter/ — thread a unique per-run identity in via --dart-define
//   # so teardown can find the in-browser-registered account afterward:
//   EMAIL="e2e-reset-$(date +%s)@tamagotchi.test"
//   patrol test --target integration_test/reset_rehatch_test.dart \
//     --dart-define=E2E_EMAIL="$EMAIL" \
//     -d chrome --web-headless true --web-port 7357 --web-locale en-US
//   # tamagotchi_server/ — row-level teardown (removes the user + re-hatched
//   # creature + personality the in-browser run created):
//   dart tool/e2e_seed.dart teardown --email "$EMAIL"
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

/// The empty-creature state copy (hatch_form.dart). Its presence is how we
/// observe the post-reset fallback to the HatchForm.
const _emptyState = 'No creature yet — hatch one to begin';

/// The email threaded in via `--dart-define=E2E_EMAIL=…` so out-of-process
/// `e2e_seed.dart teardown --email` can find this in-browser-registered
/// account. Empty when unset; we then fall back to a uniquely-stamped email so
/// even a bare `patrol test` (no define) stays self-isolating across re-runs.
const _definedEmail = String.fromEnvironment('E2E_EMAIL');

void main() {
  patrolTest('reset deletes the creature and the user can re-hatch a fresh one', (
    $,
  ) async {
    // ── setup ────────────────────────────────────────────────────────────
    // A unique identifier per run keyed off the seeded email (threaded in via
    // --dart-define=E2E_EMAIL so out-of-process teardown can find this
    // in-browser-registered account). A fresh email → a fresh user → a fresh
    // creature, so re-runs and parallel runs never collide (anti-patterns
    // #3/#5). Two DISTINCT creature names prove the second CreatureView is a
    // genuinely NEW hatch, not a stale render of the first.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    // Prefer the wrapper-supplied (teardownable) email; otherwise stamp a unique
    // one so a bare re-run never collides on the email-unique index.
    final email = _definedEmail.isEmpty
        ? 'e2e-reset-$stamp@tamagotchi.test'
        : _definedEmail;
    final firstName = 'Doomed-$stamp';
    final secondName = 'Reborn-$stamp';

    // Reach the authenticated, creatureless state programmatically through the
    // REAL auth endpoints — the same transport the seed proved on patrol web.
    // The `e2e` runmode's fixed verification code ('12345678') lets sign-up
    // complete with no mailer, exercising the real auth/JWT path without
    // coupling to the third-party SignInWidget black box.
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
      password: 'e2e-reset-Passw0rd!',
    );
    // Persist the real JWT so the app boots authenticated and the auth gate
    // lands on the home (not /sign-in).
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
    // for that state rather than guessing a fixed delay (anti-pattern #4).
    await $(_emptyState).waitUntilVisible();

    // ── hatch the first creature ───────────────────────────────────────────
    await $(#hatchNameField).enterText(firstName);
    await $(#hatchButton).tap();

    // The hatch round-tripped to the DB and CreatureView rendered. Wait for a
    // Key that exists only in CreatureView (a stat row), then assert the
    // creature's own name and the Feed action are present.
    await $(const Key('statRow-Hunger')).waitUntilVisible();
    expect($(firstName), findsOneWidget);
    expect($(#feedButton), findsOneWidget);
    // The Reset action only appears once a creature exists.
    expect($(#resetButton), findsOneWidget);

    // ── reset (through the confirm dialog) ───────────────────────────────────
    await $(#resetButton).tap();
    // The destructive action is gated behind an explicit confirm.
    await $('Reset creature?').waitUntilVisible();
    // Confirm via the dialog's Key — NOT the text 'Reset' (the AppBar action
    // also renders 'Reset' while the dialog is open; the Key disambiguates).
    await $(#resetConfirmButton).tap();

    // ── assertion #1: the creature was deleted and the home fell back ────────
    // The business outcome: reset() deleted the creature server-side and the
    // invalidated provider re-fetched null, so the home re-renders the HatchForm
    // empty state. This FAILS if the delete or the fallback didn't happen — the
    // CreatureView would remain and this text would never appear.
    await $(_emptyState).waitUntilVisible();
    // The old creature view is gone, and so is its Reset action (no creature →
    // no Reset). These are the same failure mode stated two ways.
    expect($(#feedButton), findsNothing);
    expect($(#resetButton), findsNothing);
    expect($(firstName), findsNothing);

    // ── re-hatch a fresh creature ────────────────────────────────────────────
    // This is the load-bearing proof that reset truly deleted the row: the
    // creature_owner_idx is unique-per-owner, so a second hatch succeeds ONLY if
    // the first creature is gone from the DB. If reset had merely cleared client
    // state, this hatch would fail with `alreadyHatched` and `secondName` would
    // never render.
    await $(#hatchNameField).enterText(secondName);
    await $(#hatchButton).tap();

    await $(const Key('statRow-Hunger')).waitUntilVisible();
    expect($(secondName), findsOneWidget);
    expect($(#feedButton), findsOneWidget);

    // ── cleanup ──────────────────────────────────────────────────────────────
    // Sign out to reset the browser session for the next test. The unique email
    // keeps re-runs from colliding; row-level teardown of the registered user +
    // its re-hatched creature is out-of-process via `e2e_seed.dart teardown
    // --email "$E2E_EMAIL"` (header) — the browser must not delete DB rows
    // (E2E_RULES.md, "Cleanup").
    await $('Log out').tap();
    await $('Sign in').waitUntilVisible();
  });
}
