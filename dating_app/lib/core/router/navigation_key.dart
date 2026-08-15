import 'package:flutter/material.dart';

/// Lets code outside the widget tree (a local-notification tap callback,
/// specifically — see PushNotificationService) navigate imperatively.
/// Kept in its own file rather than inside app_router.dart so that
/// PushNotificationService doesn't have to import the whole router file
/// (and everything it transitively pulls in, every screen in the app)
/// just for this one key.
final rootNavigatorKey = GlobalKey<NavigatorState>();
