/// Environment variables for Firebase configuration.
/// Values are injected at build/run time with `--dart-define-from-file`.
class Env {
  static const firebaseApiKey =
  String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId =
  String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseProjectId =
  String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseMessagingSenderId =
  String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseMeasurementId =
  String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  static const firebaseStorageBucket =
  String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseAuthDomain =
  String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
}
