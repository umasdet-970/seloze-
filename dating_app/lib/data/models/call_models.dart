enum CallType { audio, video }

enum CallStatus { ringing, accepted, declined, ended }

/// One call attempt on a conversation. Signaling only — who's calling
/// whom and whether it's been picked up — kept in Firestore, separate
/// from the actual Agora media session (see CallScreen/call_config.dart).
/// One active call per conversation at a time (doc id = conversationId),
/// same simplification chat itself makes (one conversation per match).
class CallInvite {
  final String conversationId;
  final String callerId;
  final String calleeId;
  final CallType type;
  final CallStatus status;
  final DateTime startedAt;

  const CallInvite({
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.type,
    required this.status,
    required this.startedAt,
  });

  bool isCaller(String uid) => uid == callerId;

  CallInvite copyWith({CallStatus? status}) {
    return CallInvite(
      conversationId: conversationId,
      callerId: callerId,
      calleeId: calleeId,
      type: type,
      status: status ?? this.status,
      startedAt: startedAt,
    );
  }
}
