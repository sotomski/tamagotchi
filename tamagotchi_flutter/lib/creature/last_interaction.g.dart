// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_interaction.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the [InteractionOutcome] of the most recent Feed *or* Play. `null`
/// before the first interaction. Both controllers write it on success
/// (Feed passes its `accepted`; Play always passes `true`); [CreatureView] reads
/// it to render the shared response box.

@ProviderFor(LastInteraction)
final lastInteractionProvider = LastInteractionProvider._();

/// Holds the [InteractionOutcome] of the most recent Feed *or* Play. `null`
/// before the first interaction. Both controllers write it on success
/// (Feed passes its `accepted`; Play always passes `true`); [CreatureView] reads
/// it to render the shared response box.
final class LastInteractionProvider
    extends $NotifierProvider<LastInteraction, InteractionOutcome?> {
  /// Holds the [InteractionOutcome] of the most recent Feed *or* Play. `null`
  /// before the first interaction. Both controllers write it on success
  /// (Feed passes its `accepted`; Play always passes `true`); [CreatureView] reads
  /// it to render the shared response box.
  LastInteractionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastInteractionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastInteractionHash();

  @$internal
  @override
  LastInteraction create() => LastInteraction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InteractionOutcome? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InteractionOutcome?>(value),
    );
  }
}

String _$lastInteractionHash() => r'32760b64b63eea5d21e24ad2704914f164cbec64';

/// Holds the [InteractionOutcome] of the most recent Feed *or* Play. `null`
/// before the first interaction. Both controllers write it on success
/// (Feed passes its `accepted`; Play always passes `true`); [CreatureView] reads
/// it to render the shared response box.

abstract class _$LastInteraction extends $Notifier<InteractionOutcome?> {
  InteractionOutcome? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<InteractionOutcome?, InteractionOutcome?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InteractionOutcome?, InteractionOutcome?>,
              InteractionOutcome?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
