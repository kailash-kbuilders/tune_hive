/// Build-time configuration for TuneHive.
///
/// Everything here is compiled into the app, so a released APK needs no
/// setup from the person using it.

/// Jamendo Client ID, taken from `--dart-define=JAMENDO_CLIENT_ID=...` at
/// build time. The GitHub workflow passes it from the repository secret
/// JAMENDO_CLIENT_ID, so you can change it without touching any code.
const String kJamendoClientIdFromEnv =
    String.fromEnvironment('JAMENDO_CLIENT_ID', defaultValue: '');

/// Hardcoded fallback. Paste your Client ID between the quotes if you prefer
/// editing code over using the secret. Leave empty to skip.
///
/// Get one free: https://devportal.jamendo.com -> sign up -> My Apps ->
/// Create an Application -> copy the "Client ID" (NOT the Client Secret).
const String kJamendoClientId = '';

/// The Client ID the app should use, or an empty string when none is set.
/// Order: build-time define, then the constant above, then whatever the user
/// typed in Profile -> Jamendo API key.
const String kBuiltInJamendoClientId =
    kJamendoClientIdFromEnv != '' ? kJamendoClientIdFromEnv : kJamendoClientId;

bool get hasBuiltInJamendoClientId => kBuiltInJamendoClientId.trim().isNotEmpty;
