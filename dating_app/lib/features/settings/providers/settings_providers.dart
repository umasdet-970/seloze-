import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/models/settings_models.dart';
import '../../../data/repositories/firebase/firestore_settings_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../discover/providers/discover_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return kUseFirebase ? FirestoreSettingsRepository() : MockSettingsRepository();
});

final _settingsTickProvider = StreamProvider<void>((ref) {
  return ref.watch(settingsRepositoryProvider).changes();
});

final notificationPreferencesProvider = Provider<NotificationPreferences>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(settingsRepositoryProvider);
  ref.watch(_settingsTickProvider);
  return uid.isEmpty ? const NotificationPreferences() : repo.notificationPreferences(uid);
});

final privacySettingsProvider = Provider<PrivacySettings>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(settingsRepositoryProvider);
  ref.watch(_settingsTickProvider);
  return uid.isEmpty ? const PrivacySettings() : repo.privacySettings(uid);
});
