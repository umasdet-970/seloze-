import '../../core/utils/spam_signals.dart';
import '../models/moderation_models.dart';

/// Content moderation (spec sections 12, 19: profile text moderation,
/// message safety checks, spam/contact-sharing detection). This is
/// rule-based — a real deployment swaps this for a hosted AI moderation
/// API (e.g. Cloud Vision SafeSearch for photos, Perspective API or a
/// custom classifier for text) behind the same interface. Signal
/// definitions live in `core/utils/spam_signals.dart`, shared with
/// [ProfileRiskScorer] so text-moderation and profile-risk-scoring don't
/// each maintain their own copy of the same regex list.
abstract class ModerationRepository {
  Future<ModerationResult> moderateText(String text);
  Future<ModerationResult> moderatePhoto(String imageUrl);
}

class MockModerationRepository implements ModerationRepository {
  @override
  Future<ModerationResult> moderateText(String text) async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (containsHarassment(text)) {
      return const ModerationResult(
        allowed: false,
        category: ModerationCategory.harassment,
        reason: 'This contains language that violates our community guidelines.',
      );
    }

    if (containsContactInfo(text)) {
      return const ModerationResult(
        allowed: false,
        category: ModerationCategory.contactInfoSharing,
        reason: "For your safety, don't share phone numbers or emails here.",
      );
    }

    if (containsSpamPattern(text)) {
      return const ModerationResult(
        allowed: false,
        category: ModerationCategory.spam,
        reason: 'This looks like spam or an off-platform contact request.',
      );
    }

    return ModerationResult.ok;
  }

  @override
  Future<ModerationResult> moderatePhoto(String imageUrl) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Real implementation calls a vision moderation API here. Mock just
    // validates the URL isn't empty — there's no image content to
    // actually analyze without that API.
    if (imageUrl.trim().isEmpty) {
      return const ModerationResult(allowed: false, category: ModerationCategory.spam, reason: 'Please provide a valid photo.');
    }
    return ModerationResult.ok;
  }
}
