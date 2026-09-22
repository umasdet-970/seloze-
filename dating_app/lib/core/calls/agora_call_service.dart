import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../config/call_config.dart';

/// Thin wrapper around the Agora engine for one call — created fresh per
/// call, disposed when it ends, rather than a long-lived singleton (unlike
/// RewardedAdService/AudioRecorder elsewhere in this app, a call is a
/// one-shot session with its own join/leave lifecycle, not something to
/// pre-warm). Only ever touched when [kUseVoiceVideoCalls] is true.
class AgoraCallService {
  RtcEngine? _engine;
  int? remoteUid;

  Future<void> initAndJoin({
    required String channelId,
    required bool video,
    required void Function() onRemoteJoined,
    required void Function() onRemoteLeft,
  }) async {
    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(const RtcEngineContext(appId: kAgoraAppId));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (connection, uid, elapsed) {
          remoteUid = uid;
          onRemoteJoined();
        },
        onUserOffline: (connection, uid, reason) {
          remoteUid = null;
          onRemoteLeft();
        },
      ),
    );

    if (video) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.enableAudio();
      await engine.disableVideo();
    }

    // Testing-mode join (empty token) — see call_config.dart's doc comment
    // on why production needs a real token server instead.
    await engine.joinChannel(
      token: '',
      channelId: channelId,
      uid: 0, // 0 lets Agora assign one — this app never needs a stable numeric uid
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setCameraOff(bool off) async {
    await _engine?.muteLocalVideoStream(off);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  RtcEngine? get engine => _engine;

  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    await engine.leaveChannel();
    await engine.release();
  }
}
