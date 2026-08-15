import 'dart:async';

import '../../core/utils/rate_limiter.dart';
import '../models/social_models.dart';

/// The "social graph" — likes, matches, blocks, reports, and daily
/// discovery usage. In Firestore terms this is roughly `likes/`,
/// `matches/`, `blocks/`, and `reports/` collections. Kept separate from
/// [ProfileRepository] (candidate cards) and [UserProfileRepository]
/// (your own profile doc) so each has a single responsibility.
abstract class SocialRepository {
  /// Fires on any like/pass/match/unmatch/block/unblock so screens can
  /// react without polling.
  Stream<void> changes();

  /// Ids already liked or passed by [uid] — Discover must never show
  /// these again (spec section 5: prevent duplicate likes).
  Set<String> swipedIds(String uid);

  /// Ids blocked by [uid] OR that have blocked [uid] — symmetric
  /// exclusion (spec section 10).
  Set<String> blockedIds(String uid);

  /// Ids [uid] has explicitly blocked (one-directional) — for the
  /// Blocked Users settings screen, where only blocks *you* placed can
  /// be undone.
  Set<String> blockedByMe(String uid);

  /// Ids [uid] has reported — automated moderation excludes these from
  /// their own Discover immediately, pending admin review (spec section
  /// 11/12), without requiring an explicit block.
  Set<String> reportedIds(String uid);

  /// Ids of people who liked [uid] but haven't matched yet — the
  /// "who liked you" grid (spec section 5 / Likes screen).
  List<String> receivedLikeIds(String uid);

  List<MatchRecord> matches(String uid);

  /// Distinct profile ids [uid] has been shown today (resets at local
  /// midnight). Tracked as a set rather than a raw counter so that
  /// switching filters/tabs and re-fetching never double-counts a
  /// profile the user has already seen today — a real backend needs a
  /// server-side day boundary via Firestore + Cloud Functions.
  Set<String> shownProfileIdsToday(String uid);

  /// How many distinct profiles [uid] has seen today.
  int discoveriesUsedToday(String uid);

  /// Whether [uid] can be shown another NEW profile under [dailyLimit].
  bool canDiscoverMore(String uid, int dailyLimit);

  /// Marks [profileId] as counted toward today's quota. Idempotent —
  /// safe to call again for a profile already shown today.
  void recordDiscoveryShown(String uid, String profileId);

  Future<LikeResult> like(String uid, String targetId);
  Future<void> pass(String uid, String targetId);

  Future<void> unmatch(String uid, String otherId);

  Future<void> block(String uid, String targetId);
  Future<void> unblock(String uid, String targetId);

  Future<void> report(String uid, String targetId, {required ReportReason reason, String details = ''});
}

class MockSocialRepository implements SocialRepository {
  final _controller = StreamController<void>.broadcast();

  final Map<String, Set<String>> _likesGiven = {};
  final Map<String, Set<String>> _passesGiven = {};
  final Map<String, Set<String>> _likesReceived = {};
  final Map<String, List<MatchRecord>> _matches = {};
  final Map<String, Set<String>> _blockedByMe = {};
  final Map<String, Set<String>> _reportedByMe = {};
  final Map<String, DateTime> _lastDiscoveryDate = {};
  final Map<String, Set<String>> _shownToday = {};
  final Set<String> _seeded = {};
  final _reportLimiter = RateLimiter(maxEvents: 5, window: const Duration(minutes: 10));
  // Bot detection (spec section 12/19): sustained swiping faster than a
  // human plausibly can — real dating apps see this from scraping/farming
  // bots. Throttles rather than silently allows; a real backend would
  // also flag the account for the admin review queue, not just rate-limit.
  final _swipeLimiter = RateLimiter(maxEvents: 40, window: const Duration(minutes: 2));

  void _notify() => _controller.add(null);

  @override
  Stream<void> changes() => _controller.stream;

  /// Every fresh test account starts with a couple of pending admirers
  /// so the Likes screen and mutual-match flow are demonstrable without
  /// needing multiple real signed-in accounts.
  void _ensureSeeded(String uid) {
    if (_seeded.contains(uid)) return;
    _seeded.add(uid);
    (_likesReceived[uid] ??= {}).addAll({'u2', 'u5'});
  }

  @override
  Set<String> swipedIds(String uid) => {...?_likesGiven[uid], ...?_passesGiven[uid]};

  @override
  Set<String> blockedIds(String uid) {
    final ids = <String>{...?_blockedByMe[uid]};
    for (final entry in _blockedByMe.entries) {
      if (entry.value.contains(uid)) ids.add(entry.key);
    }
    return ids;
  }

  @override
  Set<String> blockedByMe(String uid) => Set.unmodifiable(_blockedByMe[uid] ?? const {});

  @override
  Set<String> reportedIds(String uid) => Set.unmodifiable(_reportedByMe[uid] ?? const {});

  @override
  List<String> receivedLikeIds(String uid) {
    _ensureSeeded(uid);
    final matchedIds = _matches[uid]?.map((m) => m.otherUserId).toSet() ?? {};
    return (_likesReceived[uid] ?? {}).where((id) => !matchedIds.contains(id)).toList();
  }

  @override
  List<MatchRecord> matches(String uid) => List.unmodifiable(_matches[uid] ?? const []);

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _resetIfNewDay(String uid) {
    final last = _lastDiscoveryDate[uid];
    if (last == null || !_isToday(last)) {
      _shownToday[uid] = {};
      _lastDiscoveryDate[uid] = DateTime.now();
    }
  }

  @override
  Set<String> shownProfileIdsToday(String uid) {
    _resetIfNewDay(uid);
    return Set.unmodifiable(_shownToday[uid] ?? const {});
  }

  @override
  int discoveriesUsedToday(String uid) {
    _resetIfNewDay(uid);
    return _shownToday[uid]?.length ?? 0;
  }

  @override
  bool canDiscoverMore(String uid, int dailyLimit) {
    return discoveriesUsedToday(uid) < dailyLimit;
  }

  @override
  void recordDiscoveryShown(String uid, String profileId) {
    _resetIfNewDay(uid);
    (_shownToday[uid] ??= {}).add(profileId);
  }

  @override
  Future<LikeResult> like(String uid, String targetId) async {
    if (!_swipeLimiter.allow(uid)) {
      throw RateLimitException("You're swiping too fast — please slow down.");
    }
    await Future.delayed(const Duration(milliseconds: 150));
    _ensureSeeded(uid);
    (_likesGiven[uid] ??= {}).add(targetId);

    final theyLikedMe = (_likesReceived[uid] ?? const {}).contains(targetId);
    if (theyLikedMe) {
      final now = DateTime.now();
      (_matches[uid] ??= []).add(MatchRecord(otherUserId: targetId, matchedAt: now));
      (_matches[targetId] ??= []).add(MatchRecord(otherUserId: uid, matchedAt: now));
      _likesReceived[uid]?.remove(targetId);
      _notify();
      return const LikeResult(matched: true);
    }

    (_likesReceived[targetId] ??= {}).add(uid);
    _notify();
    return const LikeResult(matched: false);
  }

  @override
  Future<void> pass(String uid, String targetId) async {
    if (!_swipeLimiter.allow(uid)) {
      throw RateLimitException("You're swiping too fast — please slow down.");
    }
    await Future.delayed(const Duration(milliseconds: 100));
    (_passesGiven[uid] ??= {}).add(targetId);
    _notify();
  }

  @override
  Future<void> unmatch(String uid, String otherId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _matches[uid]?.removeWhere((m) => m.otherUserId == otherId);
    _matches[otherId]?.removeWhere((m) => m.otherUserId == uid);
    _notify();
  }

  @override
  Future<void> block(String uid, String targetId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    (_blockedByMe[uid] ??= {}).add(targetId);
    // Blocking removes any existing match and hides it from both sides.
    await unmatch(uid, targetId);
    _notify();
  }

  @override
  Future<void> unblock(String uid, String targetId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _blockedByMe[uid]?.remove(targetId);
    _notify();
  }

  @override
  Future<void> report(String uid, String targetId, {required ReportReason reason, String details = ''}) async {
    if (!_reportLimiter.allow(uid)) {
      throw RateLimitException("You've submitted a lot of reports recently. Please try again later.");
    }
    await Future.delayed(const Duration(milliseconds: 300));
    // Real backend: write to `reports/` + trigger the admin review queue
    // (roadmap phase: admin dashboard). Automated moderation reacts
    // immediately by excluding the reported user from this reporter's
    // own Discover — see reportedIds().
    (_reportedByMe[uid] ??= {}).add(targetId);
    _notify();
  }
}
