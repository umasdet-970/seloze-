import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../discover/providers/discover_providers.dart';
import '../providers/settings_providers.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final uid = ref.read(currentUserIdProvider);
    final repo = ref.read(settingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('New likes'),
            subtitle: const Text('When someone likes your profile'),
            value: prefs.newLikes,
            onChanged: (v) => repo.saveNotificationPreferences(uid, prefs.copyWith(newLikes: v)),
          ),
          SwitchListTile(
            title: const Text('Matches'),
            subtitle: const Text('When you get a mutual match'),
            value: prefs.matches,
            onChanged: (v) => repo.saveNotificationPreferences(uid, prefs.copyWith(matches: v)),
          ),
          SwitchListTile(
            title: const Text('Messages'),
            subtitle: const Text('New chat messages'),
            value: prefs.messages,
            onChanged: (v) => repo.saveNotificationPreferences(uid, prefs.copyWith(messages: v)),
          ),
          SwitchListTile(
            title: const Text('Promotional'),
            subtitle: const Text('Reminders, tips, and product news'),
            value: prefs.promotional,
            onChanged: (v) => repo.saveNotificationPreferences(uid, prefs.copyWith(promotional: v)),
          ),
        ],
      ),
    );
  }
}
