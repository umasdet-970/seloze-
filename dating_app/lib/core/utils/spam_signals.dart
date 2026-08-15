/// Shared regex signals for spam/contact-sharing/harassment detection —
/// used by both [ModerationRepository] (blocks/rejects text as it's
/// typed) and [ProfileRiskScorer] (scores a saved profile for the admin
/// review queue). Kept in one place so the two don't drift out of sync.
///
/// Small placeholder lists — a real deployment needs maintained,
/// multi-language provider lists (and ideally a hosted classifier), not
/// hardcoded arrays. See moderation_repository.dart's doc comment.
library;

const harassmentWords = ['idiot', 'stupid', 'shut up', 'hate you'];

final spamPatterns = [
  RegExp(r'\bwhatsapp\b', caseSensitive: false),
  RegExp(r'\btelegram\b', caseSensitive: false),
  RegExp(r'\bonlyfans\b', caseSensitive: false),
  RegExp(r'\b(cashapp|venmo|bitcoin|crypto)\b', caseSensitive: false),
  RegExp(r'https?://\S+'),
];

final phonePattern = RegExp(r'(\+?\d[\d\s-]{8,}\d)');
final emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}');

bool containsSpamPattern(String text) => spamPatterns.any((p) => p.hasMatch(text));

bool containsContactInfo(String text) => phonePattern.hasMatch(text) || emailPattern.hasMatch(text);

bool containsHarassment(String text) {
  final lower = text.toLowerCase();
  return harassmentWords.any(lower.contains);
}
