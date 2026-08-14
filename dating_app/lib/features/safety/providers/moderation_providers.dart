import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/moderation_repository.dart';

/// Swap MockModerationRepository() -> a hosted AI moderation API client
/// once one is integrated (roadmap: AI/automation phase).
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) => MockModerationRepository());
