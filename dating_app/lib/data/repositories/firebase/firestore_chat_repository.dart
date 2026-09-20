import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/rate_limiter.dart';
import '../../models/chat_message.dart';
import '../chat_repository.dart';
import '../../../core/utils/stream_safety.dart';

/// Firestore schema:
///   conversations/{conversationId}                    {participants: [a,b], hiddenFor: [uids]}
///   conversations/{conversationId}/messages/{msgId}    {senderId, text, imageUrl, sentAt, read}
///
/// `typingUsers` on the conversation doc is written by [setTyping] —
/// called from the composer's debounced `onChanged` (see
/// ChatDetailScreen) — and read by `isTyping`.
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

    convoRef.snapshots().listenSafely((doc) {
      final data = doc.data();
      _hiddenForCache[conversationId] = Set<String>.from(data?['hiddenFor'] as List? ?? const []);
      _typingCache[conversationId] = Set<String>.from(data?['typingUsers'] as List? ?? const []);
      _notify();
    });

    convoRef.collection('messages').orderBy('sentAt').snapshots().listenSafely((snap) {
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

  @override
  Future<void> setTyping(String conversationId, String uid, bool typing) async {
    // `set(..., merge: true)` rather than `update` — the conversation doc
    // may not exist yet if the user starts typing before either side has
    // sent a first message. In that case this WRITES it, and
    // firestore.rules' `allow create` requires `participants` to be
    // present on that first write (it checks `request.auth.uid in
    // request.resource.data.participants`) — so `participants` has to be
    // included here too, not just in `_ensureConversationDoc`, or a
    // brand-new conversation's first typing event is denied.
    //
    // Every call site in ChatDetailScreen calls this fire-and-forget
    // (from onChanged/dispose/a Timer callback, none of which usefully
    // await it) — swallowing errors here, once, is simpler and more
    // reliable than adding catchError at each of those call sites.
    try {
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': conversationId.split('_'),
        'typingUsers': typing ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort UI nicety — never worth surfacing to the user or
      // crashing a dispose()/timer callback over.
    }
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
