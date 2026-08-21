// Generated from the real `connect-dating-app-e2ad4` Firebase project's
// android/app/google-services.json (Project Settings -> Your apps ->
// Android app), by hand rather than via `flutterfire configure` (no
// FlutterFire CLI / interactive Firebase login available in this
// environment) — same values that command would have written. Only an
// Android app is registered in this project, so only that platform is
// populated; add iOS/web apps in the Firebase console and their
// `FirebaseOptions` blocks here if this ever targets those platforms.
//
// See FIREBASE_SETUP.md for the full setup checklist.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions has no config for platform $defaultTargetPlatform — '
      'only the Android app is registered in the connect-dating-app-e2ad4 Firebase '
      'project. Register an app for this platform in the Firebase console and add '
      'its FirebaseOptions here.',
    );
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyD4eQK7GmYm_FDn_jeOEsUUTs--4moTxV8',
    appId: '1:196230871568:android:80696083db4593bd57a895',
    messagingSenderId: '196230871568',
    projectId: 'connect-dating-app-e2ad4',
    storageBucket: 'connect-dating-app-e2ad4.firebasestorage.app',
  );
}
