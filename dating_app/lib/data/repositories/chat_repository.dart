import 'dart:async';
import 'dart:math';

import '../../core/utils/rate_limiter.dart';
import '../models/chat_message.dart';

/// One-to-one messaging (spec section 7). Conversations are 1:1 with
/// matches — there's no separate "create conversation" step, just
/// `conversationId(a, b)` as a stable, symmetric key.
abstract class ChatRepository {
  String conversationId(String uidA, String uidB);

  /// Fires on any new message, typing change, read update, or hide.
  Stream<void> changes();

  List<ChatMessage> messages(String conversationId);
  int unreadCount(String conversationId, String forUid);
  bool isHidden(String conversationId, String forUid);
  bool isTyping(String conversationId, String byUserId);

  /// Sets/clears [uid]'s typing state for [conversationId] — spec section
  /// 7's typing indicator. Called from the composer's `onChanged`
  /// (debounced) rather than per-keystroke; see ChatDetailScreen.
  Future<void> setTyping(String conversationId, String uid, bool typing);

  Future<void> sendText(String conversationId, String senderId, String text);
  Future<void> sendImage(String conversationId, String senderId, String imageUrl);
  Future<void> markRead(String conversationId, String readerUid);
  Future<void> hideConversation(String conversationId, String forUid);
}

class MockChatRepository implements ChatRepository {
  final _controller = StreamController<void>.broadcast();
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, Set<String>> _hiddenFor = {};
  final Map<String, Set<String>> _typingUsers = {};
  int _nextId = 1;
  final _messageLimiter = RateLimiter(maxEvents: 20, window: const Duration(minutes: 1));

  static const _autoReplies = [
    "Hey! 😊",
    "Haha, that's funny",
    "How's your day going?",
    "Nice! Tell me more",
    "I was just thinking about that too",
    "Omg yes 😄",
  ];

  void _notify() => _controller.add(null);

  @override
  String conversationId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  String _otherUserId(String conversationId, String knownUserId) {
    final ids = conversationId.split('_');
    return ids.first == knownUserId ? ids.last : ids.first;
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  List<ChatMessage> messages(String conversationId) => List.unmodifiable(_messages[conversationId] ?? const []);

  @override
  int unreadCount(String conversationId, String forUid) {
    return (_messages[conversationId] ?? const [])
        .where((m) => m.senderId != forUid && !m.read)
        .length;
  }

  @override
  bool isHidden(String conversationId, String forUid) => _hiddenFor[conversationId]?.contains(forUid) ?? false;

  @override
  bool isTyping(String conversationId, String byUserId) => _typingUsers[conversationId]?.contains(byUserId) ?? false;

  @override
  Future<void> setTyping(String conversationId, String uid, bool typing) async {
    final set = _typingUsers[conversationId] ??= {};
    typing ? set.add(uid) : set.remove(uid);
    _notify();
  }

  void _appendMessage(String conversationId, ChatMessage message) {
    (_messages[conversationId] ??= []).add(message);
    // A new incoming message un-hides a conversation the user had hidden.
    _hiddenFor[conversationId]?.clear();
    _notify();
  }

  Future<void> _simulateReply(String conversationId, String senderId) async {
    final otherId = _otherUserId(conversationId, senderId);
    (_typingUsers[conversationId] ??= {}).add(otherId);
    _notify();

    await Future.delayed(Duration(milliseconds: 900 + Random().nextInt(900)));

    _typingUsers[conversationId]?.remove(otherId);
    final reply = _autoReplies[Random().nextInt(_autoReplies.length)];
    _appendMessage(
      conversationId,
      ChatMessage(id: '${_nextId++}', senderId: otherId, text: reply, sentAt: DateTime.now()),
    );
  }

  @override
  Future<void> sendText(String conversationId, String senderId, String text) async {
    if (text.trim().isEmpty) return;
    if (!_messageLimiter.allow(senderId)) {
      throw RateLimitException("You're sending messages too fast. Please slow down.");
    }
    _appendMessage(
      conversationId,
      ChatMessage(id: '${_nextId++}', senderId: senderId, text: text.trim(), sentAt: DateTime.now()),
    );
    unawaited(_simulateReply(conversationId, senderId));
  }

  @override
  Future<void> sendImage(String conversationId, String senderId, String imageUrl) async {
    if (!_messageLimiter.allow(senderId)) {
      throw RateLimitException("You're sending messages too fast. Please slow down.");
    }
    _appendMessage(
      conversationId,
      ChatMessage(id: '${_nextId++}', senderId: senderId, imageUrl: imageUrl, sentAt: DateTime.now()),
    );
    unawaited(_simulateReply(conversationId, senderId));
  }

  @override
  Future<void> markRead(String conversationId, String readerUid) async {
    final list = _messages[conversationId];
    if (list == null) return;
    var changed = false;
    for (var i = 0; i < list.length; i++) {
      if (list[i].senderId != readerUid && !list[i].read) {
        list[i] = list[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) _notify();
  }

  @override
  Future<void> hideConversation(String conversationId, String forUid) async {
    (_hiddenFor[conversationId] ??= {}).add(forUid);
    _notify();
  }
}
