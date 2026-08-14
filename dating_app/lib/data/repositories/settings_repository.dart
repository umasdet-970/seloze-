import 'dart:async';

import '../models/settings_models.dart';

/// App-level settings (spec section 14) — distinct from [DatingPreferences]
/// (discovery matching criteria) and [Profile] (public-facing content).
abstract class SettingsRepository {
  Stream<void> changes();
  NotificationPreferences notificationPreferences(String uid);
  Future<void> saveNotificationPreferences(String uid, NotificationPreferences prefs);
  PrivacySettings privacySettings(String uid);
  Future<void> savePrivacySettings(String uid, PrivacySettings settings);
}

class MockSettingsRepository implements SettingsRepository {
  final _controller = StreamController<void>.broadcast();
  final Map<String, NotificationPreferences> _notificationPrefs = {};
  final Map<String, PrivacySettings> _privacySettings = {};

  @override
  Stream<void> changes() => _controller.stream;

  @override
  NotificationPreferences notificationPreferences(String uid) =>
      _notificationPrefs[uid] ?? const NotificationPreferences();

  @override
  Future<void> saveNotificationPreferences(String uid, NotificationPreferences prefs) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _notificationPrefs[uid] = prefs;
    _controller.add(null);
  }

  @override
  PrivacySettings privacySettings(String uid) => _privacySettings[uid] ?? const PrivacySettings();

  @override
  Future<void> savePrivacySettings(String uid, PrivacySettings settings) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _privacySettings[uid] = settings;
    _controller.add(null);
  }
}
