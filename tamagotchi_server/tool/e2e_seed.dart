// e2e seed/teardown fixture (Phase 3, playwright-for-flutter).
//
// Creates — or removes — a deterministic e2e fixture in `tamagotchi_test`:
//   • a REAL auth user (email + password) the patrol browser can log into, and
//   • a HUNGRY creature (+ its 1:1 personality) owned by that user.
//
// Why out-of-process, and why hungry: the Feed persistence risk (Phase 4) needs
// an ACCEPTED feed — a stat drop AND a journal entry — to survive a page reload.
// A freshly hatched creature has `hunger == 0` (full: see `baselineCreatureStats`
// in creature_service.dart), so Feed is refused with no journal entry (the same
// reason `feed_endpoint_test.dart` seeds creatures directly). The browser can't
// insert DB rows, so this seeds them server-embedded against the SAME
// `tamagotchi_test` DB the running e2e server (`serverpod run e2e`) reads.
//
// The seeded password hash and the e2e server's login check both use the
// `emailSecretHashPepper` from `config/passwords.yaml` (shared section). Running
// this script under `--mode test` (which the e2e server also boots under) makes
// the pepper — and the `tamagotchi_test` DB — identical on both sides, so the
// password verifies at login.
//
// Usage (sidecars are always up; the DB is migrated by the running e2e server):
//   dart tool/e2e_seed.dart seed     --email <e> [--password <p>] [--name <n>] [--hunger <h>]
//   dart tool/e2e_seed.dart teardown --email <e>
//
// `seed` is re-runnable: it tears down any prior fixture for the same email
// first, so the one-creature-per-owner and email-unique indexes never collide on
// a repeat run. It prints a machine-readable summary line so a wrapper can
// capture the email/password and thread them into `patrol test` via
// `--dart-define=E2E_EMAIL=… --dart-define=E2E_PASSWORD=…` (see
// integration_test/helpers/auth.dart and the Phase 6 cookbook).
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:tamagotchi_server/src/generated/endpoints.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';

/// Default strong password for the seeded account (overridable via `--password`).
/// The default matches `helpers/auth.dart`'s `--dart-define` fallback so the
/// fixed harness fixture works with no extra wiring.
const _defaultPassword = 'e2e-Passw0rd!';

/// Default hunger for the seeded creature — high enough that the picky/accept
/// gate can fire (a fed creature writes a journal entry). 80 mirrors the value
/// `feed_endpoint_test.dart` uses for its accepted-feed cases.
const _defaultHunger = 80;

/// Default creature name when `--name` is omitted.
const _defaultName = 'Persisty';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _usageAndExit();
  final command = args.first;
  final options = _parseOptions(args.skip(1));

  final email = options['email'];
  if (email == null || email.isEmpty) {
    stderr.writeln('error: --email is required');
    _usageAndExit();
  }

  // Boot Serverpod in `test` mode WITHOUT serving HTTP. The constructor starts
  // the DB pool (serverpod.dart:558 — "the database is connected when the
  // Serverpod is created … such as createSession(...)"), so `createSession()`
  // works without `pod.start()`. We deliberately never call `start()`: that
  // would bind the API port and collide with the running e2e server on :8080.
  // We pass a clean `['--mode', 'test']` so the seed subcommand never reaches
  // Serverpod's own arg parser.
  final pod = Serverpod(['--mode', 'test'], Protocol(), Endpoints());
  try {
    final session = await pod.createSession(enableLogging: false);
    try {
      switch (command) {
        case 'seed':
          await _seed(
            session,
            email: email,
            password: options['password'] ?? _defaultPassword,
            name: options['name'] ?? _defaultName,
            hunger: int.tryParse(options['hunger'] ?? '') ?? _defaultHunger,
          );
        case 'teardown':
          await _teardown(session, email: email);
        default:
          stderr.writeln('error: unknown command "$command"');
          _usageAndExit();
      }
    } finally {
      await session.close();
    }
  } finally {
    // Close the DB pool so the script exits; don't let Serverpod kill the process
    // (we want our own clean return).
    await pod.shutdown(exitProcess: false);
  }
}

/// Seeds the auth user + hungry creature for [email]. Re-runnable: any prior
/// fixture for the same email is removed first.
Future<void> _seed(
  Session session, {
  required String email,
  required String password,
  required String name,
  required int hunger,
}) async {
  // Idempotency: clear a prior fixture for this email so a fixed-email re-run
  // never trips the email-unique or one-creature-per-owner constraints.
  await _teardown(session, email: email, quiet: true);

  // All inserts run in one transaction so a mid-seed failure commits nothing —
  // no orphan rows (an auth user with no creature, etc.) left behind in
  // `tamagotchi_test`. The in-process exemplar (feed_endpoint_test.dart) gets
  // this atomicity for free via `withServerpod` rollback; out-of-process we
  // wrap it explicitly. The auth-module writes and the ORM inserts all accept
  // the same `Transaction`, so they enlist in one unit of work.
  final (ownerUuid, creatureId) = await session.db.transaction((
    transaction,
  ) async {
    // 1. A real auth user — its id IS the `userIdentifier` the JWT carries and
    //    the value the creature/feed endpoints read as `ownerUuid`.
    final authUser = await AuthUsers().create(
      session,
      transaction: transaction,
    );
    final ownerUuid = authUser.id;

    // 2. An email/password login for that user. The admin path skips the
    //    verification-code dance and writes an active account directly; the hash
    //    uses the shared `emailSecretHashPepper`, so the e2e server's login check
    //    (same pepper) verifies it.
    final admin = EmailIdpAdmin(
      utils: EmailIdpUtils(config: EmailIdpConfigFromPasswords()),
    );
    await admin.createEmailAuthentication(
      session,
      authUserId: ownerUuid,
      email: email,
      password: password,
      transaction: transaction,
    );

    // 3. The hungry creature + its 1:1 personality, owned by that user (mirrors
    //    feed_endpoint_test.dart's `_seedCreature`, but for a real out-of-process
    //    DB and a real owner).
    final creature = await Creature.db.insertRow(
      session,
      Creature(
        ownerUuid: ownerUuid,
        name: name,
        hunger: hunger,
        energy: 100,
        love: 50,
        illness: 0,
      ),
      transaction: transaction,
    );
    await CreaturePersonality.db.insertRow(
      session,
      CreaturePersonality(
        creatureId: creature.id!,
        hungerDecayMod: 1.0,
        hungerRegenMod: 1.0,
        energyDecayMod: 1.0,
        energyRegenMod: 1.0,
        loveRegenMod: 1.0,
        illnessDecayMod: 1.0,
        illnessRegenMod: 1.0,
      ),
      transaction: transaction,
    );
    return (ownerUuid, creature.id!);
  });

  // Machine-readable summary (a wrapper can grep this to thread the credentials
  // into `patrol test --dart-define=…`).
  stdout.writeln(
    'seeded email=$email password=$password '
    'authUserId=$ownerUuid creatureId=$creatureId '
    'name=$name hunger=$hunger',
  );
}

/// Removes the fixture for [email]: the creature-owned rows, then the auth rows.
/// No-op (not an error) when nothing exists, so it doubles as the idempotent
/// pre-seed cleanup. Pass [quiet] to suppress the "nothing to do" line.
Future<void> _teardown(
  Session session, {
  required String email,
  bool quiet = false,
}) async {
  final admin = EmailIdpAdmin(
    utils: EmailIdpUtils(config: EmailIdpConfigFromPasswords()),
  );

  final account = await admin.findAccount(session, email: email);
  if (account == null) {
    if (!quiet) {
      stdout.writeln('teardown: no account for $email (nothing to do)');
    }
    return;
  }
  final ownerUuid = account.authUserId;

  // Creature-owned rows have no cross-module FK to the auth user, so delete them
  // explicitly (children before parents) before removing the auth rows.
  final creatures = await Creature.db.find(
    session,
    where: (t) => t.ownerUuid.equals(ownerUuid),
  );
  for (final creature in creatures) {
    await JournalEntry.db.deleteWhere(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
    );
    await CreaturePersonality.db.deleteWhere(
      session,
      where: (t) => t.creatureId.equals(creature.id!),
    );
  }
  await Creature.db.deleteWhere(
    session,
    where: (t) => t.ownerUuid.equals(ownerUuid),
  );

  // Auth rows: the email account (cascades its reset/login-attempt rows) and the
  // auth user itself.
  await admin.deleteEmailAccount(session, email: email);
  await AuthUsers().delete(session, authUserId: ownerUuid);

  if (!quiet) {
    stdout.writeln('torn down email=$email authUserId=$ownerUuid');
  }
}

/// Parses `--key value` pairs (a flag with no following value becomes '').
Map<String, String> _parseOptions(Iterable<String> args) {
  final list = args.toList();
  final options = <String, String>{};
  for (var i = 0; i < list.length; i++) {
    final arg = list[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    final hasValue = i + 1 < list.length && !list[i + 1].startsWith('--');
    options[key] = hasValue ? list[++i] : '';
  }
  return options;
}

Never _usageAndExit() {
  stderr.writeln(
    'usage:\n'
    '  dart tool/e2e_seed.dart seed     --email <e> [--password <p>] [--name <n>] [--hunger <h>]\n'
    '  dart tool/e2e_seed.dart teardown --email <e>\n'
    '\n'
    'Run from tamagotchi_server/ with the Postgres sidecars up. Seeds/removes the\n'
    'patrol e2e fixture in tamagotchi_test (see integration_test/helpers/auth.dart).',
  );
  exit(64);
}
