import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';

part 'journal_provider.g.dart';

/// The signed-in user's full journal, newest-first, **including** the empty-prose
/// `hatched` origin marker (the screen renders it as the "Day one" card).
///
/// Mirrors [creatureProvider]: an async-data provider over the generated
/// Serverpod client, consumed via `AsyncValue.when` and refreshed by
/// invalidation (`ref.invalidate(journalProvider)` on the error-retry path).
@Riverpod(keepAlive: true)
Future<List<JournalEntry>> journal(Ref ref) {
  return ref.read(serverpodClientProvider).creature.readJournal();
}
