import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../analytics_repository.dart';

/// Maps a subset of event names to a boolean milestone field on
/// `analyticsFunnel/{uid}` — spec section 17's registration/conversion
/// funnel. Firebase Analytics events (logged unconditionally below,
/// every event) go to Google Analytics/BigQuery, which the admin
/// dashboard has no direct access to; this parallel Firestore write is
/// what `FirestoreAdminRepository.registrationFunnel()` actually reads,
/// same reasoning as writing to `reports`/`notifications` collections
/// directly rather than relying on Analytics exports for anything the
/// dashboard needs live. A milestone doc (not a per-event log) so funnel
/// stage counts are `count()` queries on distinct users, not raw event
/// occurrences — someone who likes 50 people should count once toward
/// "first like sent", not 50 times.
const _funnelMilestoneFields = {
  'sign_up': 'signedUp',
  'age_verified': 'ageVerified',
  'profile_completed': 'profileCompleted',
  'like': 'likedSomeone',
  'match': 'matched',
  'subscription_purchase': 'subscribed',
};

class FirebaseAnalyticsRepository implements AnalyticsRepository {
  FirebaseAnalyticsRepository({FirebaseAnalytics? analytics, FirebaseFirestore? firestore})
      : _analytics = analytics ?? FirebaseAnalytics.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAnalytics _analytics;
  final FirebaseFirestore _firestore;
  String? _currentUid;

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    // FirebaseAnalytics requires non-null, non-empty param maps to omit
    // the `parameters` argument entirely rather than pass an empty map.
    _analytics.logEvent(name: name, parameters: params.isEmpty ? null : Map<String, Object>.from(params));

    final milestoneField = _funnelMilestoneFields[name];
    final uid = _currentUid;
    if (milestoneField != null && uid != null && uid.isNotEmpty) {
      // Fire-and-forget — a failed funnel-tracking write shouldn't block
      // or surface an error for whatever real user action triggered it.
      // `catchError` (not just omitting `await`) matters here: an
      // unawaited Future that later completes with an error is still an
      // unhandled zone error if nothing attaches a handler to it.
      _firestore.collection('analyticsFunnel').doc(uid).set({milestoneField: true}, SetOptions(merge: true)).catchError((_) {});
    }
  }

  @override
  void setUserId(String? uid) {
    _currentUid = uid;
    _analytics.setUserId(id: uid);
  }
}
