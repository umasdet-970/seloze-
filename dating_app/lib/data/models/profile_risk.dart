/// Automated suspicious-profile / fake-profile signal (spec sections 3,
/// 12, 19). Computed once at profile save time by [ProfileRiskScorer] —
/// see that file for the heuristics — and persisted alongside the
/// profile so the admin dashboard's flagged-profiles queue doesn't need
/// to recompute it for every user on every load.
enum RiskLevel { low, medium, high }

extension RiskLevelInfo on RiskLevel {
  static RiskLevel fromScore(int score) {
    if (score >= 50) return RiskLevel.high;
    if (score >= 25) return RiskLevel.medium;
    return RiskLevel.low;
  }

  String get label => switch (this) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
      };
}

class ProfileRiskAssessment {
  final int score;
  final RiskLevel level;
  final List<String> signals;

  const ProfileRiskAssessment({required this.score, required this.level, required this.signals});

  static const none = ProfileRiskAssessment(score: 0, level: RiskLevel.low, signals: []);
}
