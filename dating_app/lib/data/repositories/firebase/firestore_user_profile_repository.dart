import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/profile_risk_scorer.dart';
import '../../models/dating_preferences.dart';
import '../../models/profile.dart';
import '../user_profile_repository.dart';
import '../../../core/utils/stream_safety.dart';

DatingPreferences _preferencesFromMap(Map<String, dynamic>? map) {
  if (map == null) return const DatingPreferences();
  return DatingPreferences(
    intention: DatingIntention.values.firstWhere(
      (e) => e.name == map['intention'],
      orElse: () => DatingIntention.notSure,
    ),
    relationshipPreference: RelationshipPreference.values.firstWhere(
      (e) => e.name == map['relationshipPreference'],
      orElse: () => RelationshipPreference.notSure,
    ),
    showMe: ShowMePreference.values.firstWhere(
      (e) => e.name == map['showMe'],
      orElse: () => ShowMePreference.everyone,
    ),
    minAge: map['minAge'] as int? ?? 18,
    maxAge: map['maxAge'] as int? ?? 45,
    maxDistanceKm: (map['maxDistanceKm'] as num?)?.toDouble() ?? 50,
    profileVisible: map['profileVisible'] as bool? ?? true,
  );
}

Map<String, dynamic> _preferencesToMap(DatingPreferences p) => {
      'intention': p.intention.name,
      'relationshipPreference': p.relationshipPreference.name,
      'showMe': p.showMe.name,
      'minAge': p.minAge,
      'maxAge': p.maxAge,
      'maxDistanceKm': p.maxDistanceKm,
      'profileVisible': p.profileVisible,
    };

/// Backs [UserProfileRepository] with `users/{uid}` (profile fields, same
/// document Auth uses for ageVerified/dateOfBirth) and
/// `users/{uid}/private/preferences` (dating preferences — kept in a
/// `private` subcollection so Firestore security rules can allow public
/// read of the parent doc's profile fields while keeping preferences
/// readable only by the owner).
class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _changesController = StreamController<void>.broadcast();
  final Map<String, Profile> _profileCache = {};
  final Map<String, StreamSubscription> _profileSubs = {};

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _firestore.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _preferencesDoc(String uid) => _userDoc(uid).collection('private').doc('preferences');

  void _ensureListening(String uid) {
    if (_profileSubs.containsKey(uid)) return;
    _profileSubs[uid] = _userDoc(uid).snapshots().listenSafely((doc) {
      final data = doc.data();
      if (data == null || (data['name'] as String? ?? '').isEmpty) {
        _profileCache.remove(uid);
      } else {
        _profileCache[uid] = Profile.fromMap(uid, data);
      }
      _changesController.add(null);
    });
  }

  @override
  bool hasCompletedProfile(String uid) {
    _ensureListening(uid);
    final profile = _profileCache[uid];
    return profile != null && profile.name.isNotEmpty && profile.photoUrls.isNotEmpty;
  }

  @override
  Stream<void> profileChanges() => _changesController.stream;

  @override
  Future<Profile?> fetchMyProfile(String uid) async {
    _ensureListening(uid);
    if (_profileCache.containsKey(uid)) return _profileCache[uid];
    final doc = await _userDoc(uid).get();
    final data = doc.data();
    if (data == null || (data['name'] as String? ?? '').isEmpty) return null;
    return Profile.fromMap(uid, data);
  }

  @override
  Future<void> saveProfile(String uid, Profile profile) async {
    // `profileComplete` lets FirestoreProfileRepository's discover-feed
    // query filter server-side (`where('profileComplete', isEqualTo: true)`)
    // instead of fetching every user doc and filtering client-side.
    //
    // Suspicious-profile detection (spec section 3/12/19) runs here, once
    // per save, rather than on every admin dashboard load — see
    // ProfileRiskScorer's doc comment. Persisted, not just computed and
    // discarded, so the admin flagged-profiles queue is a plain Firestore
    // read instead of rescoring every user on every page load.
    final risk = ProfileRiskScorer.assess(profile);
    final map = profile.toMap()
      ..['profileComplete'] = profile.name.isNotEmpty && profile.photoUrls.isNotEmpty
      ..['riskScore'] = risk.score
      ..['riskSignals'] = risk.signals;
    await _userDoc(uid).set(map, SetOptions(merge: true));
  }

  @override
  Future<DatingPreferences> fetchPreferences(String uid) async {
    final doc = await _preferencesDoc(uid).get();
    return _preferencesFromMap(doc.data());
  }

  @override
  Future<void> savePreferences(String uid, DatingPreferences preferences) async {
    await _preferencesDoc(uid).set(_preferencesToMap(preferences));
  }

  @override
  Future<void> requestVerification(String uid) async {
    // Real moderation happens server-side (Cloud Function reviewing the
    // submitted photos, or an admin queue) and flips this flag once
    // approved. Setting a `verificationRequested` marker here gives that
    // backend something to watch for; it should NOT set isVerified itself
    // client-side in production — this mirrors the mock's instant-approve
    // behavior only because there's no moderation backend yet to trigger.
    await _userDoc(uid).set({'verificationRequested': true}, SetOptions(merge: true));
  }
}
