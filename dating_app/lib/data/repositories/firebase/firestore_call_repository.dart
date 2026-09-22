import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/stream_safety.dart';
import '../../models/call_models.dart';
import '../call_repository.dart';

CallStatus _statusFromString(String? s) => CallStatus.values.firstWhere((v) => v.name == s, orElse: () => CallStatus.ended);
CallType _typeFromString(String? s) => CallType.values.firstWhere((v) => v.name == s, orElse: () => CallType.audio);

/// Firestore schema: `calls/{conversationId}`
/// {callerId, calleeId, type, status, startedAt}. One doc per
/// conversation — a new call overwrites the previous (ended) one, same
/// "one active thing per conversation" simplification chat itself makes.
class FirestoreCallRepository implements CallRepository {
  FirestoreCallRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();
  final Map<String, CallInvite> _cache = {};
  final Set<String> _listening = {};

  DocumentReference<Map<String, dynamic>> _doc(String conversationId) => _firestore.collection('calls').doc(conversationId);

  void _ensureListening(String conversationId) {
    if (_listening.contains(conversationId)) return;
    _listening.add(conversationId);
    _doc(conversationId).snapshots().listenSafely((doc) {
      final data = doc.data();
      if (data == null) {
        _cache.remove(conversationId);
      } else {
        _cache[conversationId] = CallInvite(
          conversationId: conversationId,
          callerId: data['callerId'] as String? ?? '',
          calleeId: data['calleeId'] as String? ?? '',
          type: _typeFromString(data['type'] as String?),
          status: _statusFromString(data['status'] as String?),
          startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }
      _controller.add(null);
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  CallInvite? currentCall(String conversationId) {
    _ensureListening(conversationId);
    return _cache[conversationId];
  }

  @override
  Future<CallInvite> startCall(
    String conversationId, {
    required String callerId,
    required String calleeId,
    required CallType type,
  }) async {
    final now = DateTime.now();
    await _doc(conversationId).set({
      'callerId': callerId,
      'calleeId': calleeId,
      'type': type.name,
      'status': CallStatus.ringing.name,
      'startedAt': Timestamp.fromDate(now),
    });
    return CallInvite(
      conversationId: conversationId,
      callerId: callerId,
      calleeId: calleeId,
      type: type,
      status: CallStatus.ringing,
      startedAt: now,
    );
  }

  @override
  Future<void> accept(String conversationId) async {
    await _doc(conversationId).set({'status': CallStatus.accepted.name}, SetOptions(merge: true));
  }

  @override
  Future<void> decline(String conversationId) async {
    await _doc(conversationId).set({'status': CallStatus.declined.name}, SetOptions(merge: true));
  }

  @override
  Future<void> end(String conversationId) async {
    await _doc(conversationId).set({'status': CallStatus.ended.name}, SetOptions(merge: true));
  }
}
