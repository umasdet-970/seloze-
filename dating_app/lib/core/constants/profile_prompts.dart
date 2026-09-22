/// Curated prompt questions (Hinge-style) — a member picks up to
/// [kMaxProfilePrompts] of these and answers each in their own words.
/// Optional and additive to the plain bio, not a replacement for it:
/// prompts give matches a specific, concrete thing to reply to instead of
/// a generic "hey" — the reason Hinge built its whole profile around them.
const List<String> kProfilePromptQuestions = [
  'A perfect first date looks like...',
  "I'm known for...",
  'My most controversial opinion is...',
  'Two truths and a lie...',
  'The way to win me over is...',
  'My simple pleasures...',
  'A typical Sunday for me...',
  "I'll fall for you if...",
  'Green flags I look for...',
  'Together, we could...',
  'The key to my heart is...',
  "Let's debate this topic...",
];

const int kMaxProfilePrompts = 3;
