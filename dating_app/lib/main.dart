import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/config/ad_config.dart';
import 'core/config/backend_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/firebase/push_notification_service.dart';
import 'data/repositories/firebase/revenuecat_billing_repository.dart';
import 'features/chat/providers/chat_providers.dart';
import 'features/notifications/providers/notification_providers.dart';
import 'features/profile/providers/presence_providers.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kUseFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  if (kUseRevenueCat) {
    await configureRevenueCat();
  }
  if (kUseAds) {
    await MobileAds.instance.initialize();
  }
  runApp(const ProviderScope(child: ConnectApp()));
}

class ConnectApp extends ConsumerWidget {
  const ConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(newMessageWatcherProvider); // keeps the global "New Message" listener alive app-wide
    ref.watch(pushRegistrarProvider); // registers this device's FCM token once signed in (no-op unless kUseFirebase)
    ref.watch(presenceRegistrarProvider); // starts the online/offline heartbeat once signed in (no-op unless kUseFirebase)
    return MaterialApp.router(
      title: 'Connect', // rename to your app name
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
