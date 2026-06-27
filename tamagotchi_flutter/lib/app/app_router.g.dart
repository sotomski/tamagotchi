// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [GoRouter] with the S-01 auth gate.
///
/// Watches [serverpodClientProvider] for `client.auth`: a `redirect` bounces
/// unauthenticated users to `/sign-in` and keeps authenticated users on the
/// app surface, while `refreshListenable` re-evaluates the redirect live on
/// every sign-in / sign-out (the listenable fires when `authInfo` changes).

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The app's [GoRouter] with the S-01 auth gate.
///
/// Watches [serverpodClientProvider] for `client.auth`: a `redirect` bounces
/// unauthenticated users to `/sign-in` and keeps authenticated users on the
/// app surface, while `refreshListenable` re-evaluates the redirect live on
/// every sign-in / sign-out (the listenable fires when `authInfo` changes).

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app's [GoRouter] with the S-01 auth gate.
  ///
  /// Watches [serverpodClientProvider] for `client.auth`: a `redirect` bounces
  /// unauthenticated users to `/sign-in` and keeps authenticated users on the
  /// app surface, while `refreshListenable` re-evaluates the redirect live on
  /// every sign-in / sign-out (the listenable fires when `authInfo` changes).
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'521446bfb3cb70e3415f7c87958a3c3b271a55d7';
