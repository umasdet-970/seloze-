import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/profile.dart';
import '../../discover/providers/discover_providers.dart';

class MatchedProfile {
  final Profile profile;
  final DateTime matchedAt;
  const MatchedProfile({required this.profile, required this.matchedAt});
}

/// Mutual matches (spec section 6), newest first, re-fetched whenever the
/// social graph changes (new match, unmatch, or block).
final matchesProvider = StreamProvider<List<MatchedProfile>>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final social = ref.watch(socialRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  Future<List<MatchedProfile>> resolve() async {
    if (uid.isEmpty) return [];
    final records = social.matches(uid);
    final resolved = await Future.wait(records.map((r) async {
      final profile = await profileRepo.fetchProfileById(r.otherUserId);
      if (profile == null) return null;
      return MatchedProfile(profile: profile, matchedAt: r.matchedAt);
    }));
    final list = resolved.whereType<MatchedProfile>().toList();
    list.sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
    return list;
  }

  yield await resolve();
  await for (final _ in social.changes()) {
    yield await resolve();
  }
});
