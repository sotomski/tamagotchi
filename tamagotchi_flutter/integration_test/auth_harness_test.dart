// Phase 3 auth harness canary (playwright-for-flutter).
//
// NOT a risk-tied test and NOT the seed. Its only job is to prove the Phase 3
// harness end-to-end: that the login-once helper (helpers/auth.dart) signs the
// out-of-process-seeded user in and lands on the authenticated home with the
// seeded creature loaded — the storageState equivalent Phase 4's persistence
// test is built on. (This is the auth analogue of smoke_test.dart's toolchain
// canary.)
//
// Run from tamagotchi_flutter/ — seed the fixture first, run, then tear it down
// (sidecars always up; API booted via `serverpod run e2e` in tamagotchi_server/):
//   # in tamagotchi_server/:
//   dart tool/e2e_seed.dart seed --email e2e-harness@tamagotchi.test
//   # in tamagotchi_flutter/:
//   patrol test --target integration_test/auth_harness_test.dart \
//     -d chrome --web-headless true --web-port 7357 --web-locale en-US
//   # in tamagotchi_server/:
//   dart tool/e2e_seed.dart teardown --email e2e-harness@tamagotchi.test
//
// The default credentials in helpers/auth.dart match the fixed fixture above, so
// no `--dart-define` is needed for this canary. Phase 4's test threads a unique
// per-run identity through `--dart-define=E2E_EMAIL/E2E_PASSWORD`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/auth.dart';

void main() {
  patrolTest(
    'login-once reaches the home and the session survives a reload',
    ($) async {
      await loginOnce($);

      // The signed-in affordance proves we're on the home, not bounced to
      // /sign-in.
      expect($('Log out'), findsOneWidget);

      // The seeded creature round-tripped (auth → API → DB): its stats view
      // rendered, so we land on CreatureView (a stat-row Key), not the hatch
      // empty state.
      await $(const Key('statRow-Hunger')).waitUntilVisible();

      // The soft spot (Phase 3 manual 3.3): a fresh-client reload must restore
      // the persisted JWT — still on the authenticated home, NOT bounced to
      // /sign-in. This is the storageState-survives-reload guarantee Phase 4's
      // persistence assertion is built on.
      await reloadAndSettle($);
      await $('AI-Tamagotchi').waitUntilVisible();
      expect($('Log out'), findsOneWidget);
      expect($('Sign in'), findsNothing);
      // The seeded creature is still loaded after the reload, too.
      await $(const Key('statRow-Hunger')).waitUntilVisible();
    },
  );
}
