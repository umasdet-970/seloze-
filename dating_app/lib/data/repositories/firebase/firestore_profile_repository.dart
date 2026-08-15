import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/geo_distance.dart';
import '../../models/profile.dart';
import '../profile_repository.dart';

/// Serves OTHER users' candidate cards into Discover. Exclusion of
/// already-swiped/blocked/reported ids happens in `discover_providers.dart`
/// (same as with the mock) — this repository's job is just "give me a
/// batch of complete profiles that aren't me."
///
/// `distanceKm` is real haversine distance (see core/utils/geo_distance.dart)
/// between the viewer's and each candidate's stored `{lat, lng}` — both
/// written by LocationService, best-effort at profile-save time. Falls
/// back to 0 (not a fabricated number) whenever either side hasn't
/// granted location: the viewer hasn't shared theirs, a candidate hasn't
/// shared theirs, or neither has. This computes distance for an
/// already-fetched batch rather than querying Firestore by radius
/// directly — Firestore has no native geoqueries, and a true "only fetch
/// candidates within N km" query would need geohashing (e.g. storing a
/// geohash field and querying geohash-prefix ranges); that's a further
/// scale optimization this pass doesn't add, since the ask was real
/// distance values, not radius-filtered fetching.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore, this.batchSize = 30})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final int batchSize;

  // A user is "online" if PresenceService's heartbeat has written within
  // this window — see that class for why it's a staleness check rather
  // than a live disconnect signal.
  static const _onlineWindow = Duration(minutes: 2);

  Future<(double, double)?> _fetchLatLng(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final lat = data?['lat'] as num?;
      final lng = data?['lng'] as num?;
      if (lat == null || lng == null) return null;
      return (lat.toDouble(), lng.toDouble());
    } catch (_) {
      // Missing doc, permission hiccup, offline — distance just falls
      // back to unknown (0) rather than failing the whole feed fetch
      // over a location lookup.
      return null;
    }
  }

  /// `Profile.fromMap` reads a raw `isOnline` field that's never actually
  /// written anywhere — presence is derived from `lastActiveAt` recency
  /// instead, computed here (where the raw Timestamp is available) rather
  /// than in the generic model. [viewerLatLng] is null for
  /// [fetchProfileById] (no viewer context there) — distance stays 0 in
  /// that case, same as before this pass.
  Profile _profileFromDoc(String id, Map<String, dynamic> data, (double, double)? viewerLatLng) {
    final lastActiveAt = (data['lastActiveAt'] as Timestamp?)?.toDate();
    final isOnline = lastActiveAt != null && DateTime.now().difference(lastActiveAt) < _onlineWindow;

    var distanceKm = 0.0;
    final lat = data['lat'] as num?;
    final lng = data['lng'] as num?;
    if (viewerLatLng != null && lat != null && lng != null) {
      distanceKm = haversineKm(viewerLatLng.$1, viewerLatLng.$2, lat.toDouble(), lng.toDouble());
    }

    return Profile.fromMap(id, data).copyWith(isOnline: isOnline, distanceKm: distanceKm);
  }

  @override
  Future<List<Profile>> fetchDiscoverFeed({required String currentUserId}) async {
    final viewerLatLng = await _fetchLatLng(currentUserId);

    final snapshot = await _firestore
        .collection('users')
        .where('profileComplete', isEqualTo: true)
        .limit(batchSize)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => _profileFromDoc(doc.id, doc.data(), viewerLatLng))
        .toList();
  }

  @override
  Future<Profile?> fetchProfileById(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return _profileFromDoc(doc.id, data, null);
  }
}
