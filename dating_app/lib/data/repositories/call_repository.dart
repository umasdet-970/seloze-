import 'dart:async';

import '../models/call_models.dart';

/// Call signaling (spec: Bumble/Badoo-style in-app voice/video calls) —
/// who's calling whom on a conversation, and whether it's been picked up.
/// Deliberately separate from the actual Agora media join (CallScreen):
/// this half is plain Firestore, works and is tested independently of
/// kUseVoiceVideoCalls (see call_config.dart) — only actually joining a
/// media channel needs a real Agora account.
abstract class CallRepository {
  /// Fires on any call started/accepted/declined/ended.
  Stream<void> changes();

  /// The current call on [conversationId], if any is ringing/active.
  /// Null once ended/declined.
  CallInvite? currentCall(String conversationId);

  Future<CallInvite> startCall(String conversationId, {required String callerId, required String calleeId, required CallType type});
  Future<void> accept(String conversationId);
  Future<void> decline(String conversationId);
  Future<void> end(String conversationId);
}

class MockCallRepository implements CallRepository {
  final _controller = StreamController<void>.broadcast();
  final Map<String, CallInvite> _calls = {};

  void _notify() => _controller.add(null);

  @override
  Stream<void> changes() => _controller.stream;

  @override
  CallInvite? currentCall(String conversationId) => _calls[conversationId];

  @override
  Future<CallInvite> startCall(
    String conversationId, {
    required String callerId,
    required String calleeId,
    required CallType type,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final call = CallInvite(
      conversationId: conversationId,
      callerId: callerId,
      calleeId: calleeId,
      type: type,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
    );
    _calls[conversationId] = call;
    _notify();
    return call;
  }

  @override
  Future<void> accept(String conversationId) async {
    final call = _calls[conversationId];
    if (call == null) return;
    _calls[conversationId] = call.copyWith(status: CallStatus.accepted);
    _notify();
  }

  @override
  Future<void> decline(String conversationId) async {
    final call = _calls[conversationId];
    if (call == null) return;
    _calls[conversationId] = call.copyWith(status: CallStatus.declined);
    _notify();
  }

  @override
  Future<void> end(String conversationId) async {
    final call = _calls[conversationId];
    if (call == null) return;
    _calls[conversationId] = call.copyWith(status: CallStatus.ended);
    _notify();
  }
}
