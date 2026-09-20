import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/ad_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/subscription_models.dart';
import '../../../shared/widgets/ad_banner.dart';
import '../../../shared/widgets/report_sheet.dart';
import '../../../shared/widgets/shimmer_placeholders.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/discover_providers.dart';
import '../widgets/action_buttons.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/profile_card.dart';
import '../widgets/profile_details_sheet.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final CardSwiperController _swiperController = CardSwiperController();

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(discoverFeedProvider);
    final selectedTab = ref.watch(discoverTabProvider);
    final (used, limit) = ref.watch(discoveryQuotaProvider);
    final tier = ref.watch(subscriptionTierProvider);

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context, used, limit, tier),
          const SizedBox(height: 12),
          _buildTabChips(context, selectedTab),
          if (kUseAds && tier == SubscriptionTier.free) ...[
            const SizedBox(height: 12),
            _AdPlaceholder(onUpgrade: () => context.push('/paywall')),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: feedAsync.when(
              data: (profiles) {
                if (profiles.isEmpty) {
                  final limitReached = used >= limit;
                  return _EmptyState(
                    limitReached: limitReached,
                    onRefresh: () => ref.read(discoverFeedProvider.notifier).refresh(),
                    onUpgrade: () => context.push('/paywall'),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: profiles.length,
                    numberOfCardsDisplayed: profiles.length < 3 ? profiles.length : 3,
                    backCardOffset: const Offset(0, 24),
                    padding: EdgeInsets.zero,
                    onSwipe: (previousIndex, currentIndex, direction) {
                      _handleSwipe(direction, profiles[previousIndex]);
                      return true;
                    },
                    cardBuilder: (context, index, percentX, percentY) {
                      final profile = profiles[index];
                      return ProfileCard(
                        profile: profile,
                        onInfoTap: () => showProfileDetailsSheet(context, profile),
                        onMenuTap: () => _showCardMenu(profile.id, profile.name),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ShimmerCard(),
              ),
              error: (err, _) => Center(child: Text('Something went wrong: $err')),
            ),
          ),
          const SizedBox(height: 16),
          ActionButtons(
            onPass: () => _swiperController.swipe(CardSwiperDirection.left),
            onLike: () => _swiperController.swipe(CardSwiperDirection.right),
            onSuperLike: () => _swiperController.swipe(CardSwiperDirection.top),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _handleSwipe(CardSwiperDirection direction, Profile profile) async {
    final notifier = ref.read(discoverFeedProvider.notifier);
    try {
      if (direction == CardSwiperDirection.right || direction == CardSwiperDirection.top) {
        HapticFeedback.mediumImpact();
        final matched = await notifier.likeTop();
        if (matched && mounted) {
          HapticFeedback.heavyImpact();
          _showMatchDialog(profile.name);
        }
      } else if (direction == CardSwiperDirection.left) {
        HapticFeedback.lightImpact();
        await notifier.passTop();
      }
    } catch (e) {
      // Surfaces the swipe-rate limiter's message (bot-detection guard —
      // spec section 12/19) instead of letting it fall through as an
      // uncaught async error.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCardMenu(String targetId, String targetName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('Report profile'),
              onTap: () {
                Navigator.pop(sheetContext);
                showReportSheet(
                  context,
                  targetName: targetName,
                  onSubmit: (reason, details) => ref
                      .read(socialRepositoryProvider)
                      .report(ref.read(currentUserIdProvider), targetId, reason: reason, details: details),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text('Block $targetName'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await ref.read(socialRepositoryProvider).block(ref.read(currentUserIdProvider), targetId);
                  await ref.read(discoverFeedProvider.notifier).refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$targetName is blocked.')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMatchDialog(String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("It's a Match! 🎉"),
        content: Text('You and $name liked each other.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Swiping')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Say Hi')),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int used, int limit, SubscriptionTier tier) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.menu), onPressed: () => context.push('/settings')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Discover', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(
                  '$used of $limit discoveries used today',
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Chip(
              label: Text(tier == SubscriptionTier.premium
                  ? 'Premium'
                  : tier == SubscriptionTier.adFree
                      ? 'Ad-Free'
                      : 'Free'),
              backgroundColor: tier == SubscriptionTier.premium ? AppColors.primary.withValues(alpha: 0.15) : null,
              labelStyle: TextStyle(
                fontSize: 11,
                color: tier == SubscriptionTier.premium ? AppColors.primary : onSurfaceVariant,
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final hasFilters =
                  ref.watch(discoverFiltersProvider).differsFrom(ref.watch(discoverBaseFiltersProvider));
              return IconButton(
                icon: Badge(
                  isLabelVisible: hasFilters,
                  smallSize: 8,
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => showFilterSheet(context),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationCountProvider);
              return IconButton(
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => context.push('/notifications'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabChips(BuildContext context, DiscoverTab selected) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = {
      DiscoverTab.forYou: ('For You', Icons.favorite),
      DiscoverTab.nearby: ('Nearby', Icons.location_on_outlined),
      DiscoverTab.newProfiles: ('New', Icons.bolt),
      DiscoverTab.online: ('Online', Icons.circle),
    };

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: tabs.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value.$1),
              avatar: Icon(entry.value.$2, size: 16,
                  color: isSelected ? Colors.white : colorScheme.onSurfaceVariant),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                ref.read(discoverTabProvider.notifier).state = entry.key;
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : colorScheme.onSurface),
              backgroundColor: colorScheme.surface,
              shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade200)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Stand-in for a real ad SDK (e.g. AdMob) — spec sections 4/18: ads
/// display for Free users only — real ad SDK (see AdBanner/ad_config.dart),
/// not a placeholder. "Remove ads" stays visible regardless of whether an
/// ad actually loaded, since that CTA shouldn't depend on ad-network luck.
class _AdPlaceholder extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _AdPlaceholder({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const AdBanner(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onUpgrade, child: const Text('Remove ads', style: TextStyle(fontSize: 12))),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool limitReached;
  final VoidCallback onRefresh;
  final VoidCallback onUpgrade;
  const _EmptyState({required this.limitReached, required this.onRefresh, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(limitReached ? Icons.lock_clock_outlined : Icons.search_off, size: 64, color: onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              limitReached ? "You've hit today's discovery limit" : "You're all caught up!",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              limitReached
                  ? 'Upgrade to Premium for 50 discoveries a day, or come back tomorrow.'
                  : 'Check back later for new profiles.',
              style: TextStyle(color: onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: limitReached ? onUpgrade : onRefresh,
              child: Text(limitReached ? 'Upgrade to Premium' : 'Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
