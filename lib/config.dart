import 'package:dartstream_client/dartstream_client.dart';

/// Compile-time configuration injected via --dart-define.
///
/// OAuth2 Grant Type used by this application:
/// ─────────────────────────────────────────────────────────────────────────
/// Grant: Firebase Resource Owner Password Credentials → DartStream Bearer
///
/// Flow:
///   1. User provides email + password.
///   2. App calls Firebase Identity Toolkit (accounts:signInWithPassword)
///      using [firebaseApiKey] as the OAuth2 client_id.
///   3. Firebase issues an RS256-signed ID Token (Bearer JWT).
///   4. DartStreamClient.onboardFirebaseSession() exchanges the Firebase
///      ID Token for a DartStream tenant session (userId + tenantId).
///   5. All subsequent DartStream API calls attach the Bearer token via
///      the Authorization: Bearer <idToken> header.
///
/// What [firebaseApiKey] IS:
///   The Firebase Web API Key is the OAuth2 client_id that identifies this
///   web application to the Firebase / DartStream SaaS identity provider.
///   It is public-safe (browser-visible) but must never be committed.
///
/// OAuth2 client credentials (oauthClientId / oauthClientSecret):
///   Additional registered OAuth2 client credentials from the DartStream
///   dashboard. Configure when the DartStream platform requires explicit
///   OAuth2 client registration for ds-experience / ds-reactive access.
/// ─────────────────────────────────────────────────────────────────────────
class AppConfig {
  // Firebase Web API Key — OAuth2 client_id for this web app.
  static const firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');

  static bool get hasFirebaseApiKey => firebaseApiKey.isNotEmpty;

  // OAuth2 client_id registered in the DartStream dashboard.
  static const oauthClientId =
      String.fromEnvironment('OAUTH_CLIENT_ID');

  // OAuth2 client_secret registered in the DartStream dashboard.
  // Never log or expose this value.
  static const oauthClientSecret =
      String.fromEnvironment('OAUTH_CLIENT_SECRET');

  static bool get hasOAuthCredentials =>
      oauthClientId.isNotEmpty && oauthClientSecret.isNotEmpty;

  // DartStream SDK config targeting the live dev environment.
  static DartStreamConfig get dartStream =>
      DartStreamConfig.dev(firebaseApiKey: firebaseApiKey);
}
