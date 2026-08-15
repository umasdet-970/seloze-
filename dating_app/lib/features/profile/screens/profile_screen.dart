import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/subscription_models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../../subscription/providers/subscription_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final profile = ref.watch(myProfileProvider).valueOrNull;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile & Settings',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? user?.phoneNumber ?? 'Signed in',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (profile != null) _ProfileSummaryCard(profile: profile),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/edit-profile'),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit profile'),
            ),
          ),
          const SizedBox(height: 8),
          _VerificationCard(isVerified: profile?.isVerified ?? false),
          const SizedBox(height: 16),
          const _SubscriptionCard(),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final Profile profile;

  const _ProfileSummaryCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: profile.photoUrls.isNotEmpty
                ? Image.network(profile.photoUrls.first, width: 64, height: 64, fit: BoxFit.cover)
                : Container(width: 64, height: 64, color: Colors.grey.shade300, child: const Icon(Icons.person)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('${profile.name}, ${profile.age}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.primary, size: 18),
                    ],
                  ],
                ),
                if (profile.city.isNotEmpty)
                  Text(profile.city, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends ConsumerStatefulWidget {
  final bool isVerified;
  const _VerificationCard({required this.isVerified});

  @override
  ConsumerState<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends ConsumerState<_VerificationCard> {
  bool _requesting = false;

  Future<void> _requestVerification() async {
    setState(() => _requesting = true);
    final uid = ref.read(currentUserIdProvider);
    await ref.read(userProfileRepositoryProvider).requestVerification(uid);
    HapticFeedback.mediumImpact();
    ref.read(notificationRepositoryProvider).add(
          uid,
          NotificationType.profileVerification,
          "You're verified! ✅",
          'Your verified badge is now visible to other members.',
        );
    if (mounted) setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            widget.isVerified ? Icons.verified : Icons.shield_outlined,
            color: widget.isVerified ? AppColors.success : onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isVerified ? 'Profile verified' : 'Not verified yet',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.isVerified
                      ? 'Your verified badge is visible to other members.'
                      : 'Verify your photos to get a badge and build trust.',
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!widget.isVerified)
            _requesting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _requestVerification, child: const Text('Verify')),
        ],
      ),
    );
  }
}

/// Subscription management (spec section 14).
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(subscriptionRecordProvider);
    final tier = record.tier;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            tier == SubscriptionTier.premium ? Icons.workspace_premium : Icons.card_membership_outlined,
            color: tier == SubscriptionTier.premium ? AppColors.primary : onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.isActive ? record.plan!.title : 'Free plan',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  record.isActive
                      ? (record.autoRenew ? 'Renews automatically' : 'Auto-renew off')
                      : '10 discoveries/day, chat locked, ads shown',
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/paywall'),
            child: Text(record.isActive ? 'Manage' : 'Upgrade'),
          ),
        ],
      ),
    );
  }
}
