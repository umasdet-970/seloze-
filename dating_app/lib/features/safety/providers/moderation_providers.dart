import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/repositories/firebase/cloud_moderation_repository.dart';
import '../../../data/repositories/moderation_repository.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return kUseCloudModeration ? CloudModerationRepository() : MockModerationRepository();
});
