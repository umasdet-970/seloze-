import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/profile.dart';
import '../profile_repository.dart';

/// Serves OTHER users' candidate cards into Discover. Exclusion of
/// already-swiped/blocked/reported ids happens in `discover_providers.dart`
/// (same as with the mock) — this repository's job is just "give me a
/// batch of complete profiles that aren't me."
///
/// Note: `distanceKm` on the returned [Profile] is a placeholder (0) —
/// real distance needs the viewer's location plus a geo-indexed query
/// (Firestore has no native geoqueries; a real implementation needs
/// geohashing, e.g. via a Cloud Function that maintains a geohash field,
/// or a service like Algolia/Typesense). Wiring that up is a follow-up,
/// not part of the Firebase auth/data swap.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore, this.batchSize = 30})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final int batchSize;

  @override
  Future<List<Profile>> fetchDiscoverFeed({required String currentUserId}) async {
    final snapshot = await _firestore
        .collection('users')
        .where('profileComplete', isEqualTo: true)
        .limit(batchSize)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => Profile.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<Profile?> fetchProfileById(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return Profile.fromMap(doc.id, data);
  }
}
