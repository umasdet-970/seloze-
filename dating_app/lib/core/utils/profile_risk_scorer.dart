import '../../data/models/profile.dart';
import '../../data/models/profile_risk.dart';
import 'spam_signals.dart';

/// Heuristic fake-profile / suspicious-profile detection (spec section 3:
/// "Suspicious-profile detection"; section 12/19: "Fake-profile
/// detection", "Bot detection", "Automated moderation alerts"). Runs once
/// when a profile is saved — see `FirestoreUserProfileRepository.saveProfile`
/// — and the result is persisted for the admin dashboard's flagged-profiles
/// queue to read directly, rather than rescored on every admin page load.
///
/// This is rule-based, same honesty note as `ModerationRepository`: a
/// real deployment would want a hosted classifier (duplicate-photo
/// detection via perceptual hashing, a trained fake-profile model, etc.)
/// behind the same `assess()` signature. These heuristics catch the
/// cheap, common cases — single stock-photo-style profile, spam links in
/// the bio, bot-like generated usernames — not a sophisticated fake.
class ProfileRiskScorer {
  static ProfileRiskAssessment assess(Profile profile) {
    final signals = <String>[];
    var score = 0;

    if (profile.photoUrls.length <= 1) {
      score += 15;
      signals.add('Only one photo');
    }

    final bio = profile.bio.trim();
    if (bio.isEmpty) {
      score += 20;
      signals.add('Empty bio');
    } else if (bio.length < 10) {
      score += 12;
      signals.add('Very short bio');
    }

    if (bio.isNotEmpty && containsSpamPattern(bio)) {
      score += 30;
      signals.add('Bio contains a spam/off-platform link or keyword');
    }

    if (bio.isNotEmpty && containsContactInfo(bio)) {
      score += 25;
      signals.add('Bio contains a phone number or email');
    }

    // Generic bot-style handle: letters followed by 3+ digits (e.g.
    // "user4821", "priya9273") — real users overwhelmingly pick a plain
    // first name. Flags, doesn't block — plenty of real people do this
    // too, it's just a signal worth an admin's second look.
    if (RegExp(r'^[a-zA-Z]+\d{3,}$').hasMatch(profile.name.trim())) {
      score += 20;
      signals.add('Name looks auto-generated');
    }

    if (profile.name.trim().isNotEmpty && profile.name.trim() == profile.name.trim().toUpperCase() && profile.name.trim().length > 3) {
      score += 8;
      signals.add('Name is all caps');
    }

    if (profile.bio.isNotEmpty && bio == bio.toUpperCase() && bio.length > 10) {
      score += 8;
      signals.add('Bio is all caps');
    }

    if (profile.age < 18 || profile.age > 100) {
      score += 40;
      signals.add('Implausible age');
    }

    score = score.clamp(0, 100);
    return ProfileRiskAssessment(score: score, level: RiskLevelInfo.fromScore(score), signals: signals);
  }
}
