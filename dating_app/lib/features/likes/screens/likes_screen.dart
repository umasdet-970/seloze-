import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/subscription_models.dart';
import '../../../shared/widgets/shimmer_placeholders.dart';
import '../../discover/providers/discover_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/likes_providers.dart';

/// "Who liked you" (spec section 5). Free users get a blurred teaser with
/// an upgrade CTA; Premium users can like back directly (an instant
/// match, since these people already liked the current user).
class LikesScreen extends ConsumerWidget {
  const LikesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesAsync = ref.watch(receivedLikesProvider);
    final tier = ref.watch(subscriptionTierProvider);
    final isPremium = tier == SubscriptionTier.premium;
    final roseSenderIds = ref.watch(roseSenderIdsProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Likes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('People who liked your profile', style: TextStyle(color: onSurfaceVariant)),
            const SizedBox(height: 20),
            Expanded(
              child: likesAsync.when(
                data: (profiles) {
                  if (profiles.isEmpty) {
                    return Center(
                      child: Text('No likes yet — keep swiping in Discover!', style: TextStyle(color: onSurfaceVariant)),
                    );
                  }

                  // Roses always reveal the sender, even to a Free viewer —
                  // that's the whole point of spending one (see
                  // core/config/rose_config.dart) — so they're excluded
                  // from the blurred/locked section below.
                  final roseSenders = profiles.where((p) => roseSenderIds.contains(p.id)).toList();
                  final others = profiles.where((p) => !roseSenderIds.contains(p.id)).toList();

                  Widget tileGrid(List<Profile> list, {required bool interactive}) => GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) => _LikeTile(
                          profile: list[index],
                          interactive: interactive,
                          isRose: roseSenderIds.contains(list[index].id),
                        ),
                      );

                  // Premium sees everyone clearly, full stop — no
                  // separate Rose section needed since nothing's blurred.
                  if (isPremium) return tileGrid(profiles, interactive: true);

                  return ListView(
                    children: [
                      if (roseSenders.isNotEmpty) ...[
                        const _RoseSectionHeader(),
                        tileGrid(roseSenders, interactive: true),
                        if (others.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text('Everyone else', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 12),
                        ],
                      ],
                      if (others.isNotEmpty)
                        Stack(
                          children: [
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: tileGrid(others, interactive: false),
                            ),
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.center,
                                color: Colors.black.withValues(alpha: 0.15),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_outline, size: 32, color: AppColors.primary),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${others.length} more ${others.length == 1 ? 'person likes' : 'people like'} you',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Upgrade to Premium to see who and match instantly.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: () => context.push('/paywall'),
                                          child: const Text('Upgrade to Premium'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
                loading: () => GridView.builder(
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (_, __) => const ShimmerGridTile(),
                ),
                error: (err, _) => Center(child: Text('Something went wrong: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoseSectionHeader extends StatelessWidget {
  const _RoseSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.local_florist, color: Colors.pink, size: 20),
          SizedBox(width: 6),
          Text('Sent you a Rose', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _LikeTile extends ConsumerStatefulWidget {
  final Profile profile;
  final bool interactive;
  final bool isRose;
  const _LikeTile({required this.profile, required this.interactive, this.isRose = false});

  @override
  ConsumerState<_LikeTile> createState() => _LikeTileState();
}

class _LikeTileState extends ConsumerState<_LikeTile> {
  bool _busy = false;

  Future<void> _likeBack() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final uid = ref.read(currentUserIdProvider);
    final result = await ref.read(socialRepositoryProvider).like(uid, widget.profile.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.matched) {
      HapticFeedback.heavyImpact();
      ref.read(notificationRepositoryProvider).add(
            uid,
            NotificationType.mutualMatch,
            "It's a match! 🎉",
            'You and ${widget.profile.name} liked each other. Say hi!',
          );
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("It's a Match! 🎉"),
          content: Text('You and ${widget.profile.name} liked each other.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Nice!'))],
        ),
      );
    }
  }

  Future<void> _pass() async {
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    await ref.read(socialRepositoryProvider).pass(ref.read(currentUserIdProvider), widget.profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${profile.name}, ${profile.age}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  if (widget.interactive) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _miniButton(icon: Icons.close, color: Colors.white, onTap: _busy ? null : _pass),
                        _miniButton(icon: Icons.favorite, color: AppColors.like, onTap: _busy ? null : _likeBack),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.isRose)
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.local_florist, color: Colors.pink, size: 20, shadows: [Shadow(blurRadius: 4)]),
            ),
        ],
      ),
    );
  }

  Widget _miniButton({required IconData icon, required Color color, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
