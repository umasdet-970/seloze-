import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/navigation_key.dart';
import '../../models/notification_item.dart';
import '../../../firebase_options.dart';

const _androidChannel = AndroidNotificationChannel(
  'connect_messages',
  'Seloze notifications',
  description: 'New likes, matches, messages, and other account activity.',
  importance: Importance.high,
);

/// Push delivery, client-side half: requests notification permission,
/// registers this device's FCM token against the signed-in user, and —
/// spec section 7/13's "foreground push notifications" — actually shows
/// a heads-up local notification for messages that arrive while the app
/// is open, which FirebaseMessaging.onMessage doesn't do on its own.
/// The other half (actually SENDING a push) is `sendPushOnNotificationCreate`
/// (see functions/src/index.ts).
class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  bool _initialized = false;

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;
  static int _nextNotificationId = 0;

  static Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) return;
    _localNotificationsInitialized = true;
    try {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    } catch (_) {
      // Best-effort — a failure to initialize local notifications
      // shouldn't block FCM token registration, which is the more
      // important half of push delivery.
      _localNotificationsInitialized = false;
    }
  }

  static void _handleNotificationTap(NotificationResponse response) {
    final route = response.payload;
    if (route == null || route.isEmpty) return;
    final context = rootNavigatorKey.currentState?.context;
    if (context == null || !context.mounted) return;
    GoRouter.of(context).push(route);
  }

  // Called from pushRegistrarProvider's Provider body, which can't be
  // async and so never awaits or handles errors from this — every
  // failure path below has to be swallowed internally, or a denied
  // permission / offline device turns into an unhandled zone error on
  // every rebuild.
  Future<void> registerForUser(String uid) async {
    if (_initialized || uid.isEmpty) return;
    _initialized = true;

    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _ensureLocalNotificationsInitialized();

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);

      _messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken).catchError((_) {}));

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (_) {
      // Allow a later call (e.g. after the user grants permission in
      // system settings, or connectivity returns) to retry, rather than
      // permanently treating this uid as "already registered" after a
      // failed first attempt.
      _initialized = false;
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsInitialized) {
      if (kDebugMode) debugPrint('[push] foreground message (no local-notifications): ${message.notification?.title}');
      return;
    }

    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return; // data-only message — nothing to show

    // Resolves the same in-app route NotificationsScreen uses for this
    // NotificationType (e.g. newLike -> /likes) — stored as the
    // notification's payload so the tap handler can read it
    // synchronously with no async work in that callback.
    String? route;
    final typeName = message.data['type'];
    if (typeName != null) {
      for (final type in NotificationType.values) {
        if (type.name == typeName) {
          route = type.route;
          break;
        }
      }
    }

    try {
      await _localNotifications.show(
        // Wraps to stay a valid 32-bit notification id — collisions just
        // mean an older foreground notification gets replaced, which is
        // an acceptable trade for not needing a real random source here.
        _nextNotificationId++ % 0x7FFFFFFF,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: route,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[push] failed to show foreground notification: $e');
    }
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
