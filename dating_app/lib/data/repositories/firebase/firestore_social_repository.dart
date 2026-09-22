import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/ad_config.dart';
import '../../../core/utils/rate_limiter.dart';
import '../../models/social_models.dart';
import '../social_repository.dart';
import '../../../core/utils/stream_safety.dart';

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Firestore schema (see FIREBASE_SETUP.md for indexes/rules):
///   users/{uid}/swipes/{targetId}         {type: 'like'|'pass', createdAt}
///   users/{uid}/likesReceived/{fromId}    {createdAt, fromUserId}  -- pending, not yet matched
///   users/{uid}/matches/{otherId}         {matchedAt, otherUserId}
///   users/{uid}/blocked/{targetId}        {targetId, createdAt}
///   users/{uid}/reported/{targetId}       {reason, details, createdAt}
///   users/{uid}/private/quota             {date, shownIds, adBonusCount}
///   reports/{autoId}                      {reporterId, targetId, reason, details, createdAt} -- admin dashboard
///
/// `otherUserId`/`fromUserId` duplicate each doc's own ID as a queryable
/// field — collection-group queries can't filter on document ID, and
/// `cleanupUserOnDelete` (see functions/) needs to find every match/
/// pending-like doc across ALL users that references a just-deleted uid.
///
/// Every synchronous getter in [SocialRepository] is backed by a local
/// cache kept current by a Firestore listener started the first time that
/// uid is touched (mirrors how MockSocialRepository's in-memory maps work,
/// just fed by snapshots instead of direct mutation).
class FirestoreSocialRepository implements SocialRepository {
  FirestoreSocialRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();
  final _reportLimiter = RateLimiter(maxEvents: 5, window: const Duration(minutes: 10));
  // Bot detection (spec section 12/19) — see MockSocialRepository's copy
  // of this same limiter for the reasoning. A real hardening pass would
  // enforce this server-side too (Cloud Function or Firestore rules can't
  // easily rate-limit by themselves), same caveat as every other
  // client-side rate limiter in this app.
  final _swipeLimiter = RateLimiter(maxEvents: 40, window: const Duration(minutes: 2));

  final Map<String, Set<String>> _swipedCache = {};
  final Map<String, Set<String>> _blockedByMeCache = {};
  final Map<String, Set<String>> _blockedMeCache = {};
  final Map<String, Set<String>> _reportedCache = {};
  final Map<String, List<String>> _likesReceivedCache = {};
  final Map<String, Set<String>> _roseSenderCache = {};
  final Map<String, List<MatchRecord>> _matchesCache = {};
  final Map<String, ({String date, Set<String> shownIds, int adBonusCount, int roseCount})> _quotaCache = {};
  final Set<String> _listening = {};

  void _notify() => _controller.add(null);

  CollectionReference<Map<String, dynamic>> _userSub(String uid, String name) =>
      _firestore.collection('users').doc(uid).collection(name);

  void _ensureListening(String uid) {
    if (_listening.contains(uid)) return;
    _listening.add(uid);

    _userSub(uid, 'swipes').snapshots().listenSafely((snap) {
      _swipedCache[uid] = snap.docs.map((d) => d.id).toSet();
      _notify();
    });

    _userSub(uid, 'blocked').snapshots().listenSafely((snap) {
      _blockedByMeCache[uid] = snap.docs.map((d) => d.id).toSet();
      _notify();
    });

    _firestore.collectionGroup('blocked').where('targetId', isEqualTo: uid).snapshots().listenSafely((snap) {
      _blockedMeCache[uid] = snap.docs.map((d) => d.reference.parent.parent!.id).toSet();
      _notify();
    });

    _userSub(uid, 'reported').snapshots().listenSafely((snap) {
      _reportedCache[uid] = snap.docs.map((d) => d.id).toSet();
      _notify();
    });

    _userSub(uid, 'likesReceived').snapshots().listenSafely((snap) {
      _likesReceivedCache[uid] = snap.docs.map((d) => d.id).toList();
      _roseSenderCache[uid] = snap.docs.where((d) => d.data()['isRose'] == true).map((d) => d.id).toSet();
      _notify();
    });

    _userSub(uid, 'matches').snapshots().listenSafely((snap) {
      _matchesCache[uid] = snap.docs
          .map((d) => MatchRecord(otherUserId: d.id, matchedAt: (d.data()['matchedAt'] as Timestamp?)?.toDate() ?? DateTime.now()))
          .toList();
      _notify();
    });

    _firestore.collection('users').doc(uid).collection('private').doc('quota').snapshots().listenSafely((doc) {
      final data = doc.data();
      final date = data?['date'] as String? ?? '';
      final ids = Set<String>.from(data?['shownIds'] as List? ?? const []);
      final adBonusCount = (data?['adBonusCount'] as num?)?.toInt() ?? 0;
      final roseCount = (data?['roseCount'] as num?)?.toInt() ?? 0;
      _quotaCache[uid] = (date: date, shownIds: ids, adBonusCount: adBonusCount, roseCount: roseCount);
      _notify();
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  Set<String> swipedIds(String uid) {
    _ensureListening(uid);
    return Set.unmodifiable(_swipedCache[uid] ?? const {});
  }

  @override
  Set<String> blockedIds(String uid) {
    _ensureListening(uid);
    return {...?_blockedByMeCache[uid], ...?_blockedMeCache[uid]};
  }

  @override
  Set<String> blockedByMe(String uid) {
    _ensureListening(uid);
    return Set.unmodifiable(_blockedByMeCache[uid] ?? const {});
  }

  @override
  Set<String> reportedIds(String uid) {
    _ensureListening(uid);
    return Set.unmodifiable(_reportedCache[uid] ?? const {});
  }

  @override
  List<String> receivedLikeIds(String uid) {
    _ensureListening(uid);
    return List.unmodifiable(_likesReceivedCache[uid] ?? const []);
  }

  @override
  Set<String> roseSenderIds(String uid) {
    _ensureListening(uid);
    return Set.unmodifiable(_roseSenderCache[uid] ?? const {});
  }

  @override
  List<MatchRecord> matches(String uid) {
    _ensureListening(uid);
    return List.unmodifiable(_matchesCache[uid] ?? const []);
  }

  Set<String> _shownTodayRaw(String uid) {
    _ensureListening(uid);
    final quota = _quotaCache[uid];
    if (quota == null || quota.date != _todayKey()) return const {};
    return quota.shownIds;
  }

  int _adBonusTodayRaw(String uid) {
    _ensureListening(uid);
    final quota = _quotaCache[uid];
    if (quota == null || quota.date != _todayKey()) return 0;
    return quota.adBonusCount;
  }

  @override
  Set<String> shownProfileIdsToday(String uid) => Set.unmodifiable(_shownTodayRaw(uid));

  @override
  int discoveriesUsedToday(String uid) => _shownTodayRaw(uid).length;

  @override
  bool canDiscoverMore(String uid, int dailyLimit) => discoveriesUsedToday(uid) < dailyLimit;

  @override
  void recordDiscoveryShown(String uid, String profileId) {
    _ensureListening(uid);
    final today = _todayKey();
    final current = _shownTodayRaw(uid);
    if (current.contains(profileId)) return;
    final updated = {...current, profileId};
    final adBonusCount = _adBonusTodayRaw(uid);
    final roseCount = _roseTodayRaw(uid);
    // Update the cache immediately (synchronous callers read it right
    // after calling this), then persist in the background — matches the
    // interface's fire-and-forget (non-Future) contract. `catchError`
    // matters here too: this fires on every profile shown in Discover
    // (i.e. every swipe), so it's the highest-frequency write in the
    // app — a transient failure without a handler would be the most
    // likely source of unhandled zone errors under real-world flakiness.
    // Carries the ad-bonus/rose counts along (rather than a partial
    // `update`) so every writer of this doc agrees on what "today's
    // quota doc" is.
    _quotaCache[uid] = (date: today, shownIds: updated, adBonusCount: adBonusCount, roseCount: roseCount);
    unawaited(
      _firestore.collection('users').doc(uid).collection('private').doc('quota').set({
        'date': today,
        'shownIds': updated.toList(),
        'adBonusCount': adBonusCount,
        'roseCount': roseCount,
      }).catchError((_) {}),
    );
  }

  @override
  int adBonusUsedToday(String uid) => _adBonusTodayRaw(uid);

  @override
  void recordAdBonusEarned(String uid) {
    _ensureListening(uid);
    final today = _todayKey();
    final current = _adBonusTodayRaw(uid);
    if (current >= kMaxAdBonusPerDay) return;
    final shownIds = _shownTodayRaw(uid);
    final roseCount = _roseTodayRaw(uid);
    final updated = current + 1;
    _quotaCache[uid] = (date: today, shownIds: shownIds, adBonusCount: updated, roseCount: roseCount);
    unawaited(
      _firestore.collection('users').doc(uid).collection('private').doc('quota').set({
        'date': today,
        'shownIds': shownIds.toList(),
        'adBonusCount': updated,
        'roseCount': roseCount,
      }).catchError((_) {}),
    );
    _notify();
  }

  @override
  Future<LikeResult> like(String uid, String targetId) => _likeInternal(uid, targetId, isRose: false);

  @override
  Future<LikeResult> sendRose(String uid, String targetId) async {
    final result = await _likeInternal(uid, targetId, isRose: true);
    // Only counts against the daily rose quota if it actually created a
    // new pending like — an instant match doesn't need the "stand out in
    // their Likes grid" effect a rose exists for (see MockSocialRepository
    // for the same reasoning).
    if (!result.matched) {
      final today = _todayKey();
      final current = _roseTodayRaw(uid);
      final updated = current + 1;
      final shownIds = _shownTodayRaw(uid);
      final adBonusCount = _adBonusTodayRaw(uid);
      _quotaCache[uid] = (date: today, shownIds: shownIds, adBonusCount: adBonusCount, roseCount: updated);
      unawaited(
        _firestore.collection('users').doc(uid).collection('private').doc('quota').set({
          'date': today,
          'shownIds': shownIds.toList(),
          'adBonusCount': adBonusCount,
          'roseCount': updated,
        }).catchError((_) {}),
      );
      _notify();
    }
    return result;
  }

  int _roseTodayRaw(String uid) {
    _ensureListening(uid);
    final quota = _quotaCache[uid];
    if (quota == null || quota.date != _todayKey()) return 0;
    return quota.roseCount;
  }

  @override
  int roseUsedToday(String uid) => _roseTodayRaw(uid);

  Future<LikeResult> _likeInternal(String uid, String targetId, {required bool isRose}) async {
    if (!_swipeLimiter.allow(uid)) {
      throw RateLimitException("You're swiping too fast — please slow down.");
    }
    await _userSub(uid, 'swipes').doc(targetId).set({'type': 'like', 'createdAt': FieldValue.serverTimestamp()});

    final matched = await _firestore.runTransaction<bool>((transaction) async {
      final receivedRef = _userSub(uid, 'likesReceived').doc(targetId);
      final receivedSnap = await transaction.get(receivedRef);

      if (receivedSnap.exists) {
        final now = FieldValue.serverTimestamp();
        // `otherUserId` duplicates the document ID as a queryable field —
        // Firestore can't filter a collection-group query on document ID
        // directly, so without this, `cleanupUserOnDelete` (see
        // functions/) has no way to find "every match doc that
        // references uid X" when X's account is deleted, across every
        // other user's `matches` subcollection.
        transaction.set(_userSub(uid, 'matches').doc(targetId), {'matchedAt': now, 'otherUserId': targetId});
        transaction.set(_userSub(targetId, 'matches').doc(uid), {'matchedAt': now, 'otherUserId': uid});
        transaction.delete(receivedRef);
        return true;
      } else {
        // Same reasoning as `otherUserId` above, for the same cleanup
        // function's benefit — finds "every pending like FROM uid X"
        // across other users' `likesReceived` subcollections.
        transaction.set(_userSub(targetId, 'likesReceived').doc(uid), {
          'createdAt': FieldValue.serverTimestamp(),
          'fromUserId': uid,
          'isRose': isRose,
        });
        return false;
      }
    });

    return LikeResult(matched: matched);
  }

  @override
  Future<void> pass(String uid, String targetId) async {
    if (!_swipeLimiter.allow(uid)) {
      throw RateLimitException("You're swiping too fast — please slow down.");
    }
    await _userSub(uid, 'swipes').doc(targetId).set({'type': 'pass', 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> unmatch(String uid, String otherId) async {
    await Future.wait([
      _userSub(uid, 'matches').doc(otherId).delete(),
      _userSub(otherId, 'matches').doc(uid).delete(),
    ]);
  }

  @override
  Future<void> block(String uid, String targetId) async {
    await _userSub(uid, 'blocked').doc(targetId).set({'targetId': targetId, 'createdAt': FieldValue.serverTimestamp()});
    await unmatch(uid, targetId);
  }

  @override
  Future<void> unblock(String uid, String targetId) async {
    await _userSub(uid, 'blocked').doc(targetId).delete();
  }

  @override
  Future<void> report(String uid, String targetId, {required ReportReason reason, String details = ''}) async {
    if (!_reportLimiter.allow(uid)) {
      throw RateLimitException("You've submitted a lot of reports recently. Please try again later.");
    }
    final payload = {
      'reason': reason.name,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await Future.wait([
      _userSub(uid, 'reported').doc(targetId).set(payload),
      _firestore.collection('reports').add({'reporterId': uid, 'targetId': targetId, ...payload}),
    ]);
  }
}
