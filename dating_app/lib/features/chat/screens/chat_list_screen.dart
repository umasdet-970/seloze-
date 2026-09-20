import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/report_sheet.dart';
import '../../../shared/widgets/shimmer_placeholders.dart';
import '../../discover/providers/discover_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/chat_providers.dart';

/// Chat list (spec section 7): locked entirely for Free users, unlimited
/// messaging for Premium.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(chatUnlockedProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Messages', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Chat with your matches', style: TextStyle(color: onSurfaceVariant)),
            const SizedBox(height: 20),
            Expanded(child: isPremium ? _ConversationList() : const _ChatLockedState()),
          ],
        ),
      ),
    );
  }
}

class _ChatLockedState extends StatelessWidget {
  const _ChatLockedState();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Chat is a Premium feature', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Upgrade to Premium for unlimited messaging with your matches.',
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/paywall'),
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Text('No matches yet — get swiping in Discover!', style: TextStyle(color: onSurfaceVariant)),
          );
        }
        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) => _ConversationTile(conversation: conversations[index]),
        );
      },
      loading: () => ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, __) => const ShimmerListTile(),
      ),
      error: (err, _) => Center(child: Text('Something went wrong: $err')),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationSummary conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = conversation.profile;
    final lastMessage = conversation.lastMessage;
    final hasUnread = conversation.unreadCount > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push('/chat/${conversation.conversationId}', extra: profile),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: CachedNetworkImage(
              imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey.shade300),
            ),
          ),
          if (profile.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(profile.name, style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600)),
      subtitle: Text(
        lastMessage == null
            ? "You matched — say hi!"
            : (lastMessage.isImage ? '📷 Photo' : lastMessage.text ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.like, borderRadius: BorderRadius.circular(12)),
              child: Text('${conversation.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'hide', child: Text('Hide conversation')),
              PopupMenuItem(value: 'block', child: Text('Block')),
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final uid = ref.read(currentUserIdProvider);
    final profile = conversation.profile;

    try {
      switch (action) {
        case 'hide':
          await ref.read(chatRepositoryProvider).hideConversation(conversation.conversationId, uid);
          break;
        case 'block':
          await ref.read(socialRepositoryProvider).block(uid, profile.id);
          break;
        case 'report':
          // showReportSheet has its own try/catch around onSubmit — not
          // duplicated here.
          await showReportSheet(
            context,
            targetName: profile.name,
            onSubmit: (reason, details) =>
                ref.read(socialRepositoryProvider).report(uid, profile.id, reason: reason, details: details),
          );
          break;
      }
    } catch (e) {
      // 'report' never reaches here — showReportSheet handles its own
      // errors. 'hide'/'block' otherwise had no feedback path on
      // failure (a PopupMenuButton's onSelected isn't awaited by
      // Flutter, so a thrown error here would've been an unhandled
      // zone error instead of this snackbar).
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
