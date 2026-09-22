import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/rose_config.dart';
import '../../../data/models/profile.dart';
import '../../discover/providers/discover_providers.dart';
import '../../subscription/providers/subscription_providers.dart';

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

/// Ids among the current user's received likes that were sent as a Rose —
/// LikesScreen shows these unblurred regardless of tier (see
/// core/config/rose_config.dart).
final roseSenderIdsProvider = Provider<Set<String>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final social = ref.watch(socialRepositoryProvider);
  ref.watch(receivedLikesProvider); // rebuild alongside the likes list itself
  if (uid.isEmpty) return const {};
  return social.roseSenderIds(uid);
});

/// How many roses the current user has left to send today.
final rosesLeftTodayProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid.isEmpty) return 0;
  final social = ref.watch(socialRepositoryProvider);
  final tier = ref.watch(subscriptionTierProvider);
  ref.watch(receivedLikesProvider); // rebuild right after sendRose() calls social.changes()
  final used = social.roseUsedToday(uid);
  return (roseLimitFor(tier) - used).clamp(0, roseLimitFor(tier));
});
