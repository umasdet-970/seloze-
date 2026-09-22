/// In-app voice/video calls (spec: Bumble/Badoo-style — talk before
/// meeting, without exchanging phone numbers), using Agora's RTC SDK.
///
/// Off for the first release: real-time media needs an Agora account and
/// project App ID (agora.io — free tier exists, same "needs an account
/// that doesn't exist yet" story as AdMob before that was set up). All the
/// call *signaling* (ringing, accept/decline, call history) works and is
/// tested independently of this flag — see CallRepository — since it's
/// plain Firestore, not Agora. Only actually joining a media channel is
/// gated behind [kUseVoiceVideoCalls]; flipping it on needs [kAgoraAppId]
/// replaced with a real one too, or the SDK will fail to initialize.
///
/// Before a real launch:
/// 1. Create an Agora project at https://console.agora.io (free tier).
/// 2. Replace [kAgoraAppId] below with the real App ID.
/// 3. For production, Agora strongly recommends token-based auth (not the
///    App-ID-only "testing mode" this scaffolding uses) — see Agora's
///    docs on token servers; that needs a small server endpoint (e.g. a
///    Cloud Function) this app doesn't have yet.
/// 4. Flip this flag to true and rebuild.
const bool kUseVoiceVideoCalls = false;

const String kAgoraAppId = 'REPLACE_WITH_REAL_AGORA_APP_ID';
