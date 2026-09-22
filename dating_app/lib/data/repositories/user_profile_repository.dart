import 'dart:async';

import '../models/dating_preferences.dart';
import '../models/profile.dart';

/// Owns the signed-in user's OWN profile + preferences — distinct from
/// [ProfileRepository], which serves OTHER users' cards into Discover.
/// When Firestore is wired in, both will read/write the same
/// `users/{uid}` document; the split stays for testability and because
/// preferences are private and never rendered on a card.
abstract class UserProfileRepository {
  bool hasCompletedProfile(String uid);

  /// Fires whenever a profile or verification status changes, so the
  /// router can react (mirrors AuthRepository.authStateChanges()).
  Stream<void> profileChanges();

  Future<Profile?> fetchMyProfile(String uid);
  Future<void> saveProfile(String uid, Profile profile);

  Future<DatingPreferences> fetchPreferences(String uid);
  Future<void> savePreferences(String uid, DatingPreferences preferences);

  /// Simulates submitting photos for verification (spec section 3).
  /// Real implementation calls the AI moderation API + admin review
  /// queue (roadmap phase 8); this mock just approves after a delay.
  Future<void> requestVerification(String uid);

  /// Premium's "Boost" — marks [uid] boosted for [duration] (see
  /// Profile.boostedUntil/isBoosted), sorted first in other users'
  /// Discover feeds for that window (discover_providers.dart). No-ops
  /// (throws) if a boost is already active — checked by the caller via
  /// [activeBoostUntil] before calling this, not re-checked here, since
  /// the UI already disables the button while one's active.
  Future<void> activateBoost(String uid, {required Duration duration});

  /// Null/past means not currently boosted.
  DateTime? activeBoostUntil(String uid);

  /// Premium's "Incognito" (see Profile.incognito) — on/off, no expiry.
  Future<void> setIncognito(String uid, bool value);
}

class MockUserProfileRepository implements UserProfileRepository {
  final Map<String, Profile> _profiles = {};
  final Map<String, DatingPreferences> _preferences = {};
  final _changesController = StreamController<void>.broadcast();

  @override
  bool hasCompletedProfile(String uid) {
    final profile = _profiles[uid];
    return profile != null && profile.name.isNotEmpty && profile.photoUrls.isNotEmpty;
  }

  @override
  Stream<void> profileChanges() => _changesController.stream;

  @override
  Future<Profile?> fetchMyProfile(String uid) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _profiles[uid];
  }

  @override
  Future<void> saveProfile(String uid, Profile profile) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _profiles[uid] = profile;
    _changesController.add(null);
  }

  @override
  Future<DatingPreferences> fetchPreferences(String uid) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _preferences[uid] ?? const DatingPreferences();
  }

  @override
  Future<void> savePreferences(String uid, DatingPreferences preferences) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _preferences[uid] = preferences;
  }

  @override
  Future<void> requestVerification(String uid) async {
    await Future.delayed(const Duration(seconds: 2));
    final profile = _profiles[uid];
    if (profile == null) return;
    _profiles[uid] = profile.copyWith(isVerified: true);
    _changesController.add(null);
  }

  @override
  DateTime? activeBoostUntil(String uid) {
    final until = _profiles[uid]?.boostedUntil;
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  @override
  Future<void> activateBoost(String uid, {required Duration duration}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final profile = _profiles[uid];
    if (profile == null) return;
    _profiles[uid] = profile.copyWith(boostedUntil: DateTime.now().add(duration));
    _changesController.add(null);
  }

  @override
  Future<void> setIncognito(String uid, bool value) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final profile = _profiles[uid];
    if (profile == null) return;
    _profiles[uid] = profile.copyWith(incognito: value);
    _changesController.add(null);
  }
}
