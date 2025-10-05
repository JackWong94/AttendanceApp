/// Environment variables for Firebase configuration.
/// Values are injected at build/run time with `--dart-define-from-file`.
class Env {
  static const firebaseApiKey =
  String.fromEnvironment('apiKey');
  static const firebaseAuthDomain =
  String.fromEnvironment('authDomain');
  static const firebaseProjectId =
  String.fromEnvironment('projectId');
  static const firebaseStorageBucket =
  String.fromEnvironment('storageBucket');
  static const firebaseMessagingSenderId =
  String.fromEnvironment('messagingSenderId');
  static const firebaseAppId =
  String.fromEnvironment('appId');
  static const firebaseMeasurementId =
  String.fromEnvironment('measurementId');
}

/*
//Place this into main() to debug for the retrieving of API
//Strictly do not expose key to the public

print('🔑 API Key: ${opts.apiKey}');
print('🆔 App ID: ${opts.appId}');
print('📂 Project ID: ${opts.projectId}');
print('📤 Messaging Sender ID: ${opts.messagingSenderId}');
print('📦 Storage Bucket: ${opts.storageBucket}');
print('🌐 Auth Domain: ${opts.authDomain}');
print('📊 Measurement ID: ${opts.measurementId}');
*/
