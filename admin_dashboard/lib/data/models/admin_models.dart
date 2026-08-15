/// Spec section 16 (Admin Dashboard) + 12 (safety escalation: Warning →
/// Suspension → Permanent ban).
enum AccountStatus { active, warned, suspended, banned }

extension AccountStatusLabel on AccountStatus {
  String get label => switch (this) {
        AccountStatus.active => 'Active',
        AccountStatus.warned => 'Warned',
        AccountStatus.suspended => 'Suspended',
        AccountStatus.banned => 'Banned',
      };
}

enum SubscriptionTier { free, premium, adFree }

extension SubscriptionTierLabel on SubscriptionTier {
  String get label => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.premium => 'Premium',
        SubscriptionTier.adFree => 'Ad-Free',
      };
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String country;
  final DateTime joinedAt;
  final AccountStatus status;
  final SubscriptionTier tier;
  final bool isVerified;
  final int reportCount;
  // Automated suspicious-profile score (spec section 3/12/19), computed
  // once by dating_app's ProfileRiskScorer at profile-save time and read
  // here as-is — see firestore_admin_repository.dart's doc comment.
  final int riskScore;
  final List<String> riskSignals;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.country,
    required this.joinedAt,
    required this.status,
    required this.tier,
    required this.isVerified,
    required this.reportCount,
    this.riskScore = 0,
    this.riskSignals = const [],
  });

  AdminUser copyWith({AccountStatus? status, bool? isVerified}) {
    return AdminUser(
      id: id,
      name: name,
      email: email,
      country: country,
      joinedAt: joinedAt,
      status: status ?? this.status,
      tier: tier,
      isVerified: isVerified ?? this.isVerified,
      reportCount: reportCount,
      riskScore: riskScore,
      riskSignals: riskSignals,
    );
  }
}

enum ReportStatus { pending, resolved }

enum ModerationAction { dismissed, warning, suspension, ban }

extension ModerationActionLabel on ModerationAction {
  String get label => switch (this) {
        ModerationAction.dismissed => 'Dismissed',
        ModerationAction.warning => 'Warned user',
        ModerationAction.suspension => 'Suspended user',
        ModerationAction.ban => 'Banned user',
      };
}

class ReportQueueItem {
  final String id;
  final String reporterName;
  final AdminUser target;
  final String reason;
  final String details;
  final DateTime submittedAt;
  final ReportStatus status;
  final ModerationAction? actionTaken;

  const ReportQueueItem({
    required this.id,
    required this.reporterName,
    required this.target,
    required this.reason,
    required this.details,
    required this.submittedAt,
    this.status = ReportStatus.pending,
    this.actionTaken,
  });

  ReportQueueItem copyWith({ReportStatus? status, ModerationAction? actionTaken}) {
    return ReportQueueItem(
      id: id,
      reporterName: reporterName,
      target: target,
      reason: reason,
      details: details,
      submittedAt: submittedAt,
      status: status ?? this.status,
      actionTaken: actionTaken ?? this.actionTaken,
    );
  }
}

class RevenuePoint {
  final DateTime date;
  final double amountInr;
  const RevenuePoint({required this.date, required this.amountInr});
}

class CountryStat {
  final String country;
  final int users;
  final double revenueInr;
  const CountryStat({required this.country, required this.users, required this.revenueInr});
}

class DashboardStats {
  final int totalUsers;
  final int dailyActiveUsers;
  final int monthlyActiveUsers;
  final int newRegistrationsToday;
  final int freeUsers;
  final int premiumUsers;
  final int adFreeUsers;
  final int totalMatches;
  final int totalMessages;
  final double monthlyRevenueInr;

  const DashboardStats({
    required this.totalUsers,
    required this.dailyActiveUsers,
    required this.monthlyActiveUsers,
    required this.newRegistrationsToday,
    required this.freeUsers,
    required this.premiumUsers,
    required this.adFreeUsers,
    required this.totalMatches,
    required this.totalMessages,
    required this.monthlyRevenueInr,
  });
}

/// One stage of the registration/monetization funnel (spec section 17).
class FunnelStep {
  final String label;
  final int users;
  const FunnelStep({required this.label, required this.users});
}

/// Cohort retention at fixed intervals after signup.
class RetentionPoint {
  final String label; // 'Day 1', 'Day 7', 'Day 30'
  final double retentionPct;
  const RetentionPoint({required this.label, required this.retentionPct});
}

class AcquisitionSource {
  final String channel;
  final int users;
  const AcquisitionSource({required this.channel, required this.users});
}

/// One admin moderation action (spec section 20: "Audit logs"). Written
/// automatically by AdminRepository whenever setUserStatus/setVerified/
/// resolveReport run — never editable, so it stays a trustworthy record
/// of who did what and when, not just what the current state is.
class AuditLogEntry {
  final String id;
  final String adminEmail;
  final String action;
  final String targetUserId;
  final String targetUserName;
  final String details;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.adminEmail,
    required this.action,
    required this.targetUserId,
    required this.targetUserName,
    required this.details,
    required this.createdAt,
  });
}

/// Illustrative growth metrics — a real CAC/LTV needs ad-spend data from
/// Meta/Google/YouTube ad accounts and observed revenue per cohort over
/// time, neither of which exist without those integrations.
class GrowthMetrics {
  final double cacInr;
  final double ltvInr;
  final double monthlyChurnPct;
  final double premiumConversionPct;
  final double adFreeConversionPct;

  const GrowthMetrics({
    required this.cacInr,
    required this.ltvInr,
    required this.monthlyChurnPct,
    required this.premiumConversionPct,
    required this.adFreeConversionPct,
  });
}
