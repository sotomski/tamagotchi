import 'dart:io';

// Prefixed: `mailer` exports `Message`, which collides with relic_core's
// `Message` re-exported transitively through `package:serverpod/serverpod.dart`.
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart' show SmtpServer;
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

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // Initialize authentication services for the server.
  // Token managers will be used to validate and issue authentication keys,
  // and the identity providers will be the authentication options available for users.
  //
  // In `development` run mode we override the registration verification code with a
  // fixed value (`_devRegistrationVerificationCode`) so sign-up can be completed in
  // the UI without a real mailer — `_sendRegistrationCode` just logs the code. Every
  // other run mode omits the override and keeps the package default (a secure random
  // 8-character code), which the registration send-callback delivers to the user.
  final emailIdpConfig = pod.runMode == 'development'
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
  // In `development` there is no mailer wired: just log the (static) code so it
  // can be entered manually in the UI. Every other run mode delivers the random
  // default code over EmailLabs SMTP.
  if (session.serverpod.runMode == 'development') {
    session.log('[EmailIdp] Registration code ($email): $verificationCode');
    return;
  }
  await _sendVerificationEmail(
    session,
    recipient: email,
    subject: 'Verify your AI-Tamagotchi account',
    body: 'Welcome to AI-Tamagotchi!\n\n'
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
  // Same run-mode gate as registration: log-only in `development`, real SMTP
  // delivery via EmailLabs otherwise.
  if (session.serverpod.runMode == 'development') {
    session.log('[EmailIdp] Password reset code ($email): $verificationCode');
    return;
  }
  await _sendVerificationEmail(
    session,
    recipient: email,
    subject: 'Reset your AI-Tamagotchi password',
    body: 'A password reset was requested for your AI-Tamagotchi account.\n\n'
        'Your password reset code is: $verificationCode\n\n'
        'If you did not request this, you can safely ignore this email.',
  );
}

/// Sends a plain-text verification email via EmailLabs SMTP. Called only outside
/// `development`; the SMTP-account credentials and verified From-address come
/// from the server password map (`emaillabsSmtp*`), provisioned out-of-band via
/// `scloud secret set` — never committed to the repo.
///
/// NOTE: EmailLabs SMTP auth uses the dedicated "SMTP account" credential
/// (`1.<panelname>.smtp` + its own password), NOT the REST API AppKey/SecretKey.
/// Host `smtp.emaillabs.net.pl`, STARTTLS on 587 (`ssl: false`, the library
/// upgrades the connection via the `starttls` command).
Future<void> _sendVerificationEmail(
  Session session, {
  required String recipient,
  required String subject,
  required String body,
}) async {
  final smtpServer = SmtpServer(
    'smtp.emaillabs.net.pl',
    port: 587,
    ssl: false,
    allowInsecure: false,
    username: session.passwords['emaillabsSmtpUser']!,
    password: session.passwords['emaillabsSmtpPassword']!,
  );

  final message = mailer.Message()
    ..from = session.passwords['emaillabsSmtpFrom']!
    ..recipients.add(recipient)
    ..subject = subject
    ..text = body;

  try {
    await mailer.send(message, smtpServer);
  } on mailer.MailerException catch (e, stackTrace) {
    session.log(
      '[EmailIdp] Failed to send verification email to $recipient',
      level: LogLevel.error,
      exception: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
