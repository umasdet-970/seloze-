import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/subscription_models.dart';
import '../../discover/providers/discover_providers.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/settings_providers.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);
    final uid = ref.read(currentUserIdProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final isPremium = ref.watch(subscriptionTierProvider) == SubscriptionTier.premium;
    final incognito = ref.watch(myProfileProvider).valueOrNull?.incognito ?? false;

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
          SwitchListTile(
            title: Row(
              children: [
                const Text('Incognito mode'),
                if (!isPremium) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.workspace_premium, size: 16, color: Colors.amber),
                ],
              ],
            ),
            subtitle: Text(
              isPremium
                  ? "Browse Discover without appearing in anyone's feed, unless they already liked you"
                  : 'Premium members can browse without appearing in Discover',
            ),
            value: isPremium && incognito,
            onChanged: !isPremium
                ? (_) => context.push('/paywall')
                : (v) => ref.read(userProfileRepositoryProvider).setIncognito(uid, v),
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
