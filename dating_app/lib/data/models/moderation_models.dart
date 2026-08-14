/// Spec section 12/19: profile text moderation, message safety checks.
enum ModerationCategory { none, harassment, spam, contactInfoSharing }

class ModerationResult {
  final bool allowed;
  final ModerationCategory category;
  final String? reason;

  const ModerationResult({required this.allowed, this.category = ModerationCategory.none, this.reason});

  static const ok = ModerationResult(allowed: true);
}
