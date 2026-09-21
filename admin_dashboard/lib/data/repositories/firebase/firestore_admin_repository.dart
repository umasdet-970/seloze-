import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../models/admin_models.dart';
import '../admin_repository.dart';

/// Real Firestore backing for the admin dashboard — reads the SAME
/// `users`, `reports`, and `conversations/*/messages` data dating_app
/// writes (see dating_app/FIREBASE_SETUP.md for the schema). Requires the
/// `admin` custom claim (see this project's FIREBASE_SETUP.md) — without
/// it, every query here fails closed per firestore.rules.
///
/// What's real vs. estimated vs. not-yet-available, and why, is
/// documented field-by-field below rather than silently faked — same
/// spirit as the rest of this codebase's Firebase setup docs. In short:
/// user counts, tiers, verification, matches, messages, the report
/// queue, DAU/MAU, churn, retention, the registration funnel, and
/// acquisition source (Android — see AcquisitionSourceService in
/// dating_app) are all genuine Firestore reads (DAU/MAU/churn/retention
/// are live proxy queries against `lastActiveAt`/`createdAt`, not
/// textbook cohort tracking off a stored activity history — see
/// `_refreshAggregates`). `dashboardStats().monthlyRevenueInr` is still
/// a real-users-×-real-prices *estimate*; `growthMetrics().ltvInr` is
/// instead computed from actual RevenueCat transaction history via the
/// `revenueCatWebhook` Cloud Function, and `.cacInr` from real ad-spend
/// entries in `adSpend` — both stay real-but-zero until, respectively,
/// RevenueCat is configured to send webhooks and an admin enters spend
/// data, which are external-account/manual-entry dependencies, not code
/// gaps (see functions/src/revenuecat_webhook.ts and firestore.rules'
/// comment on the `adSpend` collection).
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance {
    _startListening();
  }

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();

  // The live per-user cache below powers search, tier/country breakdowns,
  // and the report queue's user lookups. It's capped rather than loading
  // every user — fine for a dashboard's working set at moderate scale; a
  // production deployment with 100k+ users would want the count()
  // aggregates (used for totalUsers/newRegistrationsToday/matches/messages
  // below, which stay accurate regardless of cache size) plus Cloud
  // Functions rollups for the breakdowns, per MockAdminRepository's own
  // doc comment about what a "real" version of this needs.
  static const _userCacheLimit = 500;
  static const _reportCacheLimit = 200;

  final Map<String, Map<String, dynamic>> _rawUsers = {};

  // Email / phone live in `users/{uid}/private/account` (owner-only; admins can
  // read it) and no longer on the world-readable profile doc. Fetched once per
  // user in the background and cached; the dashboard falls back to the legacy
  // profile-doc fields for accounts not migrated yet.
  final Map<String, String> _contacts = {};
  final Set<String> _fetchingContacts = {};
  final Map<String, Map<String, dynamic>> _rawReports = {};
  final Map<String, Map<String, dynamic>> _rawAuditLog = {};
  final Set<String> _fetchingUserIds = {};

  int? _totalUsersCount;
  int? _totalMatchesCount;
  int? _totalMessagesCount;
  int _newRegistrationsToday = 0;
  int _dailyActiveUsers = 0;
  int _monthlyActiveUsers = 0;
  double _monthlyChurnPct = 0;
  final Map<String, int> _funnelCounts = {};
  List<RetentionPoint> _retentionPoints = const [];
  double _cacInr = 0;
  double _ltvInr = 0;

  void _notify() => _controller.add(null);

  Future<void> _loadContact(String uid) async {
    if (_contacts.containsKey(uid) || !_fetchingContacts.add(uid)) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).collection('private').doc('account').get();
      final data = doc.data();
      final contact = (data?['email'] as String?) ?? (data?['phoneNumber'] as String?);
      if (contact != null) {
        _contacts[uid] = contact;
        _notify();
      }
    } catch (_) {
      // Not readable yet (rules not redeployed) — keep the legacy fallback.
    } finally {
      _fetchingContacts.remove(uid);
    }
  }

  void _startListening() {
    _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(_userCacheLimit)
        .snapshots()
        .listen((snap) {
      _rawUsers
        ..clear()
        ..addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
      _notify();
      for (final d in snap.docs) {
        _loadContact(d.id);
      }
    }, onError: (_) {
      // Most likely cause: signed in but missing the `admin` claim, or
      // rules not yet redeployed. Leave the cache empty rather than crash
      // the dashboard — the UI will just show zero users.
    });

    _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(_reportCacheLimit)
        .snapshots()
        .listen((snap) {
      _rawReports
        ..clear()
        ..addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
      _notify();
    }, onError: (_) {});

    _firestore
        .collection('auditLogs')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      _rawAuditLog
        ..clear()
        ..addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
      _notify();
    }, onError: (_) {});

    unawaited(_refreshAggregates());
    // DAU/MAU/churn/retention/funnel are read-mostly aggregates that
    // don't have a live listener (unlike users/reports/auditLogs above)
    // — re-poll periodically so an open dashboard doesn't show
    // increasingly stale numbers. 2 minutes balances freshness against
    // `count()` query cost (billed per query, not per document matched,
    // but still not free to poll every second).
    // No reference kept, never cancelled — this repository is a
    // singleton for the app's lifetime (see adminRepositoryProvider),
    // same as the snapshot listeners in _startListening() above, none
    // of which are cancelled either.
    Timer.periodic(const Duration(minutes: 2), (_) => _refreshAggregates());
  }

  /// Every mutating admin action writes one of these (spec section 20:
  /// "Audit logs") — `create`-only per firestore.rules, so once written
  /// an entry can't be edited or deleted, including by another admin.
  Future<void> _recordAudit(String action, String targetUserId, String targetUserName, {String details = ''}) async {
    await _firestore.collection('auditLogs').add({
      'adminEmail': fb.FirebaseAuth.instance.currentUser?.email ?? 'unknown',
      'action': action,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _refreshAggregates() async {
    // Independent groups, run in parallel — each is internally parallel
    // too (Future.wait of count() queries), kept as separate Future<void>
    // methods rather than one flat list because they return different
    // shapes (AggregateQuerySnapshot vs. a counts map vs. a List<RetentionPoint>).
    await Future.wait([
      _refreshCoreCounts(),
      _refreshFunnelCounts(),
      _refreshRetentionPoints(),
      _refreshCac(),
      _refreshLtv(),
    ]);
    _notify();
  }

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// CAC (spec section 17) = this month's ad spend ÷ users acquired via a
  /// paid channel this month. Spend comes from `adSpend/{channelMonthKey}`
  /// docs — no automated writer exists yet (would need a Meta/Google Ads
  /// API integration, a separate external-account-dependent piece), so
  /// this stays real-but-zero until an admin enters spend manually (see
  /// firestore.rules' comment on that collection). "Paid channel" =
  /// anything dating_app's AcquisitionSourceService captured other than
  /// 'Organic/Direct'. Computed from the already-loaded, capped
  /// `_rawUsers` cache (same bounded-cache caveat as countryStats/
  /// searchUsers) rather than a fresh query, since combining a
  /// createdAt-this-month filter with an acquisitionSource filter on two
  /// different fields would need yet another composite index for
  /// marginal benefit over what's already cached.
  Future<void> _refreshCac() async {
    try {
      final monthKey = _monthKey(DateTime.now());
      final spendDocs = await _firestore.collection('adSpend').where('month', isEqualTo: monthKey).get();
      final totalSpend = spendDocs.docs.fold<double>(0, (total, d) => total + ((d.data()['spendInr'] as num?)?.toDouble() ?? 0));

      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final paidSignupsThisMonth = _rawUsers.values.where((data) {
        final source = data['acquisitionSource'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return source != null && source != 'Organic/Direct' && createdAt != null && !createdAt.isBefore(startOfMonth);
      }).length;

      _cacInr = paidSignupsThisMonth == 0 ? 0 : totalSpend / paidSignupsThisMonth;
    } catch (_) {
      // adSpend collection not created yet (no admin has entered
      // anything), or the usual claim/rules-not-deployed cause — leave
      // the prior value in place.
    }
  }

  // Bounded — same reasoning as _userCacheLimit/_reportCacheLimit: a
  // dashboard's working set, not a full production-scale ledger (which
  // would want the same count()/sum() aggregate-query treatment as the
  // core counts above, once genuinely needed at that volume).
  static const _revenueEventsCacheLimit = 2000;

  /// LTV (spec section 17) = average realized revenue per paying user,
  /// from real RevenueCat transaction history — `revenueCatEvents`,
  /// written by the `revenueCatWebhook` Cloud Function (see
  /// functions/src/revenuecat_webhook.ts), not estimated from current
  /// subscriber counts like `dashboardStats().monthlyRevenueInr` is.
  /// Stays real-but-zero until RevenueCat is configured to POST to that
  /// webhook — an external-account-dependent step, not a code gap.
  Future<void> _refreshLtv() async {
    try {
      final snapshot = await _firestore
          .collection('revenueCatEvents')
          .orderBy('eventTimestampMs', descending: true)
          .limit(_revenueEventsCacheLimit)
          .get();

      double totalRevenueUsd = 0;
      final payingUids = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final revenue = (data['revenueUsd'] as num?)?.toDouble() ?? 0;
        if (revenue > 0) {
          totalRevenueUsd += revenue;
          final uid = data['uid'] as String?;
          if (uid != null) payingUids.add(uid);
        }
      }

      // Converted at a fixed illustrative rate rather than a live FX
      // API (a currency-conversion service is its own external
      // dependency, out of scope for "revenue data plumbing") — update
      // this constant if you want a more current rate.
      const usdToInr = 83.0;
      _ltvInr = payingUids.isEmpty ? 0 : (totalRevenueUsd / payingUids.length) * usdToInr;
    } catch (_) {
      // revenueCatEvents collection not created yet (webhook never
      // fired), or the usual claim/rules-not-deployed cause.
    }
  }

  Future<void> _refreshCoreCounts() async {
    try {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final thirtyDaysAgo = Timestamp.fromDate(now.subtract(const Duration(days: 30)));
      final sixtyDaysAgo = Timestamp.fromDate(now.subtract(const Duration(days: 60)));
      final usersRef = _firestore.collection('users');

      final results = await Future.wait([
        usersRef.count().get(), // 0: total users
        _firestore.collectionGroup('matches').count().get(), // 1
        _firestore.collectionGroup('messages').count().get(), // 2
        usersRef.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight)).count().get(), // 3: new today
        usersRef.where('lastActiveAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight)).count().get(), // 4: DAU
        usersRef.where('lastActiveAt', isGreaterThanOrEqualTo: thirtyDaysAgo).count().get(), // 5: MAU
        // Churn proxy: users last seen 30-60 days ago (i.e. went quiet
        // roughly a month ago and haven't returned since) as a fraction
        // of users old enough to have possibly churned by now. Both
        // filters are on the SAME field (lastActiveAt), so this is a
        // single-field range query — no composite index needed, unlike
        // the retention queries below.
        usersRef.where('lastActiveAt', isGreaterThanOrEqualTo: sixtyDaysAgo, isLessThan: thirtyDaysAgo).count().get(), // 6
        usersRef.where('createdAt', isLessThanOrEqualTo: thirtyDaysAgo).count().get(), // 7: churn-eligible
      ]);

      _totalUsersCount = results[0].count;
      // Each match is written into BOTH participants' `matches` subcollections
      // (see FirestoreSocialRepository.like) — halve the raw doc count to
      // get the number of actual matches, not match-memberships.
      _totalMatchesCount = ((results[1].count ?? 0) / 2).round();
      _totalMessagesCount = results[2].count;
      _newRegistrationsToday = results[3].count ?? 0;
      _dailyActiveUsers = results[4].count ?? 0;
      _monthlyActiveUsers = results[5].count ?? 0;

      final churned = results[6].count ?? 0;
      final churnEligible = results[7].count ?? 0;
      _monthlyChurnPct = churnEligible == 0 ? 0 : (churned / churnEligible * 100);
    } catch (_) {
      // Most likely cause: signed in but missing the `admin` claim, rules
      // not deployed yet, or (for the two range-on-lastActiveAt queries)
      // the composite index still building — leave prior values in place
      // rather than zero them out on a transient failure.
    }
  }

  /// Registration/conversion funnel (spec section 17) — counts distinct
  /// users who've reached each milestone, written by dating_app's
  /// FirebaseAnalyticsRepository into `analyticsFunnel/{uid}` (see that
  /// file's doc comment for why milestones, not raw event counts).
  static const _funnelStages = [
    ('Sign-ups', 'signedUp'),
    ('Age verified', 'ageVerified'),
    ('Profile completed', 'profileCompleted'),
    ('First like sent', 'likedSomeone'),
    ('First match', 'matched'),
    ('Premium conversion', 'subscribed'),
  ];

  Future<void> _refreshFunnelCounts() async {
    try {
      final funnelRef = _firestore.collection('analyticsFunnel');
      final results = await Future.wait(
        _funnelStages.map((stage) => funnelRef.where(stage.$2, isEqualTo: true).count().get()),
      );
      for (var i = 0; i < _funnelStages.length; i++) {
        _funnelCounts[_funnelStages[i].$1] = results[i].count ?? 0;
      }
    } catch (_) {
      // Leave prior counts in place — same reasoning as _refreshCoreCounts.
    }
  }

  /// Retention (spec section 17): NOT textbook cohort tracking (this app
  /// doesn't store a full daily-activity history per user, only the most
  /// recent `lastActiveAt`) — a live proxy instead. "Day-N retention" =
  /// of users who signed up at least N days ago, what fraction have been
  /// active in the last 3 days. That measures current stickiness of an
  /// N-day-old-or-older cohort, not "were they active on exactly day N",
  /// which this data model can't reconstruct after the fact. Documented
  /// as a proxy rather than presented as textbook retention.
  static const _retentionWindows = [(1, 'Day 1'), (7, 'Day 7'), (30, 'Day 30')];

  Future<void> _refreshRetentionPoints() async {
    try {
      final now = DateTime.now();
      final recentlyActiveSince = Timestamp.fromDate(now.subtract(const Duration(days: 3)));
      final usersRef = _firestore.collection('users');

      final results = await Future.wait(_retentionWindows.expand((w) {
        final cohortCutoff = Timestamp.fromDate(now.subtract(Duration(days: w.$1)));
        return [
          usersRef.where('createdAt', isLessThanOrEqualTo: cohortCutoff).count().get(),
          usersRef
              .where('createdAt', isLessThanOrEqualTo: cohortCutoff)
              .where('lastActiveAt', isGreaterThanOrEqualTo: recentlyActiveSince)
              .count()
              .get(),
        ];
      }));

      final points = <RetentionPoint>[];
      for (var i = 0; i < _retentionWindows.length; i++) {
        final cohortSize = results[i * 2].count ?? 0;
        final stillActive = results[i * 2 + 1].count ?? 0;
        if (cohortSize == 0) continue; // no cohort old enough yet — skip rather than show a misleading 0%
        points.add(RetentionPoint(label: _retentionWindows[i].$2, retentionPct: stillActive / cohortSize * 100));
      }
      _retentionPoints = points;
    } catch (_) {
      // Likely the (createdAt, lastActiveAt) composite index still
      // building after a fresh `firebase deploy --only firestore:indexes`
      // — leave prior points in place.
    }
  }

  void _fetchUserIfMissing(String uid) {
    if (_rawUsers.containsKey(uid) || _fetchingUserIds.contains(uid)) return;
    _fetchingUserIds.add(uid);
    _firestore.collection('users').doc(uid).get().then((doc) {
      _fetchingUserIds.remove(uid);
      final data = doc.data();
      if (data != null) {
        _rawUsers[uid] = data;
        _notify();
      }
    }).catchError((_) {
      _fetchingUserIds.remove(uid);
    });
  }

  AdminUser _buildUser(String uid) {
    final data = _rawUsers[uid];
    if (data == null) {
      // Report target outside the capped cache (or a since-deleted
      // account) — kick off a one-off fetch and return a placeholder
      // synchronously; the next `changes()` tick will have the real data.
      _fetchUserIfMissing(uid);
      return AdminUser(
        id: uid,
        name: '(loading…)',
        email: '—',
        country: '—',
        joinedAt: DateTime.now(),
        status: AccountStatus.active,
        tier: SubscriptionTier.free,
        isVerified: false,
        reportCount: 0,
      );
    }

    final tier = SubscriptionTier.values.firstWhere(
      (t) => t.name == data['subscriptionTier'],
      orElse: () => SubscriptionTier.free,
    );
    final status = AccountStatus.values.firstWhere(
      (s) => s.name == data['accountStatus'],
      orElse: () => AccountStatus.active,
    );
    final name = (data['name'] as String?)?.trim();

    return AdminUser(
      id: uid,
      name: (name == null || name.isEmpty) ? '(no profile yet)' : name,
      email: _contacts[uid] ?? (data['email'] as String?) ?? (data['phoneNumber'] as String?) ?? '—',
      country: (data['country'] as String?)?.trim().isNotEmpty == true ? data['country'] as String : 'Unknown',
      joinedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: status,
      tier: tier,
      isVerified: data['isVerified'] as bool? ?? false,
      reportCount: _rawReports.values.where((r) => r['targetId'] == uid).length,
      // Written once by dating_app's ProfileRiskScorer at profile-save
      // time (see FirestoreUserProfileRepository.saveProfile) — read
      // as-is here, not recomputed. Absent entirely on users who signed
      // up before this pass or haven't completed onboarding yet.
      riskScore: data['riskScore'] as int? ?? 0,
      riskSignals: List<String>.from(data['riskSignals'] as List? ?? const []),
    );
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  DashboardStats dashboardStats() {
    final users = _rawUsers.keys.map(_buildUser).toList();
    final free = users.where((u) => u.tier == SubscriptionTier.free).length;
    final premium = users.where((u) => u.tier == SubscriptionTier.premium).length;
    final adFree = users.where((u) => u.tier == SubscriptionTier.adFree).length;

    // Estimated from real, currently-cached subscriber counts × the real
    // published prices (subscription_models.dart), NOT actual RevenueCat
    // transaction totals — see BILLING_SETUP.md on why that data doesn't
    // exist without webhooks. Treats every Premium subscriber as the
    // ₹899 monthly plan (can't distinguish the ₹1,899/3-month plan from
    // `subscriptionTier` alone), so this skews low if many users are on
    // the 3-month plan.
    final estimatedMonthlyRevenue = premium * 899.0 + adFree * 99.0;

    return DashboardStats(
      totalUsers: _totalUsersCount ?? _rawUsers.length,
      dailyActiveUsers: _dailyActiveUsers,
      monthlyActiveUsers: _monthlyActiveUsers,
      newRegistrationsToday: _newRegistrationsToday,
      freeUsers: free,
      premiumUsers: premium,
      adFreeUsers: adFree,
      totalMatches: _totalMatchesCount ?? 0,
      totalMessages: _totalMessagesCount ?? 0,
      monthlyRevenueInr: estimatedMonthlyRevenue,
    );
  }

  @override
  List<RevenuePoint> revenueTrend({int days = 14}) {
    // No transaction history without RevenueCat webhooks (see
    // dashboardStats' comment) — a flat line at today's estimate is an
    // honest "here's the current number, we don't have history" rather
    // than fabricating a trend shape like the mock does.
    final today = dashboardStats().monthlyRevenueInr / 30;
    final now = DateTime.now();
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      return RevenuePoint(date: date, amountInr: today);
    });
  }

  @override
  List<CountryStat> countryStats() {
    final users = _rawUsers.keys.map(_buildUser).toList();
    final byCountry = <String, List<AdminUser>>{};
    for (final u in users) {
      byCountry.putIfAbsent(u.country, () => []).add(u);
    }
    return byCountry.entries.map((e) {
      final revenue = e.value.where((u) => u.tier != SubscriptionTier.free).length * 899.0;
      return CountryStat(country: e.key, users: e.value.length, revenueInr: revenue);
    }).toList()
      ..sort((a, b) => b.users.compareTo(a.users));
  }

  @override
  List<AdminUser> searchUsers(String query) {
    final users = _rawUsers.keys.map(_buildUser).toList()..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    if (query.trim().isEmpty) return users;
    final lower = query.trim().toLowerCase();
    return users.where((u) => u.name.toLowerCase().contains(lower) || u.email.toLowerCase().contains(lower)).toList();
  }

  @override
  Future<void> setUserStatus(String userId, AccountStatus status) async {
    await _firestore.collection('users').doc(userId).set(
      {'accountStatus': status.name},
      SetOptions(merge: true),
    );
    // The listener will pick up the change and _notify(), but that can
    // lag a moment behind the Future resolving — update the local cache
    // immediately so the UI reflects the action without waiting on it.
    _rawUsers[userId]?['accountStatus'] = status.name;
    unawaited(_recordAudit('Set account status to ${status.label}', userId, _buildUser(userId).name));
    _notify();
  }

  @override
  Future<void> setVerified(String userId, bool verified) async {
    await _firestore.collection('users').doc(userId).set(
      {'isVerified': verified},
      SetOptions(merge: true),
    );
    _rawUsers[userId]?['isVerified'] = verified;
    unawaited(_recordAudit(verified ? 'Verified profile' : 'Removed verification', userId, _buildUser(userId).name));
    _notify();
  }

  @override
  List<AdminUser> flaggedProfiles() {
    // See MockAdminRepository.flaggedProfiles for why verifying/suspending
    // is what clears an entry from this queue (no separate "reviewed"
    // flag needed).
    return _rawUsers.keys
        .map(_buildUser)
        .where((u) => u.riskScore >= 25 && !u.isVerified && u.status == AccountStatus.active)
        .toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
  }

  @override
  List<ReportQueueItem> reportQueue() {
    return _rawReports.entries.map((entry) {
      final data = entry.value;
      final targetId = data['targetId'] as String? ?? '';
      final reporterId = data['reporterId'] as String? ?? '';
      final statusName = data['status'] as String?;
      final actionName = data['actionTaken'] as String?;
      return ReportQueueItem(
        id: entry.key,
        reporterName: reporterId.isEmpty ? 'Unknown' : _buildUser(reporterId).name,
        target: _buildUser(targetId),
        reason: data['reason'] as String? ?? 'Other',
        details: data['details'] as String? ?? '',
        submittedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: statusName == 'resolved' ? ReportStatus.resolved : ReportStatus.pending,
        actionTaken: ModerationAction.values.firstWhereOrNull((a) => a.name == actionName),
      );
    }).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Future<void> resolveReport(String reportId, ModerationAction action) async {
    await _firestore.collection('reports').doc(reportId).set(
      {'status': 'resolved', 'actionTaken': action.name},
      SetOptions(merge: true),
    );
    _rawReports[reportId]?['status'] = 'resolved';
    _rawReports[reportId]?['actionTaken'] = action.name;

    final targetId = _rawReports[reportId]?['targetId'] as String?;
    if (targetId != null) {
      unawaited(_recordAudit('Resolved report ($reportId): ${action.label}', targetId, _buildUser(targetId).name));
    }
    if (targetId != null && action != ModerationAction.dismissed) {
      final newStatus = switch (action) {
        ModerationAction.warning => AccountStatus.warned,
        ModerationAction.suspension => AccountStatus.suspended,
        ModerationAction.ban => AccountStatus.banned,
        ModerationAction.dismissed => AccountStatus.active,
      };
      await setUserStatus(targetId, newStatus);
    }
    _notify();
  }

  @override
  List<AuditLogEntry> auditLog() {
    return _rawAuditLog.entries.map((entry) {
      final data = entry.value;
      return AuditLogEntry(
        id: entry.key,
        adminEmail: data['adminEmail'] as String? ?? 'unknown',
        action: data['action'] as String? ?? '',
        targetUserId: data['targetUserId'] as String? ?? '',
        targetUserName: data['targetUserName'] as String? ?? '',
        details: data['details'] as String? ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  List<FunnelStep> registrationFunnel() {
    return _funnelStages.map((stage) => FunnelStep(label: stage.$1, users: _funnelCounts[stage.$1] ?? 0)).toList();
  }

  @override
  List<RetentionPoint> retentionCurve() => _retentionPoints;

  /// Acquisition source (spec section 17) — real, from dating_app's
  /// AcquisitionSourceService (Android Play Install Referrer; iOS has no
  /// equivalent and is honestly bucketed as 'Organic/Direct' — see that
  /// class's doc comment). Grouped from the same capped `_rawUsers`
  /// cache as countryStats, same bounded-cache caveat. Users who signed
  /// up before this field existed simply have no `acquisitionSource` at
  /// all and are excluded here, rather than miscounted as any specific
  /// channel.
  @override
  List<AcquisitionSource> acquisitionSources() {
    final counts = <String, int>{};
    for (final data in _rawUsers.values) {
      final source = data['acquisitionSource'] as String?;
      if (source == null || source.isEmpty) continue;
      counts[source] = (counts[source] ?? 0) + 1;
    }
    return counts.entries.map((e) => AcquisitionSource(channel: e.key, users: e.value)).toList()
      ..sort((a, b) => b.users.compareTo(a.users));
  }

  @override
  GrowthMetrics growthMetrics() {
    final stats = dashboardStats();
    final totalUsers = stats.totalUsers;
    return GrowthMetrics(
      cacInr: double.parse(_cacInr.toStringAsFixed(2)),
      ltvInr: double.parse(_ltvInr.toStringAsFixed(2)),
      monthlyChurnPct: double.parse(_monthlyChurnPct.toStringAsFixed(1)),
      // Current conversion rate (right-now tier snapshot), distinct from
      // the funnel's "Premium conversion" stage (count of users who
      // EVER subscribed, even if since lapsed) — both are real, they
      // just answer different questions.
      premiumConversionPct: totalUsers == 0 ? 0 : double.parse((stats.premiumUsers / totalUsers * 100).toStringAsFixed(1)),
      adFreeConversionPct: totalUsers == 0 ? 0 : double.parse((stats.adFreeUsers / totalUsers * 100).toStringAsFixed(1)),
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
