import 'dart:async';
import 'dart:math';

import '../models/admin_models.dart';
import 'admin_auth_repository.dart';

/// Everything an admin needs (spec section 16). This talks to a shared
/// backend in production (Firestore + Cloud Functions aggregations) —
/// there's no such backend yet, so this mock generates a believable
/// multi-user dataset locally. Unlike the mobile app's mocks (which only
/// ever simulate ONE signed-in user), this is the first repository in the
/// whole project that has to fabricate cross-user aggregate data, since
/// there's no real multi-user backend to read it from.
abstract class AdminRepository {
  Stream<void> changes();

  DashboardStats dashboardStats();
  List<RevenuePoint> revenueTrend({int days = 14});
  List<CountryStat> countryStats();

  List<AdminUser> searchUsers(String query);
  Future<void> setUserStatus(String userId, AccountStatus status);
  Future<void> setVerified(String userId, bool verified);

  /// Users whose automated risk score (spec section 3/12/19) crossed the
  /// review threshold — the proactive counterpart to [reportQueue], which
  /// only surfaces profiles someone has already reported.
  List<AdminUser> flaggedProfiles();

  List<ReportQueueItem> reportQueue();
  Future<void> resolveReport(String reportId, ModerationAction action);

  List<FunnelStep> registrationFunnel();
  List<RetentionPoint> retentionCurve();
  List<AcquisitionSource> acquisitionSources();
  GrowthMetrics growthMetrics();

  /// Audit trail (spec section 20) — every setUserStatus/setVerified/
  /// resolveReport call records an entry here automatically; there's no
  /// separate "log this" call site for UI code to remember.
  List<AuditLogEntry> auditLog();
}

class MockAdminRepository implements AdminRepository {
  final _controller = StreamController<void>.broadcast();
  late final List<AdminUser> _users;
  late final List<ReportQueueItem> _reports;
  late final List<RevenuePoint> _revenueTrend;
  final List<AuditLogEntry> _auditLog = [];
  int _nextAuditId = 1;

  // Only one admin identity exists in the mock (see MockAdminAuthRepository) —
  // real deployments attribute each entry to whichever admin actually signed
  // the action, read from FirebaseAuth in FirestoreAdminRepository.
  void _recordAudit(String action, AdminUser target, {String details = ''}) {
    _auditLog.insert(
      0,
      AuditLogEntry(
        id: 'audit-${_nextAuditId++}',
        adminEmail: MockAdminAuthRepository.demoEmail,
        action: action,
        targetUserId: target.id,
        targetUserName: target.name,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  static const _countries = ['India', 'United States', 'United Kingdom', 'UAE', 'Canada', 'Australia', 'Germany', 'Singapore'];
  static const _firstNames = [
    'Ananya', 'Rohan', 'Meera', 'Kabir', 'Priya', 'Arjun', 'Sneha', 'Vikram', 'Ishita', 'Dev',
    'Olivia', 'Liam', 'Emma', 'Noah', 'Ava', 'James', 'Sophia', 'Lucas', 'Mia', 'Ethan',
  ];
  static const _lastNames = ['Sharma', 'Patel', 'Khan', 'Singh', 'Reddy', 'Smith', 'Johnson', 'Brown', 'Wilson', 'Taylor'];
  static const _reportReasons = ['Fake profile', 'Inappropriate photos', 'Harassment or abuse', 'Spam or scam', 'Underage user', 'Other'];
  static const _riskSignalPool = [
    'Only one photo',
    'Empty bio',
    'Bio contains a spam/off-platform link or keyword',
    'Name looks auto-generated',
    'Bio is all caps',
  ];

  MockAdminRepository() {
    _seed();
  }

  void _notify() => _controller.add(null);

  void _seed() {
    final random = Random(42); // fixed seed: stable demo data across reloads
    final now = DateTime.now();

    _users = List.generate(64, (i) {
      final tier = i % 10 == 0
          ? SubscriptionTier.adFree
          : i % 4 == 0
              ? SubscriptionTier.premium
              : SubscriptionTier.free;
      final status = i % 23 == 0
          ? AccountStatus.banned
          : i % 17 == 0
              ? AccountStatus.suspended
              : i % 11 == 0
                  ? AccountStatus.warned
                  : AccountStatus.active;
      // Roughly 1 in 9 seeded users looks suspicious, with a couple of
      // plausible signals — demonstrates the flagged-profiles queue
      // without every demo user tripping it.
      final flagged = i % 9 == 0;
      final signals = flagged
          ? (List.of(_riskSignalPool)..shuffle(random)).take(1 + random.nextInt(2)).toList()
          : const <String>[];
      final riskScore = flagged ? 25 + random.nextInt(50) : random.nextInt(15);

      return AdminUser(
        id: 'user-$i',
        name: '${_firstNames[i % _firstNames.length]} ${_lastNames[(i * 3) % _lastNames.length]}',
        email: 'user$i@example.com',
        country: _countries[i % _countries.length],
        joinedAt: now.subtract(Duration(days: random.nextInt(180))),
        status: status,
        tier: tier,
        isVerified: random.nextBool(),
        reportCount: status == AccountStatus.active ? 0 : 1 + random.nextInt(4),
        riskScore: riskScore,
        riskSignals: signals,
      );
    });

    _reports = List.generate(9, (i) {
      final target = _users[(i * 7) % _users.length];
      return ReportQueueItem(
        id: 'report-$i',
        reporterName: '${_firstNames[(i * 5) % _firstNames.length]} ${_lastNames[i % _lastNames.length]}',
        target: target,
        reason: _reportReasons[i % _reportReasons.length],
        details: i % 3 == 0 ? 'Kept asking to move the conversation off-platform.' : '',
        submittedAt: now.subtract(Duration(hours: random.nextInt(72))),
      );
    });

    _revenueTrend = List.generate(14, (i) {
      final date = now.subtract(Duration(days: 13 - i));
      final base = 45000 + i * 1800;
      final noise = random.nextInt(6000) - 3000;
      return RevenuePoint(date: date, amountInr: (base + noise).toDouble());
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  DashboardStats dashboardStats() {
    final free = _users.where((u) => u.tier == SubscriptionTier.free).length;
    final premium = _users.where((u) => u.tier == SubscriptionTier.premium).length;
    final adFree = _users.where((u) => u.tier == SubscriptionTier.adFree).length;
    return DashboardStats(
      totalUsers: _users.length,
      dailyActiveUsers: (_users.length * 0.42).round(),
      monthlyActiveUsers: (_users.length * 0.71).round(),
      newRegistrationsToday: 7,
      freeUsers: free,
      premiumUsers: premium,
      adFreeUsers: adFree,
      totalMatches: 1284,
      totalMessages: 18732,
      monthlyRevenueInr: _revenueTrend.fold(0.0, (sum, p) => sum + p.amountInr) / 14 * 30,
    );
  }

  @override
  List<RevenuePoint> revenueTrend({int days = 14}) => List.unmodifiable(_revenueTrend.take(days));

  @override
  List<CountryStat> countryStats() {
    return _countries.map((country) {
      final usersInCountry = _users.where((u) => u.country == country).toList();
      final revenue = usersInCountry.where((u) => u.tier != SubscriptionTier.free).length * 899.0;
      return CountryStat(country: country, users: usersInCountry.length, revenueInr: revenue);
    }).toList()
      ..sort((a, b) => b.users.compareTo(a.users));
  }

  @override
  List<AdminUser> searchUsers(String query) {
    if (query.trim().isEmpty) return List.unmodifiable(_users);
    final lower = query.toLowerCase();
    return _users.where((u) => u.name.toLowerCase().contains(lower) || u.email.toLowerCase().contains(lower)).toList();
  }

  @override
  Future<void> setUserStatus(String userId, AccountStatus status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(status: status);
      _recordAudit('Set account status to ${status.label}', _users[index]);
      _notify();
    }
  }

  @override
  Future<void> setVerified(String userId, bool verified) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(isVerified: verified);
      _recordAudit(verified ? 'Verified profile' : 'Removed verification', _users[index]);
      _notify();
    }
  }

  @override
  List<AdminUser> flaggedProfiles() {
    // Verifying a profile is treated as "an admin reviewed this and it's
    // legitimate" — it both grants the verified badge and clears the
    // flag, so this queue empties as it's worked rather than staying
    // static. Suspending/banning removes it from Discover entirely,
    // which has the same practical effect.
    return _users.where((u) => u.riskScore >= 25 && !u.isVerified && u.status == AccountStatus.active).toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
  }

  @override
  List<ReportQueueItem> reportQueue() => List.unmodifiable(_reports);

  @override
  Future<void> resolveReport(String reportId, ModerationAction action) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index == -1) return;
    _reports[index] = _reports[index].copyWith(status: ReportStatus.resolved, actionTaken: action);

    final userIndex = _users.indexWhere((u) => u.id == _reports[index].target.id);
    if (userIndex != -1) {
      final newStatus = switch (action) {
        ModerationAction.warning => AccountStatus.warned,
        ModerationAction.suspension => AccountStatus.suspended,
        ModerationAction.ban => AccountStatus.banned,
        ModerationAction.dismissed => _users[userIndex].status,
      };
      _users[userIndex] = _users[userIndex].copyWith(status: newStatus);
      _recordAudit('Resolved report ($reportId): ${action.label}', _users[userIndex]);
    }
    _notify();
  }

  @override
  List<AuditLogEntry> auditLog() => List.unmodifiable(_auditLog);

  @override
  List<FunnelStep> registrationFunnel() {
    // Illustrative drop-off shape — a real funnel comes from analytics
    // events (sign_up, age_verified, profile_completed, like/match,
    // subscription_purchase) logged by the mobile app's AnalyticsRepository.
    const signups = 1000;
    return const [
      FunnelStep(label: 'Sign-ups', users: signups),
      FunnelStep(label: 'Age verified', users: 930),
      FunnelStep(label: 'Profile completed', users: 760),
      FunnelStep(label: 'First like sent', users: 640),
      FunnelStep(label: 'First match', users: 410),
      FunnelStep(label: 'Premium conversion', users: 96),
    ];
  }

  @override
  List<RetentionPoint> retentionCurve() {
    return const [
      RetentionPoint(label: 'Day 1', retentionPct: 62),
      RetentionPoint(label: 'Day 7', retentionPct: 34),
      RetentionPoint(label: 'Day 30', retentionPct: 18),
    ];
  }

  @override
  List<AcquisitionSource> acquisitionSources() {
    return const [
      AcquisitionSource(channel: 'Meta Ads', users: 420),
      AcquisitionSource(channel: 'Google Ads', users: 310),
      AcquisitionSource(channel: 'YouTube', users: 140),
      AcquisitionSource(channel: 'Organic / referral', users: 194),
    ];
  }

  @override
  GrowthMetrics growthMetrics() {
    return const GrowthMetrics(
      cacInr: 285,
      ltvInr: 1840,
      monthlyChurnPct: 8.4,
      premiumConversionPct: 9.6,
      adFreeConversionPct: 3.1,
    );
  }
}
