// firebase_options.dart — Dart-first Firebase configuration for SplitMadu.
// Generated from the splitmadu-app project's registered app configs
// (Android App ID 1:795299352767:android:..., iOS ..., Web ...).
//
// This file follows the FlutterFire "Dart-only" initialization flow, which is
// a fully supported alternative to native config files — though native files
// are also present in this repo for completeness.
//
// If this file is ever deleted, regenerate with:
//   dart pub global run flutterfire_cli:flutterfire configure
// or re-derive values with: firebase apps:sdkconfig <PLATFORM> <APP_ID>

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with `Firebase.initializeApp()`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS — '
          're-run flutterfire configure.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows — '
          're-run flutterfire configure.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux — '
          're-run flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are unsupported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBlDTcJBPyu2ibQz-AcGeDWVRkJoUTVOPI',
    appId: '1:795299352767:web:61c1e1601a6997e828b60a',
    messagingSenderId: '795299352767',
    projectId: 'splitmadu-app',
    authDomain: 'splitmadu-app.firebaseapp.com',
    storageBucket: 'splitmadu-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFwDpo-1tbzFahh-_YH8ld6rHhPq0gTkU',
    appId: '1:795299352767:android:ca74fbf3877c021e28b60a',
    messagingSenderId: '795299352767',
    projectId: 'splitmadu-app',
    storageBucket: 'splitmadu-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQroVLmqem-ZNpddrJVv1Ic2nvQHudKsg',
    appId: '1:795299352767:ios:06d5adef59b41ce528b60a',
    messagingSenderId: '795299352767',
    projectId: 'splitmadu-app',
    storageBucket: 'splitmadu-app.firebasestorage.app',
    iosBundleId: 'com.splitmadu.splitmadu',
  );
}
