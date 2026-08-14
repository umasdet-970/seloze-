import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../discover/providers/discover_providers.dart';
import '../../matches/providers/matches_providers.dart';

/// Swap MockChatRepository() -> FirestoreChatRepository() once Firebase
/// (Firestore + Cloud Messaging for push) is wired in.
final chatRepositoryProvider = Provider<ChatRepository>((ref) => MockChatRepository());

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
