import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/rate_limiter.dart';
import '../../models/chat_message.dart';
import '../chat_repository.dart';

/// Firestore schema:
///   conversations/{conversationId}                    {participants: [a,b], hiddenFor: [uids]}
///   conversations/{conversationId}/messages/{msgId}    {senderId, text, imageUrl, sentAt, read}
///
/// `isTyping` reads a `typingUsers` array off the conversation doc, but
/// nothing writes to it — [ChatRepository] has no "set typing" method, so
/// there's no real typing-indicator input yet. Kept wired to real data
/// rather than hardcoded `false` so adding a writer later (e.g. a
/// debounced `onChanged` call from the composer) is a pure addition, not
/// a rework.
class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();
  final _messageLimiter = RateLimiter(maxEvents: 20, window: const Duration(minutes: 1));

  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Set<String>> _hiddenForCache = {};
  final Map<String, Set<String>> _typingCache = {};
  final Set<String> _listening = {};

  void _notify() => _controller.add(null);

  @override
  String conversationId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  void _ensureListening(String conversationId) {
    if (_listening.contains(conversationId)) return;
    _listening.add(conversationId);

    final convoRef = _firestore.collection('conversations').doc(conversationId);

    convoRef.snapshots().listen((doc) {
      final data = doc.data();
      _hiddenForCache[conversationId] = Set<String>.from(data?['hiddenFor'] as List? ?? const []);
      _typingCache[conversationId] = Set<String>.from(data?['typingUsers'] as List? ?? const []);
      _notify();
    });

    convoRef.collection('messages').orderBy('sentAt').snapshots().listen((snap) {
      _messagesCache[conversationId] = snap.docs.map((d) {
        final data = d.data();
        return ChatMessage(
          id: d.id,
          senderId: data['senderId'] as String,
          text: data['text'] as String?,
          imageUrl: data['imageUrl'] as String?,
          sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          read: data['read'] as bool? ?? false,
        );
      }).toList();
      _notify();
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  List<ChatMessage> messages(String conversationId) {
    _ensureListening(conversationId);
    return List.unmodifiable(_messagesCache[conversationId] ?? const []);
  }

  @override
  int unreadCount(String conversationId, String forUid) {
    _ensureListening(conversationId);
    return (_messagesCache[conversationId] ?? const []).where((m) => m.senderId != forUid && !m.read).length;
  }

  @override
  bool isHidden(String conversationId, String forUid) {
    _ensureListening(conversationId);
    return _hiddenForCache[conversationId]?.contains(forUid) ?? false;
  }

  @override
  bool isTyping(String conversationId, String byUserId) {
    _ensureListening(conversationId);
    return _typingCache[conversationId]?.contains(byUserId) ?? false;
  }

  Future<void> _ensureConversationDoc(String conversationId, String senderId) async {
    final ref = _firestore.collection('conversations').doc(conversationId);
    final ids = conversationId.split('_');
    await ref.set({
      'participants': ids,
      // A new outgoing message un-hides the conversation for both sides —
      // matches the mock's behavior of clearing hiddenFor on new activity.
      'hiddenFor': FieldValue.arrayRemove(ids),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> sendText(String conversationId, String senderId, String text) async {
    if (text.trim().isEmpty) return;
    if (!_messageLimiter.allow(senderId)) {
      throw RateLimitException("You're sending messages too fast. Please slow down.");
    }
    await _ensureConversationDoc(conversationId, senderId);
    await _firestore.collection('conversations').doc(conversationId).collection('messages').add({
      'senderId': senderId,
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  @override
  Future<void> sendImage(String conversationId, String senderId, String imageUrl) async {
    if (!_messageLimiter.allow(senderId)) {
      throw RateLimitException("You're sending messages too fast. Please slow down.");
    }
    await _ensureConversationDoc(conversationId, senderId);
    await _firestore.collection('conversations').doc(conversationId).collection('messages').add({
      'senderId': senderId,
      'imageUrl': imageUrl,
      'sentAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  @override
  Future<void> markRead(String conversationId, String readerUid) async {
    final unread = (_messagesCache[conversationId] ?? const [])
        .where((m) => m.senderId != readerUid && !m.read);
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    final messagesRef = _firestore.collection('conversations').doc(conversationId).collection('messages');
    for (final m in unread) {
      batch.update(messagesRef.doc(m.id), {'read': true});
    }
    await batch.commit();
  }

  @override
  Future<void> hideConversation(String conversationId, String forUid) async {
    await _firestore.collection('conversations').doc(conversationId).set({
      'hiddenFor': FieldValue.arrayUnion([forUid]),
    }, SetOptions(merge: true));
  }
}
