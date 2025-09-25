// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'configs_and_tools/env.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    // Keep switch-case but non-web will throw
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Web. '
              'Run FlutterFire CLI again to set up other platforms.',
        );
    }
  }

  /// ✅ Web configuration using Env
  static final FirebaseOptions web = FirebaseOptions(
    apiKey: Env.firebaseApiKey,
    authDomain: Env.firebaseAuthDomain,
    projectId: Env.firebaseProjectId,
    storageBucket: Env.firebaseStorageBucket,
    messagingSenderId: Env.firebaseMessagingSenderId,
    appId: Env.firebaseAppId,
    measurementId: Env.firebaseMeasurementId,
  );
}
