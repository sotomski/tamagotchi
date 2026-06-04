// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Serverpod [Client] used to talk to the server.
///
/// The body throws because the real instance is constructed in `main()` and
/// supplied at the app root via `serverpodClientProvider.overrideWithValue(...)`.
/// Consumers read it with `ref.read(serverpodClientProvider)` (or `ref.watch`
/// inside a `build`) instead of the old global at `main.dart`.

@ProviderFor(serverpodClient)
final serverpodClientProvider = ServerpodClientProvider._();

/// The Serverpod [Client] used to talk to the server.
///
/// The body throws because the real instance is constructed in `main()` and
/// supplied at the app root via `serverpodClientProvider.overrideWithValue(...)`.
/// Consumers read it with `ref.read(serverpodClientProvider)` (or `ref.watch`
/// inside a `build`) instead of the old global at `main.dart`.

final class ServerpodClientProvider
    extends $FunctionalProvider<Client, Client, Client>
    with $Provider<Client> {
  /// The Serverpod [Client] used to talk to the server.
  ///
  /// The body throws because the real instance is constructed in `main()` and
  /// supplied at the app root via `serverpodClientProvider.overrideWithValue(...)`.
  /// Consumers read it with `ref.read(serverpodClientProvider)` (or `ref.watch`
  /// inside a `build`) instead of the old global at `main.dart`.
  ServerpodClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverpodClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverpodClientHash();

  @$internal
  @override
  $ProviderElement<Client> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Client create(Ref ref) {
    return serverpodClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Client value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Client>(value),
    );
  }
}

String _$serverpodClientHash() => r'33c8d936e7da76b577dee610756c80e2bbcf0080';
