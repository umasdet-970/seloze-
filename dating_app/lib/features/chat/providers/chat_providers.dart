import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/firebase/firestore_chat_repository.dart';
import '../../discover/providers/discover_providers.dart';
import '../../matches/providers/matches_providers.dart';
import '../../notifications/providers/notification_providers.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return kUseFirebase ? FirestoreChatRepository() : MockChatRepository();
});

/// Forces dependent providers to re-read the repository's synchronous
/// getters whenever a message/typing/read/hide event fires.
final _chatTickProvider = StreamProvider<void>((ref) {
  return ref.watch(chatRepositoryProvider).changes();
});

class ConversationSummary {
  final Profile profile;
  final DateTime matchedAt;
  final String conversationId;
  final ChatMessage? lastMessage;
  final int unreadCount;

  const ConversationSummary({
    required this.profile,
    required this.matchedAt,
    required this.conversationId,
    required this.lastMessage,
    required this.unreadCount,
  });
}

/// One conversation per match, newest activity first. Matches without a
/// chat repository entry yet still show up (as "say hi" prompts).
final conversationsProvider = Provider<AsyncValue<List<ConversationSummary>>>((ref) {
  final matchesAsync = ref.watch(matchesProvider);
  final uid = ref.watch(currentUserIdProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  ref.watch(_chatTickProvider);

  return matchesAsync.whenData((matches) {
    final result = <ConversationSummary>[];
    for (final m in matches) {
      final convoId = chatRepo.conversationId(uid, m.profile.id);
      if (chatRepo.isHidden(convoId, uid)) continue;
      final msgs = chatRepo.messages(convoId);
      result.add(ConversationSummary(
        profile: m.profile,
        matchedAt: m.matchedAt,
        conversationId: convoId,
        lastMessage: msgs.isNotEmpty ? msgs.last : null,
        unreadCount: chatRepo.unreadCount(convoId, uid),
      ));
    }
    result.sort((a, b) {
      final aTime = a.lastMessage?.sentAt ?? a.matchedAt;
      final bTime = b.lastMessage?.sentAt ?? b.matchedAt;
      return bTime.compareTo(aTime);
    });
    return result;
  });
});

final chatMessagesProvider = Provider.family<List<ChatMessage>, String>((ref, conversationId) {
  ref.watch(_chatTickProvider);
  return ref.watch(chatRepositoryProvider).messages(conversationId);
});

final isOtherUserTypingProvider = Provider.family<bool, ({String conversationId, String otherUserId})>((ref, args) {
  ref.watch(_chatTickProvider);
  return ref.watch(chatRepositoryProvider).isTyping(args.conversationId, args.otherUserId);
});

/// The conversation id currently open on screen, if any — set/cleared by
/// ChatDetailScreen's lifecycle. Lets the global new-message watcher
/// below skip notifying about a chat the user is actively looking at.
final openConversationIdProvider = StateProvider<String?>((ref) => null);

/// Fires a "New Message" notification (spec section 13) for any
/// conversation the signed-in user isn't currently viewing when a new
/// message arrives — watched once from main.dart so it stays active for
/// the app's lifetime, independent of which screen is on-screen.
final newMessageWatcherProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? const [];
  final chatRepo = ref.watch(chatRepositoryProvider);
  final notificationRepo = ref.watch(notificationRepositoryProvider);

  if (uid.isEmpty || conversations.isEmpty) return;

  final lastSeenCounts = <String, int>{
    for (final c in conversations) c.conversationId: chatRepo.messages(c.conversationId).length,
  };

  final subscription = chatRepo.changes().listen((_) {
    for (final c in conversations) {
      final messages = chatRepo.messages(c.conversationId);
      final previousCount = lastSeenCounts[c.conversationId] ?? 0;
      if (messages.length > previousCount) {
        final newest = messages.last;
        final isOpen = ref.read(openConversationIdProvider) == c.conversationId;
        if (newest.senderId != uid && !isOpen) {
          notificationRepo.add(
            uid,
            NotificationType.newMessage,
            'New message from ${c.profile.name}',
            newest.isImage ? '📷 Photo' : (newest.text ?? ''),
          );
        }
      }
      lastSeenCounts[c.conversationId] = messages.length;
    }
  });

  ref.onDispose(subscription.cancel);
});
