// Feed-persistence e2e — THE risk-tied browser test (playwright-for-flutter
// Phase 4). Modeled on the seed exemplar (integration_test/seed_test.dart) and
// authored under integration_test/E2E_RULES.md (the five anti-patterns +
// real-vs-mocked boundary).
//
// PROTECTED RISK (cross-boundary, browser-only): a Feed mutation must survive a
// real page reload across auth → routing → API → DB. This hardens the
// already-shipped S-03 Feed slice at the browser level — the stat half of
// test-plan.md risk #3's "coherent pair" (stat update + journal insert), seen
// end-to-end through the rendered UI. If a feed's stat change is lost on reload,
// this test goes red; that is the one thing it exists to catch.
//
// WHAT IT ASSERTS — and the journal adaptation. The browser can only observe
// what the app renders. The post-feed STATS are observable: after a reload a
// fresh client re-fetches `myCreature` from `tamagotchi_test` and CreatureView
// shows the persisted numbers. The JOURNAL entry is NOT browser-observable —
// there is no journal-read RPC (the client exposes only hatch/myCreature/feed)
// and the UI renders journal entries nowhere. Asserting it from the browser
// would be a hallucinated assertion (anti-pattern #1). It needs no separate
// browser assertion: feed writes the stat change and the journal entry in ONE DB
// transaction (creature_endpoint.dart:209-233 — the "coherent pair"), so the
// stat surviving the reload transitively proves the journal insert committed;
// the journal write itself is integration-covered (feed_endpoint_test.dart).
//
// DETERMINISTIC ACCEPTANCE — why `--hunger 100`. The accept/refuse gate rolls a
// REAL `Random()` (not the LLM stub): `rejectProbability =
// picky·(1−hunger/100)·(1−tastiness)` (feed_service.dart). At `hunger == 100`
// the `(1−hunger/100)` term is 0, so the feed is accepted every time — no flake
// from the gate, which is unit-covered and not this test's risk. An accepted
// feed then drops hunger by `feedHungerDrop` (30) and energy by `feedEnergyCost`
// (10): seeded 100/100 → 70/90. The stub LLM only supplies deterministic copy.
//
// RUN RECIPE (sidecars always up; boot the API with `serverpod run e2e` in
// tamagotchi_server/ — see E2E_RULES.md "Running" and the Phase 6 cookbook). The
// hungry creature is seeded OUT-OF-PROCESS (the browser can't write DB rows);
// a unique timestamped email isolates parallel/re-runs (anti-patterns #3/#5),
// and the feed commits a real mutation, so each run re-seeds fresh state:
//   # tamagotchi_server/ — seed (note --hunger 100 for deterministic acceptance):
//   EMAIL="e2e-persist-$(date +%s)@tamagotchi.test"
//   dart tool/e2e_seed.dart seed --email "$EMAIL" --hunger 100
//   # tamagotchi_flutter/ — thread the seeded identity in via --dart-define:
//   patrol test --target integration_test/feed_persistence_test.dart \
//     --dart-define=E2E_EMAIL="$EMAIL" \
//     -d chrome --web-headless true --web-port 7357 --web-locale en-US
//   # tamagotchi_server/ — row-level teardown (removes the user, creature,
//   # the committed feed mutation, and its journal entry):
//   dart tool/e2e_seed.dart teardown --email "$EMAIL"
// The password defaults to e2e_seed.dart's, which matches helpers/auth.dart, so
// only E2E_EMAIL needs threading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/auth.dart';

/// The seeded baseline this test requires (`e2e_seed.dart seed --hunger 100`).
/// 100 makes the feed deterministically accepted (reject probability is 0 at
/// max hunger — see the header).
const _seededHunger = 100;

/// Post-feed stats after one accepted feed: hunger −`feedHungerDrop` (30),
/// energy −`feedEnergyCost` (10) from the seeded 100/100. These are the
/// feed_service.dart oracle constants, not values copied from a passing run.
const _fedHunger = 70;
const _fedEnergy = 90;

void main() {
  patrolTest('feed mutations survive a page reload', ($) async {
    // ── setup ──────────────────────────────────────────────────────────────
    // login-once into the out-of-process-seeded hungry creature (the
    // storageState equivalent — helpers/auth.dart). Lands on the authenticated
    // home with the seeded creature loaded.
    await loginOnce($);
    await $(const Key('statRow-Hunger')).waitUntilVisible();

    // Precondition: we start from the seeded baseline. Scoped to the Hunger row
    // (the per-stat Key disambiguates which stat a number belongs to). Fails
    // fast + legibly if the fixture wasn't seeded with `--hunger 100`.
    expect(
      $(const Key('statRow-Hunger')).$('$_seededHunger'),
      findsOneWidget,
      reason:
          'expected the seeded hunger ($_seededHunger) on the home — seed the '
          'fixture with `e2e_seed.dart seed --hunger $_seededHunger`',
    );

    // ── action ─────────────────────────────────────────────────────────────
    // Feed once, then wait for the in-character response container (state, not a
    // fixed delay). #interactionResponse renders only after the feed RPC
    // resolves (the shared Feed/Play response area).
    await $(#feedButton).tap();
    await $(#interactionResponse).waitUntilVisible();

    // The mutation is applied in the LIVE view (pre-reload): hunger 100→70,
    // energy 100→90. This is the accept path — the one that writes the stat
    // change and the journal entry as a single DB transaction. Wait for the
    // re-rendered value (creatureProvider re-fetches after a feed).
    await $(const Key('statRow-Hunger')).$('$_fedHunger').waitUntilVisible();
    expect($(const Key('statRow-Energy')).$('$_fedEnergy'), findsOneWidget);

    // ── reload ─────────────────────────────────────────────────────────────
    // A fresh client re-bootstraps from the persisted JWT and re-fetches
    // myCreature from tamagotchi_test (helpers/auth.dart) — the faithful patrol
    // equivalent of a browser reload.
    await reloadAndSettle($);
    await $(const Key('statRow-Hunger')).waitUntilVisible();

    // ── assertion (THE risk) ─────────────────────────────────────────────────
    // The post-feed stats are STILL the fed values after the reload — re-read
    // from the DB across auth → routing → API → DB, not held in client memory
    // (the feed controller resets on the fresh client, so #interactionResponse
    // is gone here by design). If the feed mutation had not persisted, the
    // reload would show the seeded 100/100 and these would fail — this is the
    // business outcome, not a decorative title.
    expect(
      $(const Key('statRow-Hunger')).$('$_fedHunger'),
      findsOneWidget,
      reason: 'fed hunger ($_fedHunger) must survive the reload (persistence)',
    );
    expect(
      $(const Key('statRow-Energy')).$('$_fedEnergy'),
      findsOneWidget,
      reason: 'fed energy ($_fedEnergy) must survive the reload (persistence)',
    );
    // And it did NOT silently revert to the seeded baseline — the exact failure
    // mode the persistence risk describes.
    expect($(const Key('statRow-Hunger')).$('$_seededHunger'), findsNothing);

    // ── cleanup ────────────────────────────────────────────────────────────
    // Sign out to reset the browser session for the next test. Row-level
    // teardown of the seeded user+creature (and the committed feed mutation +
    // journal entry) is out-of-process via `e2e_seed.dart teardown` (header) —
    // there is no creature-delete endpoint, and the browser must not delete DB
    // rows (E2E_RULES.md, "Cleanup").
    await $('Log out').tap();
    await $('Sign in').waitUntilVisible();
  });
}
