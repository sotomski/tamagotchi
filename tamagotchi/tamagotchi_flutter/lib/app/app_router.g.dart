// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [GoRouter].
///
/// A flat two-route map. No auth guard yet — S-01 adds the redirect via a
/// `refreshListenable` tied to `client.auth.authInfoListenable`.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The app's [GoRouter].
///
/// A flat two-route map. No auth guard yet — S-01 adds the redirect via a
/// `refreshListenable` tied to `client.auth.authInfoListenable`.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app's [GoRouter].
  ///
  /// A flat two-route map. No auth guard yet — S-01 adds the redirect via a
  /// `refreshListenable` tied to `client.auth.authInfoListenable`.
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

String _$appRouterHash() => r'b1e639a3e5484e89b633af5e9834f4486f3fdd6f';
