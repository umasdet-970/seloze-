import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../discover/providers/discover_providers.dart';

/// Swap MockNotificationRepository() -> FirestoreNotificationRepository()
/// (paired with Firebase Cloud Messaging for real push) once Firebase is
/// wired in.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => MockNotificationRepository());

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
