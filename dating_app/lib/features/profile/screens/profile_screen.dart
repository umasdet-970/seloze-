import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/ad_config.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/config/wallet_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/subscription_models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../../referrals/widgets/invite_friends_card.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../../wallet/providers/wallet_providers.dart';

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
          const SizedBox(height: 16),
          _BoostCard(profile: profile),
          const SizedBox(height: 16),
          const _WalletCard(),
          const SizedBox(height: 16),
          const InviteFriendsCard(),
        ],
      ),
    );
  }
}

/// `Profile.photoUrls` holds a plain HTTPS URL once uploaded to Firebase
/// Storage, but can also hold a local device file path when no cloud
/// backend is configured (kUseFirebase off — see
/// CreateProfileScreen._pickPhoto, where the photo itself is always
/// real, just not always uploaded). `Image.network` throws ("No host
/// specified") on a local path, so this picks the right widget for
/// whichever kind of value is actually there.
Widget _ownPhotoThumbnail(List<String> photoUrls) {
  if (photoUrls.isEmpty) {
    return Container(width: 64, height: 64, color: Colors.grey.shade300, child: const Icon(Icons.person));
  }
  final first = photoUrls.first;
  final isRemoteUrl = first.startsWith('http://') || first.startsWith('https://');
  return isRemoteUrl
      ? Image.network(first, width: 64, height: 64, fit: BoxFit.cover)
      : Image.file(File(first), width: 64, height: 64, fit: BoxFit.cover);
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
            child: _ownPhotoThumbnail(profile.photoUrls),
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
  bool _requested = false;

  Future<void> _requestVerification() async {
    setState(() => _requesting = true);
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(userProfileRepositoryProvider).requestVerification(uid);
    } catch (e) {
      if (mounted) {
        setState(() => _requesting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    HapticFeedback.mediumImpact();
    // Only the in-memory mock approves instantly. The real backend just
    // records that a review was requested — telling the user "You're
    // verified" (and pushing that to their phone) before anyone has
    // reviewed anything was false.
    ref.read(notificationRepositoryProvider).add(
          uid,
          NotificationType.profileVerification,
          kUseFirebase ? 'Verification requested' : "You're verified! ✅",
          kUseFirebase
              ? "Thanks — we'll review your photos and let you know once it's done."
              : 'Your verified badge is now visible to other members.',
        );
    if (mounted) {
      setState(() {
        _requesting = false;
        _requested = kUseFirebase;
      });
    }
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
                  widget.isVerified
                      ? 'Profile verified'
                      : (_requested ? 'Verification requested' : 'Not verified yet'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.isVerified
                      ? 'Your verified badge is visible to other members.'
                      : (_requested
                          ? "We'll let you know once your photos are reviewed."
                          : 'Verify your photos to get a badge and build trust.'),
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!widget.isVerified && !_requested)
            _requesting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _requestVerification, child: const Text('Verify')),
        ],
      ),
    );
  }
}

/// Premium's "Boost" — 30 minutes at the front of other users' Discover
/// queue (Profile.isBoosted, applied in discover_providers.dart's
/// "For You" ordering). Shown to everyone (advertise-then-upsell, same as
/// the Rewind button) — Free members see an upgrade prompt instead of a
/// working button.
class _BoostCard extends ConsumerStatefulWidget {
  final Profile? profile;
  const _BoostCard({required this.profile});

  @override
  ConsumerState<_BoostCard> createState() => _BoostCardState();
}

class _BoostCardState extends ConsumerState<_BoostCard> {
  static const _boostDuration = Duration(minutes: 30);
  bool _activating = false;

  Future<void> _activate({bool spendCoins = false}) async {
    setState(() => _activating = true);
    HapticFeedback.mediumImpact();
    final uid = ref.read(currentUserIdProvider);
    try {
      // Debit before activating (not after) — if the balance is
      // insufficient this throws and no boost is ever granted.
      if (spendCoins) {
        await ref.read(walletRepositoryProvider).debit(uid, kBoostCostCoins, reason: 'boost');
      }
      await ref.read(userProfileRepositoryProvider).activateBoost(uid, duration: _boostDuration);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("You're boosted for the next 30 minutes 🚀")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  String _formatTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(subscriptionTierProvider);
    final isPremium = tier == SubscriptionTier.premium;
    final isBoosted = widget.profile?.isBoosted ?? false;
    final coins = ref.watch(coinBalanceProvider);
    final canAffordCoins = coins >= kBoostCostCoins;
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
          Icon(Icons.rocket_launch, color: isBoosted ? AppColors.primary : onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBoosted ? "You're boosted" : 'Boost',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  isBoosted
                      ? 'Front of the queue until ${_formatTime(widget.profile!.boostedUntil!)}'
                      : (isPremium
                          ? 'Be seen first in Discover for 30 minutes.'
                          : 'Premium members can jump the queue for 30 minutes.'),
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_activating)
            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (isBoosted)
            const SizedBox.shrink()
          else if (isPremium)
            TextButton(onPressed: () => _activate(), child: const Text('Boost now'))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => context.push('/paywall'), child: const Text('Upgrade')),
                if (canAffordCoins)
                  TextButton(
                    onPressed: () => _activate(spendCoins: true),
                    child: const Text('$kBoostCostCoins coins', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Coins/credits economy (spec: Badoo-style Superpowers — see
/// core/config/wallet_config.dart). Earned via the welcome credit and
/// invites (kUseRevenueCat is off, so there's no real purchase path yet —
/// "Get more" explains where coins actually come from right now instead
/// of pretending a buy flow exists).
class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(coinBalanceProvider);
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
          const Icon(Icons.monetization_on, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$coins coins', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Spend on Boost ($kBoostCostCoins) or Roses ($kRoseCostCoins) without Premium.',
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => const _GetMoreCoinsSheet(),
            ),
            child: const Text('Get more'),
          ),
        ],
      ),
    );
  }
}

class _GetMoreCoinsSheet extends StatelessWidget {
  const _GetMoreCoinsSheet();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Get more coins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.group_add, color: AppColors.primary),
              title: Text('Invite friends'),
              subtitle: Text('+$kCoinsPerReferral coins per friend who joins'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.card_giftcard, color: AppColors.primary),
              title: Text('Welcome bonus'),
              subtitle: Text('$kWelcomeCoins coins when you completed your profile'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shopping_cart_outlined, color: AppColors.textMuted),
              title: Text('Buy coins'),
              subtitle: Text("Coming soon — we'll let you know when it's live"),
              enabled: false,
            ),
            SizedBox(height: 8),
          ],
        ),
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
                      : [
                          '10 discoveries/day',
                          // Only true when real billing exists (see chatUnlockedProvider) / ads are on.
                          if (kUseRevenueCat) 'chat locked',
                          if (kUseAds) 'ads shown',
                        ].join(', '),
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
