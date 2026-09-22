import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/calls/agora_call_service.dart';
import '../../../core/config/call_config.dart';
import '../../../data/models/call_models.dart';
import '../../../data/models/profile.dart';
import '../../discover/providers/discover_providers.dart';
import '../providers/call_providers.dart';

/// In-app voice/video call screen (spec: Bumble/Badoo-style). Drives
/// entirely off [currentCallProvider] — the caller's ChatDetailScreen
/// creates the ringing CallInvite and pushes this screen; the callee sees
/// an incoming-call banner in chat and, on accepting, is pushed here too.
/// The actual media join only happens when [kUseVoiceVideoCalls] is true
/// (see call_config.dart) — otherwise this still runs the full
/// ringing/accept/decline/end signaling flow, just without live
/// audio/video, and says so plainly rather than pretending it's connected.
class CallScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final Profile otherProfile;

  const CallScreen({super.key, required this.conversationId, required this.otherProfile});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _agora = AgoraCallService();
  bool _muted = false;
  bool _cameraOff = false;
  bool _joinedMedia = false;
  bool _remoteJoined = false;
  bool _popped = false;

  @override
  void dispose() {
    _agora.dispose();
    super.dispose();
  }

  Future<void> _joinMediaIfNeeded(CallInvite call) async {
    if (!kUseVoiceVideoCalls || _joinedMedia) return;
    _joinedMedia = true;
    try {
      await _agora.initAndJoin(
        channelId: widget.conversationId,
        video: call.type == CallType.video,
        onRemoteJoined: () {
          if (mounted) setState(() => _remoteJoined = true);
        },
        onRemoteLeft: () {
          if (mounted) setState(() => _remoteJoined = false);
        },
      );
      if (mounted) setState(() {}); // refresh once the engine is actually ready
    } catch (_) {
      // Best-effort — a failed join shouldn't crash the call UI. The
      // "connecting…" state just never resolves, which is honest: it
      // genuinely didn't connect.
    }
  }

  void _popOnce() {
    if (_popped) return;
    _popped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  Future<void> _accept() async {
    HapticFeedback.mediumImpact();
    await ref.read(callRepositoryProvider).accept(widget.conversationId);
  }

  Future<void> _decline() async {
    await ref.read(callRepositoryProvider).decline(widget.conversationId);
    _popOnce();
  }

  Future<void> _hangUp() async {
    await ref.read(callRepositoryProvider).end(widget.conversationId);
    _popOnce();
  }

  String _statusLabel(CallInvite call, bool isCaller) {
    switch (call.status) {
      case CallStatus.ringing:
        return isCaller ? 'Calling…' : 'Incoming ${call.type == CallType.video ? 'video' : 'voice'} call';
      case CallStatus.accepted:
        if (!kUseVoiceVideoCalls) return "Connected — call audio isn't live yet";
        return _remoteJoined ? 'Connected' : 'Connecting…';
      case CallStatus.declined:
        return 'Call declined';
      case CallStatus.ended:
        return 'Call ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(currentCallProvider(widget.conversationId));
    final uid = ref.watch(currentUserIdProvider);

    if (call == null || call.status == CallStatus.declined || call.status == CallStatus.ended) {
      _popOnce();
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final isCaller = call.isCaller(uid);
    final showVideo = kUseVoiceVideoCalls &&
        call.type == CallType.video &&
        call.status == CallStatus.accepted &&
        _joinedMedia &&
        _agora.engine != null;

    if (call.status == CallStatus.accepted) _joinMediaIfNeeded(call);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (showVideo)
              _VideoLayer(
                agora: _agora,
                remoteUid: _agora.remoteUid,
                cameraOff: _cameraOff,
                channelId: widget.conversationId,
              ),
            Column(
              children: [
                if (!showVideo) ...[
                  const Spacer(),
                  CircleAvatar(
                    radius: 56,
                    backgroundImage:
                        widget.otherProfile.photoUrls.isNotEmpty ? CachedNetworkImageProvider(widget.otherProfile.photoUrls.first) : null,
                    child: widget.otherProfile.photoUrls.isEmpty ? const Icon(Icons.person, size: 48) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(widget.otherProfile.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                if (showVideo) const Spacer(),
                Text(_statusLabel(call, isCaller), style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                if (call.status == CallStatus.ringing && !isCaller)
                  _IncomingCallActions(onAccept: _accept, onDecline: _decline)
                else
                  _InCallControls(
                    muted: _muted,
                    cameraOff: _cameraOff,
                    isVideo: call.type == CallType.video,
                    onToggleMute: () {
                      setState(() => _muted = !_muted);
                      _agora.setMuted(_muted);
                    },
                    onToggleCamera: () {
                      setState(() => _cameraOff = !_cameraOff);
                      _agora.setCameraOff(_cameraOff);
                    },
                    onHangUp: _hangUp,
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLayer extends StatelessWidget {
  final AgoraCallService agora;
  final int? remoteUid;
  final bool cameraOff;
  final String channelId;
  const _VideoLayer({required this.agora, required this.remoteUid, required this.cameraOff, required this.channelId});

  @override
  Widget build(BuildContext context) {
    final engine = agora.engine;
    if (engine == null) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned.fill(
          child: remoteUid == null
              ? const ColoredBox(color: Colors.black)
              : AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: remoteUid),
                    connection: RtcConnection(channelId: channelId),
                  ),
                ),
        ),
        if (!cameraOff)
          Positioned(
            top: 16,
            right: 16,
            width: 100,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AgoraVideoView(
                controller: VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0)),
              ),
            ),
          ),
      ],
    );
  }
}

class _IncomingCallActions extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _IncomingCallActions({required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(icon: Icons.call_end, color: Colors.red, onTap: onDecline),
        _RoundButton(icon: Icons.call, color: Colors.green, onTap: onAccept),
      ],
    );
  }
}

class _InCallControls extends StatelessWidget {
  final bool muted;
  final bool cameraOff;
  final bool isVideo;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onHangUp;

  const _InCallControls({
    required this.muted,
    required this.cameraOff,
    required this.isVideo,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onHangUp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: muted ? Icons.mic_off : Icons.mic,
          color: muted ? Colors.white24 : Colors.white12,
          onTap: onToggleMute,
        ),
        _RoundButton(icon: Icons.call_end, color: Colors.red, onTap: onHangUp),
        if (isVideo)
          _RoundButton(
            icon: cameraOff ? Icons.videocam_off : Icons.videocam,
            color: cameraOff ? Colors.white24 : Colors.white12,
            onTap: onToggleCamera,
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: color,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(18), child: Icon(icon, color: Colors.white, size: 28)),
      ),
    );
  }
}
