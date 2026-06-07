import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/web/routes/app_config_route.dart';
import 'src/web/routes/root.dart';

/// Fixed registration verification code used in `development` run mode so sign-up
/// can be completed in the Flutter UI without a real mailer. Its length (8) matches
/// the package default (`defaultVerificationCodeGenerator`); every other run mode
/// uses that random default and delivers it by email.
const _devRegistrationVerificationCode = '12345678';

/// Run modes that behave like local development for the no-mailer conveniences:
/// the fixed registration verification code and the log-only email send-callbacks.
///
/// `development` is the everyday local mode; `e2e` is the identity the patrol
/// browser tests boot under — a `test`-mode overlay (see [_e2eConfigOverride]).
/// e2e sign-up must complete without a real mailer, so it gets the same fixed
/// code + log-only callbacks. Every other run mode (test/staging/production)
/// keeps the secure random code delivered over EmailLabs.
bool _isLocalDevMode(String runMode) =>
    runMode == 'development' || runMode == 'e2e';

/// When the `TAMAGOTCHI_E2E` env flag is set, returns a config transform that
/// turns the booted `test` run mode into the `e2e` identity the patrol browser
/// tests need; otherwise null, so the normal config is used unchanged.
///
/// Serverpod 3.x has no first-class custom run mode — the CLI `--mode` enum is
/// development/test/staging/production — so `e2e` is realised as a thin overlay
/// on `test`. The patrol tests boot `--mode test`, which loads the hermetic
/// `test:` passwords (no `mistralApiKey`, so `llmServiceFor` returns the
/// deterministic StubLlmService) and points at the `tamagotchi_test` database.
/// This override then (1) pins the apiServer to the fixed :8080 the patrol-served
/// Flutter web build expects (test.yaml uses a dynamic port 0), and (2) stamps
/// `runMode` as `e2e` so [_isLocalDevMode] enables the no-mailer dev-auth
/// conveniences. DB + peppers are inherited from `test`.
ServerpodConfig Function(ServerpodConfig)? _e2eConfigOverride() {
  if (Platform.environment['TAMAGOTCHI_E2E'] != 'true') return null;
  return (config) => config.copyWith(
    runMode: 'e2e',
    apiServer: ServerConfig(
      port: 8080,
      publicHost: 'localhost',
      publicPort: 8080,
      publicScheme: 'http',
    ),
  );
}

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code. The
  // `configOverride` is the seam for the `e2e` run mode (patrol browser tests) —
  // null in every normal boot. See [_e2eConfigOverride].
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    configOverride: _e2eConfigOverride(),
  );

  // Initialize authentication services for the server.
  // Token managers will be used to validate and issue authentication keys,
  // and the identity providers will be the authentication options available for users.
  //
  // In local-dev run modes (`development` + `e2e`) we override the registration
  // verification code with a fixed value (`_devRegistrationVerificationCode`) so
  // sign-up can be completed in the UI / browser tests without a real mailer —
  // `_sendRegistrationCode` just logs the code. Every other run mode omits the
  // override and keeps the package default (a secure random 8-character code),
  // which the registration send-callback delivers to the user.
  final emailIdpConfig = _isLocalDevMode(pod.runMode)
      ? EmailIdpConfigFromPasswords(
          sendRegistrationVerificationCode: _sendRegistrationCode,
          sendPasswordResetVerificationCode: _sendPasswordResetCode,
          registrationVerificationCodeGenerator: () =>
              _devRegistrationVerificationCode,
        )
      : EmailIdpConfigFromPasswords(
          sendRegistrationVerificationCode: _sendRegistrationCode,
          sendPasswordResetVerificationCode: _sendPasswordResetCode,
        );

  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      JwtConfigFromPasswords(),
    ],
    identityProviderBuilders: [
      // Configure the email identity provider for email/password authentication.
      emailIdpConfig,
    ],
  );

  // Setup a default page at the web root.
  // These are used by the default page.
  pod.webServer.addRoute(RootRoute(), '/');
  pod.webServer.addRoute(RootRoute(), '/index.html');

  // Serve all files in the web/static relative directory under /.
  // These are used by the default web page.
  final root = Directory(Uri(path: 'web/static').toFilePath());
  pod.webServer.addRoute(StaticRoute.directory(root));

  // Setup the app config route.
  // We build this configuration based on the servers api url and serve it to
  // the flutter app.
  pod.webServer.addRoute(
    AppConfigRoute(apiConfig: pod.config.apiServer),
    '/app/assets/assets/config.json',
  );

  // Checks if the flutter web app has been built and serves it if it has.
  final appDir = Directory(Uri(path: 'web/app').toFilePath());
  if (appDir.existsSync()) {
    // Serve the flutter web app under the /app path.
    pod.webServer.addRoute(
      FlutterRoute(
        Directory(
          Uri(path: 'web/app').toFilePath(),
        ),
      ),
      '/app',
    );
  } else {
    // If the flutter web app has not been built, serve the build app page.
    pod.webServer.addRoute(
      StaticRoute.file(
        File(
          Uri(path: 'web/pages/build_flutter_app.html').toFilePath(),
        ),
      ),
      '/app/**',
    );
  }

  // Start the server.
  await pod.start();
}

Future<void> _sendRegistrationCode(
  Session session, {
  required String email,
  required UuidValue accountRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) async {
  // In local-dev run modes (`development` + `e2e`) no email is sent: just log the
  // (static) code so it can be entered manually in the UI / by browser tests.
  // Every other run mode delivers the random default code over EmailLabs
  // (new_sendmail REST over 443).
  if (_isLocalDevMode(session.serverpod.runMode)) {
    session.log('[EmailIdp] Registration code ($email): $verificationCode');
    return;
  }
  await _sendVerificationEmail(
    session,
    recipient: email,
    subject: 'Verify your AI-Tamagotchi account',
    body:
        'Welcome to AI-Tamagotchi!\n\n'
        'Your verification code is: $verificationCode\n\n'
        'Enter this code in the app to finish creating your account.',
  );
}

Future<void> _sendPasswordResetCode(
  Session session, {
  required String email,
  required UuidValue passwordResetRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) async {
  // Same run-mode gate as registration: log-only in local-dev modes
  // (`development` + `e2e`), real delivery via EmailLabs (new_sendmail REST over
  // 443) otherwise.
  if (_isLocalDevMode(session.serverpod.runMode)) {
    session.log('[EmailIdp] Password reset code ($email): $verificationCode');
    return;
  }
  await _sendVerificationEmail(
    session,
    recipient: email,
    subject: 'Reset your AI-Tamagotchi password',
    body:
        'A password reset was requested for your AI-Tamagotchi account.\n\n'
        'Your password reset code is: $verificationCode\n\n'
        'If you did not request this, you can safely ignore this email.',
  );
}

/// Sends a plain-text verification email via EmailLabs' `new_sendmail` REST API
/// over HTTPS (443). Called only outside `development`.
///
/// scloud blocks outbound SMTP egress (25/465/587), so the send goes over 443 to
/// EmailLabs' transactional REST endpoint instead of SMTP. REST auth is HTTP Basic
/// with the EmailLabs **AppKey:SecretKey** (panel → Administrator → API) — NOT the
/// SMTP-account password. The SMTP-account identifier (`1.<panelname>.smtp`)
/// survives only as the `smtp_account` body param; its SMTP password is unused.
/// Credentials + the verified From-address come from the server password map
/// (`emaillabsApiKey` / `emaillabsApiSecret` / `emaillabsSmtpUser` /
/// `emaillabsSmtpFrom`), provisioned out-of-band via `scloud secret set` — never
/// committed to the repo. Body stays plain text (the `text` param); no HTML.
Future<void> _sendVerificationEmail(
  Session session, {
  required String recipient,
  required String subject,
  required String body,
}) async {
  // EmailLabs REST auth: Basic base64(AppKey:SecretKey) — NOT the smtp_account
  // password. The smtp_account identifier below is only a body param.
  final auth = base64Encode(
    utf8.encode(
      '${session.passwords['emaillabsApiKey']}:'
      '${session.passwords['emaillabsApiSecret']}',
    ),
  );

  final http.Response response;
  try {
    // Content-Type defaults to application/x-www-form-urlencoded for a Map body;
    // the array-style `to[<email>]` key carries the recipient (value = name|'').
    response = await http.post(
      Uri.parse('https://api.emaillabs.net.pl/api/new_sendmail'),
      headers: {'authorization': 'Basic $auth'},
      body: {
        'smtp_account': session.passwords['emaillabsSmtpUser']!,
        'from': session.passwords['emaillabsSmtpFrom']!,
        'subject': subject,
        'text': body,
        'to[$recipient]': '',
      },
    );
  } catch (e, stackTrace) {
    // No HTTP response at all (DNS/socket/egress failure) — fail loudly.
    session.log(
      '[EmailIdp] Failed to reach EmailLabs to send verification email to '
      '$recipient',
      level: LogLevel.error,
      exception: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }

  // EmailLabs returns JSON {code,status,message,data}; success == status:"success".
  String? status;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['status'] is String) {
      status = decoded['status'] as String;
    }
  } catch (_) {
    // Non-JSON body — leave status null so the guard below treats it as failure.
  }

  final ok =
      response.statusCode >= 200 &&
      response.statusCode < 300 &&
      status == 'success';
  if (!ok) {
    session.log(
      '[EmailIdp] EmailLabs new_sendmail rejected the send to $recipient '
      '(HTTP ${response.statusCode}): ${response.body}',
      level: LogLevel.error,
    );
    // A verification-code flow must fail loudly when no code can be delivered:
    // throw so registration/reset surfaces the failure instead of silently
    // appearing to succeed with no email sent (Q4=A, parity with the prior
    // SMTP rethrow).
    throw Exception(
      'EmailLabs new_sendmail failed (HTTP ${response.statusCode}, '
      'status "$status")',
    );
  }
}
