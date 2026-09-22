import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/report_sheet.dart';
import '../../../shared/widgets/shimmer_placeholders.dart';
import '../../chat/providers/chat_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../providers/matches_providers.dart';

/// First-move urgency (spec: Bumble-style — see
/// functions/src/matchExpiry.ts): how long until this match expires if
/// neither side has said anything yet. Null once it's already expired-ish
/// (shouldn't normally be seen — the sweep runs hourly) or has messages.
const _matchExpiryHours = 24;

/// Matches screen (spec section 6): mutual matches with Unmatch / Block /
/// Report per match. Tapping opens Chat (built in the next roadmap phase).
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matches', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('People you and you both liked', style: TextStyle(color: onSurfaceVariant)),
            const SizedBox(height: 20),
            Expanded(
              child: matchesAsync.when(
                data: (matches) {
                  if (matches.isEmpty) {
                    return Center(
                      child: Text('No matches yet — keep swiping in Discover!', style: TextStyle(color: onSurfaceVariant)),
                    );
                  }
                  return ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      final profile = match.profile;
                      final uid = ref.read(currentUserIdProvider);
                      final conversationId = ref.read(chatRepositoryProvider).conversationId(uid, profile.id);
                      return Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => context.push('/chat/$conversationId', extra: profile),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey.shade300),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text('${profile.name}, ${profile.age}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          if (profile.isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified, color: AppColors.primary, size: 16),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Matched ${_relativeTime(match.matchedAt)}',
                                          style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
                                      Consumer(
                                        builder: (context, ref, _) {
                                          final hasMessages = ref.watch(chatMessagesProvider(conversationId)).isNotEmpty;
                                          final hoursLeft = _matchExpiryHours -
                                              DateTime.now().difference(match.matchedAt).inHours;
                                          if (hasMessages || hoursLeft <= 0) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Say hi within ${hoursLeft}h or this match expires',
                                              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) => _handleAction(context, ref, action, profile.id, profile.name),
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'unmatch', child: Text('Unmatch')),
                                    PopupMenuItem(value: 'block', child: Text('Block')),
                                    PopupMenuItem(value: 'report', child: Text('Report')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.separated(
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => const ShimmerListTile(),
                ),
                error: (err, _) => Center(child: Text('Something went wrong: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action, String targetId, String targetName) async {
    final uid = ref.read(currentUserIdProvider);
    final social = ref.read(socialRepositoryProvider);

    try {
      switch (action) {
        case 'unmatch':
          final confirmed = await _confirm(context, 'Unmatch $targetName?', 'You can still match again later if you both like each other.');
          if (confirmed == true) {
            HapticFeedback.mediumImpact();
            await social.unmatch(uid, targetId);
          }
          break;
        case 'block':
          final confirmed = await _confirm(context, 'Block $targetName?', 'They will disappear from your Discover and this match will be removed.');
          if (confirmed == true) {
            HapticFeedback.mediumImpact();
            await social.block(uid, targetId);
          }
          break;
        case 'report':
          // showReportSheet has its own try/catch around onSubmit.
          await showReportSheet(
            context,
            targetName: targetName,
            onSubmit: (reason, details) => social.report(uid, targetId, reason: reason, details: details),
          );
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<bool?> _confirm(BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
