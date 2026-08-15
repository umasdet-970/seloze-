import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';

/// Client-side half of push delivery: requests notification permission,
/// registers this device's FCM token against the signed-in user, and logs
/// incoming messages. The other half — actually SENDING a push when
/// something happens (new like, match, message) — needs a Cloud Function
/// watching `users/{uid}/notifications` and calling the FCM Admin SDK.
/// That function isn't written or deployed; this only gets the device
/// ready to receive it once it exists. See FIREBASE_SETUP.md.
class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  bool _initialized = false;

  Future<void> registerForUser(String uid) async {
    if (_initialized || uid.isEmpty) return;
    _initialized = true;

    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);

    _messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));

    // Foreground messages don't show a system heads-up notification on
    // their own — a real implementation would surface these via a local
    // notification package (flutter_local_notifications) or in-app
    // banner. Logged for now so the wiring is visibly correct.
    FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) debugPrint('[push] foreground message: ${message.notification?.title}');
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }
}

/// Must be a top-level function — background messages run in a separate
/// isolate that hasn't run `main()`, so Firebase needs re-initializing
/// here before anything else touches it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) debugPrint('[push] background message: ${message.notification?.title}');
}
