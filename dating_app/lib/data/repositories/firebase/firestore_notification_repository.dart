import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/notification_item.dart';
import '../notification_repository.dart';

/// Firestore schema: `users/{uid}/notifications/{id}` {type, title, body,
/// createdAt, read}.
///
/// This only covers the in-app notification center. Actual push delivery
/// (a heads-up notification while the app is backgrounded/closed) needs
/// Firebase Cloud Messaging plus a Cloud Function that writes here AND
/// sends an FCM message — this repository is the "write the in-app
/// record" half only.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();
  final Map<String, List<NotificationItem>> _cache = {};
  final Set<String> _listening = {};

  void _notify() => _controller.add(null);

  CollectionReference<Map<String, dynamic>> _sub(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  void _ensureListening(String uid) {
    if (_listening.contains(uid)) return;
    _listening.add(uid);
    _sub(uid).orderBy('createdAt', descending: true).snapshots().listen((snap) {
      _cache[uid] = snap.docs.map((d) {
        final data = d.data();
        return NotificationItem(
          id: d.id,
          type: NotificationType.values.firstWhere((e) => e.name == data['type'], orElse: () => NotificationType.promotional),
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          read: data['read'] as bool? ?? false,
        );
      }).toList();
      _notify();
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  List<NotificationItem> notifications(String uid) {
    _ensureListening(uid);
    return List.unmodifiable(_cache[uid] ?? const []);
  }

  @override
  int unreadCount(String uid) {
    _ensureListening(uid);
    return (_cache[uid] ?? const []).where((n) => !n.read).length;
  }

  @override
  void add(String uid, NotificationType type, String title, String body) {
    _ensureListening(uid);
    unawaited(_addAsync(uid, type, title, body));
  }

  // Swallows write failures — this fires on every like/match/message, so
  // a transient failure without a handler is exactly the kind of thing
  // that would otherwise surface as a stream of unhandled zone errors
  // under any real-world flakiness. A try/catch around an explicit
  // `await`, rather than `.catchError` on the bare Future, because
  // `add()`'s return type (a DocumentReference) can't be produced from
  // an error handler that just wants to ignore the failure.
  Future<void> _addAsync(String uid, NotificationType type, String title, String body) async {
    try {
      await _sub(uid).add({
        'type': type.name,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}
  }

  @override
  Future<void> markRead(String uid, String id) async {
    await _sub(uid).doc(id).update({'read': true});
  }

  @override
  Future<void> markAllRead(String uid) async {
    final unread = (_cache[uid] ?? const []).where((n) => !n.read);
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    for (final n in unread) {
      batch.update(_sub(uid).doc(n.id), {'read': true});
    }
    await batch.commit();
  }
}
