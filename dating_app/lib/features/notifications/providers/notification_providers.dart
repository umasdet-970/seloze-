import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/repositories/firebase/firestore_notification_repository.dart';
import '../../../data/repositories/firebase/push_notification_service.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../discover/providers/discover_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return kUseFirebase ? FirestoreNotificationRepository() : MockNotificationRepository();
});

final _pushNotificationService = PushNotificationService();

/// Registers this device's FCM token against the signed-in user as soon
/// as one exists. Watched once, app-wide, from main.dart — see
/// PushNotificationService for what this does and doesn't cover.
final pushRegistrarProvider = Provider<void>((ref) {
  if (!kUseFirebase) return;
  final uid = ref.watch(currentUserIdProvider);
  if (uid.isNotEmpty) {
    _pushNotificationService.registerForUser(uid);
  }
});

final _notificationTickProvider = StreamProvider<void>((ref) {
  return ref.watch(notificationRepositoryProvider).changes();
});

final notificationsProvider = Provider<List<NotificationItem>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  ref.watch(_notificationTickProvider);
  return uid.isEmpty ? const [] : repo.notifications(uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  ref.watch(_notificationTickProvider);
  return uid.isEmpty ? 0 : repo.unreadCount(uid);
});
