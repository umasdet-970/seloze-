import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/referral_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../providers/referral_providers.dart';

/// Shares [uid]'s personal invite link. Used by the Profile card and by the
/// "daily limit reached" prompt on Discover — the moment someone most wants
/// more discoveries.
Future<void> shareInvite(WidgetRef ref) async {
  var uid = ref.read(currentUserIdProvider);
  if (uid.isEmpty) {
    // Auth state hasn't resolved yet — wait for it rather than silently
    // doing nothing when the button is tapped.
    uid = (await ref.read(authStateChangesProvider.future))?.uid ?? '';
  }
  if (uid.isEmpty) return;
  // Analytics must never be able to block sharing.
  try {
    ref.read(analyticsRepositoryProvider).logEvent('invite_shared');
  } catch (_) {}
  await ref.read(inviteSharerProvider)(
    "I'm on Seloze — meet people near you. Join with my link: ${buildInviteLink(uid)}",
  );
}

/// "Invite friends, get more daily discoveries" — the invite-a-friend growth
/// loop. Shows progress so people can see what each friend is worth.
class InviteFriendsCard extends ConsumerWidget {
  const InviteFriendsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(referralCountProvider).valueOrNull ?? 0;
    final bonus = ref.watch(referralBonusProvider);
    final counted = joined.clamp(0, kMaxRewardedFriends);
    final maxed = joined >= kMaxRewardedFriends;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text('Invite friends, get more discoveries', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '+$kBonusDiscoveriesPerFriend discoveries a day for each friend who joins and completes their '
            'profile (up to $kMaxRewardedFriends friends).',
            style: TextStyle(color: onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: counted / kMaxRewardedFriends, minHeight: 6),
          ),
          const SizedBox(height: 6),
          Text(
            maxed
                ? 'All $kMaxRewardedFriends friends joined · +$bonus discoveries a day unlocked'
                : '$counted of $kMaxRewardedFriends friends joined · +$bonus a day so far',
            style: TextStyle(color: onSurfaceVariant, fontSize: 12),
          ),
          if (!maxed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => shareInvite(ref),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Invite friends'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
