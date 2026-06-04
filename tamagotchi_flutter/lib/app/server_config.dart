import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_config.g.dart';

/// The resolved Serverpod server URL.
///
/// The body throws because the real value is supplied at the app root via
/// `serverUrlProvider.overrideWithValue(...)` in `main()`, after
/// `getServerUrl()` resolves it. Holding it as a provider lets later features
/// (e.g. environment-pinned feature flags) read the URL without reaching into
/// `main.dart`.
@Riverpod(keepAlive: true)
String serverUrl(Ref ref) =>
    throw UnimplementedError('serverUrlProvider must be overridden at the app root');
