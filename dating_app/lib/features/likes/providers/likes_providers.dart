import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/profile.dart';
import '../../discover/providers/discover_providers.dart';

/// Profiles of people who liked the current user but haven't matched yet
/// (spec section 5 — the "who liked you" grid), re-fetched whenever the
/// social graph changes (a new like arrives, or one turns into a match).
final receivedLikesProvider = StreamProvider<List<Profile>>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final social = ref.watch(socialRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  Future<List<Profile>> resolve() async {
    if (uid.isEmpty) return [];
    final ids = social.receivedLikeIds(uid);
    final profiles = await Future.wait(ids.map(profileRepo.fetchProfileById));
    return profiles.whereType<Profile>().toList();
  }

  yield await resolve();
  await for (final _ in social.changes()) {
    yield await resolve();
  }
});
