import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/settings_models.dart';
import '../settings_repository.dart';
import '../../../core/utils/stream_safety.dart';

NotificationPreferences _notifPrefsFromMap(Map<String, dynamic>? map) {
  if (map == null) return const NotificationPreferences();
  return NotificationPreferences(
    newLikes: map['newLikes'] as bool? ?? true,
    matches: map['matches'] as bool? ?? true,
    messages: map['messages'] as bool? ?? true,
    promotional: map['promotional'] as bool? ?? true,
  );
}

Map<String, dynamic> _notifPrefsToMap(NotificationPreferences p) =>
    {'newLikes': p.newLikes, 'matches': p.matches, 'messages': p.messages, 'promotional': p.promotional};

PrivacySettings _privacyFromMap(Map<String, dynamic>? map) {
  if (map == null) return const PrivacySettings();
  return PrivacySettings(
    showOnlineStatus: map['showOnlineStatus'] as bool? ?? true,
    showDistance: map['showDistance'] as bool? ?? true,
  );
}

Map<String, dynamic> _privacyToMap(PrivacySettings p) => {'showOnlineStatus': p.showOnlineStatus, 'showDistance': p.showDistance};

/// Firestore schema: `users/{uid}/private/settings`
/// {notificationPrefs: {...}, privacySettings: {...}}.
class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();
  final Map<String, NotificationPreferences> _notifCache = {};
  final Map<String, PrivacySettings> _privacyCache = {};
  final Set<String> _listening = {};

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid).collection('private').doc('settings');

  void _ensureListening(String uid) {
    if (_listening.contains(uid)) return;
    _listening.add(uid);
    _doc(uid).snapshots().listenSafely((doc) {
      final data = doc.data();
      _notifCache[uid] = _notifPrefsFromMap(data?['notificationPrefs'] as Map<String, dynamic>?);
      _privacyCache[uid] = _privacyFromMap(data?['privacySettings'] as Map<String, dynamic>?);
      _controller.add(null);
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  NotificationPreferences notificationPreferences(String uid) {
    _ensureListening(uid);
    return _notifCache[uid] ?? const NotificationPreferences();
  }

  @override
  Future<void> saveNotificationPreferences(String uid, NotificationPreferences prefs) async {
    await _doc(uid).set({'notificationPrefs': _notifPrefsToMap(prefs)}, SetOptions(merge: true));
  }

  @override
  PrivacySettings privacySettings(String uid) {
    _ensureListening(uid);
    return _privacyCache[uid] ?? const PrivacySettings();
  }

  @override
  Future<void> savePrivacySettings(String uid, PrivacySettings settings) async {
    await _doc(uid).set({'privacySettings': _privacyToMap(settings)}, SetOptions(merge: true));
  }
}
