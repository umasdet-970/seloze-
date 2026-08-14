import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../discover/providers/discover_providers.dart';
import '../providers/settings_providers.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);
    final uid = ref.read(currentUserIdProvider);
    final repo = ref.read(settingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Show online status'),
            subtitle: const Text('Let matches see when you were last active'),
            value: settings.showOnlineStatus,
            onChanged: (v) => repo.savePrivacySettings(uid, settings.copyWith(showOnlineStatus: v)),
          ),
          SwitchListTile(
            title: const Text('Show distance'),
            subtitle: const Text('Show your distance on your profile card'),
            value: settings.showDistance,
            onChanged: (v) => repo.savePrivacySettings(uid, settings.copyWith(showDistance: v)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Profile visibility (whether you appear in Discover at all) is set in Edit Profile → Location & preferences.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
