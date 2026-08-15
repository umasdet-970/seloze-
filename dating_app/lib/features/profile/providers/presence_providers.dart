import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/repositories/firebase/presence_service.dart';
import '../../discover/providers/discover_providers.dart';

final _presenceService = PresenceService();

/// Starts the presence heartbeat as soon as a user is signed in. Watched
/// once, app-wide, from main.dart — same pattern as pushRegistrarProvider
/// in notification_providers.dart. See PresenceService for what this does
/// and doesn't cover.
final presenceRegistrarProvider = Provider<void>((ref) {
  if (!kUseFirebase) return;
  final uid = ref.watch(currentUserIdProvider);
  if (uid.isNotEmpty) {
    _presenceService.start(uid);
  } else {
    _presenceService.stop();
  }
});
