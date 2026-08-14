import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/discover_filters.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/subscription_models.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../subscription/providers/subscription_providers.dart';

/// Swap MockProfileRepository() -> FirestoreProfileRepository() when ready.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository();
});

/// Swap MockSocialRepository() -> FirestoreSocialRepository() when ready.
final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return MockSocialRepository();
});

/// Derived from the signed-in user (see auth_providers.dart). Empty until
/// auth state resolves — repository calls with an empty id are treated as
/// "no session" by callers.
final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid ?? '';
});

enum DiscoverTab { forYou, nearby, newProfiles, online }

final discoverTabProvider = StateProvider<DiscoverTab>((ref) => DiscoverTab.forYou);

/// Search & Filters (spec section 15). Basic filters (age/distance/
/// gender/search) are free; the rest require Premium — see
/// [DiscoverFilters].
final discoverFiltersProvider = StateProvider<DiscoverFilters>((ref) => const DiscoverFilters());

/// Holds the current feed of candidate profiles to swipe through, already
/// filtered for already-swiped/blocked users, search & filters, and the
/// selected tab — capped by the daily discovery quota (spec section 4;
/// tier/limit live in subscription_providers.dart, driven by real
/// purchases).
class DiscoverFeedNotifier extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() async {
    // Re-run whenever the tab or filters change, so Search & Filters
    // actually affects the feed instead of just the chip UI state.
    ref.watch(discoverTabProvider);
    ref.watch(discoverFiltersProvider);
    return _loadBatch();
  }

  Future<List<Profile>> _loadBatch() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final social = ref.read(socialRepositoryProvider);
    final uid = ref.read(currentUserIdProvider);
    final limit = ref.read(dailyDiscoveryLimitProvider);
    final tab = ref.read(discoverTabProvider);
    final filters = ref.read(discoverFiltersProvider);
    final tier = ref.read(subscriptionTierProvider);

    final candidates = await profileRepo.fetchDiscoverFeed(currentUserId: uid);
    final excluded = {...social.swipedIds(uid), ...social.blockedIds(uid), ...social.reportedIds(uid)};
    var eligible = candidates.where((p) => !excluded.contains(p.id)).toList();
    eligible = _applyFilters(eligible, filters, tier);
    eligible = _applyTab(eligible, tab);

    // Profiles already counted today stay visible for free (re-filtering
    // must never burn extra quota); only genuinely new ones consume it.
    final shownToday = social.shownProfileIdsToday(uid);
    final alreadyShown = eligible.where((p) => shownToday.contains(p.id)).toList();
    final notYetShown = eligible.where((p) => !shownToday.contains(p.id)).toList();
    final remainingQuota = (limit - shownToday.length).clamp(0, limit);
    final newlyShown = notYetShown.take(remainingQuota).toList();
    for (final p in newlyShown) {
      social.recordDiscoveryShown(uid, p.id);
    }

    return [...alreadyShown, ...newlyShown];
  }

  List<Profile> _applyFilters(List<Profile> profiles, DiscoverFilters filters, SubscriptionTier tier) {
    var result = profiles.where((p) {
      if (p.age < filters.minAge || p.age > filters.maxAge) return false;
      if (p.distanceKm > filters.maxDistanceKm) return false;
      if (!filters.gender.matches(p.gender)) return false;
      if (filters.searchQuery.isNotEmpty) {
        final q = filters.searchQuery.toLowerCase();
        final matches = p.name.toLowerCase().contains(q) ||
            p.profession.toLowerCase().contains(q) ||
            p.education.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    // "Premium filters" (spec section 8 benefit) — silently ignored for
    // Free/Ad-Free rather than erroring, since the sheet already hides
    // them behind an upgrade prompt for non-Premium users.
    if (tier == SubscriptionTier.premium) {
      result = result.where((p) {
        if (filters.verifiedOnly && !p.isVerified) return false;
        if (filters.onlineOnly && !p.isOnline) return false;
        if (filters.profession.isNotEmpty &&
            !p.profession.toLowerCase().contains(filters.profession.toLowerCase())) {
          return false;
        }
        if (filters.education.isNotEmpty &&
            !p.education.toLowerCase().contains(filters.education.toLowerCase())) {
          return false;
        }
        if (filters.interests.isNotEmpty && !p.interests.any(filters.interests.contains)) return false;
        return true;
      }).toList();
    }
    return result;
  }

  List<Profile> _applyTab(List<Profile> profiles, DiscoverTab tab) {
    switch (tab) {
      case DiscoverTab.nearby:
        return [...profiles]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      case DiscoverTab.newProfiles:
        return profiles.reversed.toList();
      case DiscoverTab.online:
        return profiles.where((p) => p.isOnline).toList();
      case DiscoverTab.forYou:
        return profiles;
    }
  }

  void _removeTop() {
    final current = state.value ?? [];
    if (current.isEmpty) return;
    state = AsyncData(current.sublist(1));
  }

  Future<bool> likeTop() async {
    final current = state.value ?? [];
    if (current.isEmpty) return false;
    final target = current.first;
    final social = ref.read(socialRepositoryProvider);
    final uid = ref.read(currentUserIdProvider);
    final result = await social.like(uid, target.id);
    _removeTop();
    ref.read(analyticsRepositoryProvider).logEvent('like', params: {'source': 'discover'});
    if (result.matched) {
      ref.read(notificationRepositoryProvider).add(
            uid,
            NotificationType.mutualMatch,
            "It's a match! 🎉",
            'You and ${target.name} liked each other. Say hi!',
          );
      ref.read(analyticsRepositoryProvider).logEvent('match');
    }
    return result.matched;
  }

  Future<void> passTop() async {
    final current = state.value ?? [];
    if (current.isEmpty) return;
    final target = current.first;
    final social = ref.read(socialRepositoryProvider);
    final uid = ref.read(currentUserIdProvider);
    await social.pass(uid, target.id);
    _removeTop();
    ref.read(analyticsRepositoryProvider).logEvent('pass');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadBatch);
  }
}

final discoverFeedProvider =
    AsyncNotifierProvider<DiscoverFeedNotifier, List<Profile>>(
  DiscoverFeedNotifier.new,
);

final _socialTickProvider = StreamProvider<void>((ref) => ref.watch(socialRepositoryProvider).changes());

/// Profiles the current user has explicitly blocked — for the Blocked
/// Users settings screen (spec section 14).
final blockedProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  final social = ref.watch(socialRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  ref.watch(_socialTickProvider);
  if (uid.isEmpty) return [];
  final ids = social.blockedByMe(uid);
  final profiles = await Future.wait(ids.map(profileRepo.fetchProfileById));
  return profiles.whereType<Profile>().toList();
});
