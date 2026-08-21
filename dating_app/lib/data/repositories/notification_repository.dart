import 'dart:async';

import '../models/notification_item.dart';

/// In-app notification center (spec section 13). Real push delivery
/// needs Firebase Cloud Messaging + a live Firebase project; this stores
/// and surfaces the same events in-app so the UI/data model is already
/// correct when that swap happens.
abstract class NotificationRepository {
  Stream<void> changes();
  List<NotificationItem> notifications(String uid);
  int unreadCount(String uid);
  void add(String uid, NotificationType type, String title, String body);
  Future<void> markRead(String uid, String id);
  Future<void> markAllRead(String uid);
}

class MockNotificationRepository implements NotificationRepository {
  final _controller = StreamController<void>.broadcast();
  final Map<String, List<NotificationItem>> _byUser = {};
  final Set<String> _seeded = {};
  int _nextId = 1;

  void _notify() => _controller.add(null);

  /// Seeds a couple of realistic notifications on first access so the
  /// center isn't empty for a fresh test account.
  void _ensureSeeded(String uid) {
    if (_seeded.contains(uid)) return;
    _seeded.add(uid);
    final list = _byUser.putIfAbsent(uid, () => []);
    final now = DateTime.now();
    list.addAll([
      NotificationItem(
        id: '${_nextId++}',
        type: NotificationType.newLike,
        title: 'Someone liked your profile! ❤️',
        body: 'Open Likes to see who — and match instantly if you like them back.',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NotificationItem(
        id: '${_nextId++}',
        type: NotificationType.reportUpdate,
        title: 'Your report was reviewed',
        body: 'Thanks for helping keep Seloze safe — our team took action on your report.',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
      NotificationItem(
        id: '${_nextId++}',
        type: NotificationType.promotional,
        title: 'Complete your profile for 3x more matches',
        body: 'Profiles with 3+ photos and a full bio get significantly more likes.',
        createdAt: now.subtract(const Duration(days: 2)),
        read: true,
      ),
    ]);
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  List<NotificationItem> notifications(String uid) {
    _ensureSeeded(uid);
    final list = List<NotificationItem>.from(_byUser[uid] ?? const []);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  int unreadCount(String uid) {
    _ensureSeeded(uid);
    return (_byUser[uid] ?? const []).where((n) => !n.read).length;
  }

  @override
  void add(String uid, NotificationType type, String title, String body) {
    _ensureSeeded(uid);
    (_byUser[uid] ??= []).insert(
      0,
      NotificationItem(id: '${_nextId++}', type: type, title: title, body: body, createdAt: DateTime.now()),
    );
    _notify();
  }

  @override
  Future<void> markRead(String uid, String id) async {
    final list = _byUser[uid];
    if (list == null) return;
    final index = list.indexWhere((n) => n.id == id);
    if (index != -1 && !list[index].read) {
      list[index] = list[index].copyWith(read: true);
      _notify();
    }
  }

  @override
  Future<void> markAllRead(String uid) async {
    final list = _byUser[uid];
    if (list == null) return;
    var changed = false;
    for (var i = 0; i < list.length; i++) {
      if (!list[i].read) {
        list[i] = list[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) _notify();
  }
}
