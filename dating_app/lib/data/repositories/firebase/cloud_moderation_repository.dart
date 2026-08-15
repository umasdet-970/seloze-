import 'package:cloud_functions/cloud_functions.dart';

import '../../models/moderation_models.dart';
import '../moderation_repository.dart';

/// Calls the `moderateImage`/`moderateText` Cloud Functions (Cloud Vision
/// SafeSearch / Cloud Natural Language — see functions/src/moderation.ts)
/// instead of running the rule-based checks locally.
///
/// Falls back to [MockModerationRepository]'s rule-based checks — not to
/// "allow everything" — if the callable throws for any reason (functions
/// not deployed yet, network error, cold-start timeout). A moderation
/// gate that fails open on every transient error defeats its own
/// purpose; falling back to the still-reasonable rule-based check gives
/// defense in depth instead.
class CloudModerationRepository implements ModerationRepository {
  CloudModerationRepository({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final _fallback = MockModerationRepository();

  ModerationCategory _categoryFromName(Object? name) {
    return ModerationCategory.values.firstWhere((c) => c.name == name, orElse: () => ModerationCategory.none);
  }

  @override
  Future<ModerationResult> moderateText(String text) async {
    try {
      final result = await _functions.httpsCallable('moderateText').call({'text': text});
      // Callable results come back as an untyped Map (Object?, Object?)
      // over the platform channel — `Map<String, dynamic>.from(...)` is
      // the safe way to work with it, not a generic type param on call().
      final data = Map<String, dynamic>.from(result.data as Map);
      return ModerationResult(
        allowed: data['allowed'] as bool,
        category: _categoryFromName(data['category']),
        reason: data['reason'] as String?,
      );
    } catch (_) {
      return _fallback.moderateText(text);
    }
  }

  @override
  Future<ModerationResult> moderatePhoto(String imageUrl) async {
    try {
      final result = await _functions.httpsCallable('moderateImage').call({'imageUrl': imageUrl});
      final data = Map<String, dynamic>.from(result.data as Map);
      return ModerationResult(
        allowed: data['allowed'] as bool,
        category: _categoryFromName(data['category']),
        reason: data['reason'] as String?,
      );
    } catch (_) {
      return _fallback.moderatePhoto(imageUrl);
    }
  }
}
