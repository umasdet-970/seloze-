import '../models/moderation_models.dart';

/// Content moderation (spec sections 12, 19: profile text moderation,
/// message safety checks, spam/contact-sharing detection). This is
/// rule-based — a real deployment swaps this for a hosted AI moderation
/// API (e.g. Cloud Vision SafeSearch for photos, Perspective API or a
/// custom classifier for text) behind the same interface.
abstract class ModerationRepository {
  Future<ModerationResult> moderateText(String text);
  Future<ModerationResult> moderatePhoto(String imageUrl);
}

class MockModerationRepository implements ModerationRepository {
  // Small placeholder list — a real deployment needs a maintained,
  // multi-language provider list, not a hardcoded array.
  static const _harassmentWords = ['idiot', 'stupid', 'shut up', 'hate you'];

  static final _spamPatterns = [
    RegExp(r'\bwhatsapp\b', caseSensitive: false),
    RegExp(r'\btelegram\b', caseSensitive: false),
    RegExp(r'\bonlyfans\b', caseSensitive: false),
    RegExp(r'\b(cashapp|venmo|bitcoin|crypto)\b', caseSensitive: false),
    RegExp(r'https?://\S+'),
  ];

  static final _phonePattern = RegExp(r'(\+?\d[\d\s-]{8,}\d)');
  static final _emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}');

  @override
  Future<ModerationResult> moderateText(String text) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final lower = text.toLowerCase();

    for (final word in _harassmentWords) {
      if (lower.contains(word)) {
        return const ModerationResult(
          allowed: false,
          category: ModerationCategory.harassment,
          reason: 'This contains language that violates our community guidelines.',
        );
      }
    }

    if (_phonePattern.hasMatch(text) || _emailPattern.hasMatch(text)) {
      return const ModerationResult(
        allowed: false,
        category: ModerationCategory.contactInfoSharing,
        reason: "For your safety, don't share phone numbers or emails here.",
      );
    }

    for (final pattern in _spamPatterns) {
      if (pattern.hasMatch(text)) {
        return const ModerationResult(
          allowed: false,
          category: ModerationCategory.spam,
          reason: 'This looks like spam or an off-platform contact request.',
        );
      }
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
