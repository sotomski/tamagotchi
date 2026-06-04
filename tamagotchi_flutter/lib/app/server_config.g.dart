// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The resolved Serverpod server URL.
///
/// The body throws because the real value is supplied at the app root via
/// `serverUrlProvider.overrideWithValue(...)` in `main()`, after
/// `getServerUrl()` resolves it. Holding it as a provider lets later features
/// (e.g. environment-pinned feature flags) read the URL without reaching into
/// `main.dart`.

@ProviderFor(serverUrl)
final serverUrlProvider = ServerUrlProvider._();

/// The resolved Serverpod server URL.
///
/// The body throws because the real value is supplied at the app root via
/// `serverUrlProvider.overrideWithValue(...)` in `main()`, after
/// `getServerUrl()` resolves it. Holding it as a provider lets later features
/// (e.g. environment-pinned feature flags) read the URL without reaching into
/// `main.dart`.

final class ServerUrlProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The resolved Serverpod server URL.
  ///
  /// The body throws because the real value is supplied at the app root via
  /// `serverUrlProvider.overrideWithValue(...)` in `main()`, after
  /// `getServerUrl()` resolves it. Holding it as a provider lets later features
  /// (e.g. environment-pinned feature flags) read the URL without reaching into
  /// `main.dart`.
  ServerUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverUrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverUrlHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return serverUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$serverUrlHash() => r'1e91262cdea2e22b0effe85b97240d141da90384';
