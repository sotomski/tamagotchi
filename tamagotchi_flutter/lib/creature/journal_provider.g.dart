// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's full journal, newest-first, **including** the empty-prose
/// `hatched` origin marker (the screen renders it as the "Day one" card).
///
/// Mirrors [creatureProvider]: an async-data provider over the generated
/// Serverpod client, consumed via `AsyncValue.when` and refreshed by
/// invalidation (`ref.invalidate(journalProvider)` on the error-retry path).

@ProviderFor(journal)
final journalProvider = JournalProvider._();

/// The signed-in user's full journal, newest-first, **including** the empty-prose
/// `hatched` origin marker (the screen renders it as the "Day one" card).
///
/// Mirrors [creatureProvider]: an async-data provider over the generated
/// Serverpod client, consumed via `AsyncValue.when` and refreshed by
/// invalidation (`ref.invalidate(journalProvider)` on the error-retry path).

final class JournalProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JournalEntry>>,
          List<JournalEntry>,
          FutureOr<List<JournalEntry>>
        >
    with
        $FutureModifier<List<JournalEntry>>,
        $FutureProvider<List<JournalEntry>> {
  /// The signed-in user's full journal, newest-first, **including** the empty-prose
  /// `hatched` origin marker (the screen renders it as the "Day one" card).
  ///
  /// Mirrors [creatureProvider]: an async-data provider over the generated
  /// Serverpod client, consumed via `AsyncValue.when` and refreshed by
  /// invalidation (`ref.invalidate(journalProvider)` on the error-retry path).
  JournalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalHash();

  @$internal
  @override
  $FutureProviderElement<List<JournalEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<JournalEntry>> create(Ref ref) {
    return journal(ref);
  }
}

String _$journalHash() => r'f2967af636f92c389df3d9bb6d5bea129a0a7f3b';
