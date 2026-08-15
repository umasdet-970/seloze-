import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Foreground-presence heartbeat (spec section 7: online/offline status).
/// Firestore has no native "user disconnected" signal — unlike the
/// Realtime Database's `onDisconnect()`, which this project doesn't use —
/// so this substitutes periodic "I'm still here" writes to
/// `users/{uid}.lastActiveAt`, paired with a staleness check read at
/// display time (see `FirestoreProfileRepository._isRecentlyActive`)
/// instead of a live disconnect trigger.
///
/// Known limitation, documented rather than silently assumed away: this
/// can't detect an app kill/crash faster than [_heartbeatInterval], and
/// doesn't distinguish "foregrounded" from "backgrounded but not killed"
/// — writes continue as long as the Dart isolate is alive. A production
/// hardening pass wanting true real-time presence would move to the
/// Realtime Database specifically for its `onDisconnect()` support (RTDB
/// and Firestore commonly coexist in the same Firebase project for
/// exactly this reason), which is a bigger change than this pass makes.
class PresenceService {
  PresenceService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  Timer? _timer;

  static const heartbeatInterval = Duration(seconds: 60);

  void start(String uid) {
    if (uid.isEmpty || _timer != null) return;
    _beat(uid);
    _timer = Timer.periodic(heartbeatInterval, (_) => _beat(uid));
  }

  void _beat(String uid) {
    // Fire-and-forget, but still needs `catchError` — an unawaited
    // Future that later fails (offline device, rules not deployed yet)
    // is an unhandled zone error otherwise, not a silently ignored one.
    _firestore.collection('users').doc(uid).set(
      {'lastActiveAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    ).catchError((_) {});
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
