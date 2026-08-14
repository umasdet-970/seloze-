/// A confirmed mutual match (spec section 6).
class MatchRecord {
  final String otherUserId;
  final DateTime matchedAt;

  const MatchRecord({required this.otherUserId, required this.matchedAt});
}

/// Result of a Like action (spec section 6: mutual Like creates Match).
class LikeResult {
  final bool matched;
  const LikeResult({required this.matched});
}

/// Report reasons (spec section 11).
enum ReportReason { fakeProfile, inappropriatePhotos, harassment, spam, underage, other }

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
        ReportReason.fakeProfile => 'Fake profile',
        ReportReason.inappropriatePhotos => 'Inappropriate photos',
        ReportReason.harassment => 'Harassment or abuse',
        ReportReason.spam => 'Spam or scam',
        ReportReason.underage => 'Underage user',
        ReportReason.other => 'Other',
      };
}
