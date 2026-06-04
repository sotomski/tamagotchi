import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

part 'client_provider.g.dart';

/// The Serverpod [Client] used to talk to the server.
///
/// The body throws because the real instance is constructed in `main()` and
/// supplied at the app root via `serverpodClientProvider.overrideWithValue(...)`.
/// Consumers read it with `ref.read(serverpodClientProvider)` (or `ref.watch`
/// inside a `build`) instead of the old global at `main.dart`.
@Riverpod(keepAlive: true)
Client serverpodClient(Ref ref) => throw UnimplementedError(
  'serverpodClientProvider must be overridden at the app root',
);
