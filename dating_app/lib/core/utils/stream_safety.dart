import 'dart:async';

import 'package:flutter/foundation.dart';

/// `Stream.listen` without an `onError` turns every stream error into an
/// unhandled async exception. Firestore snapshot listeners hit this in
/// routine, non-buggy situations — the signed-in user logs out or deletes
/// their account while listeners are still attached, and Firestore then
/// terminates each one with `permission-denied`. Listeners are already
/// terminated by Firestore at that point, so all that's needed is to not
/// let the error escape.
extension SafeStreamListen<T> on Stream<T> {
  StreamSubscription<T> listenSafely(void Function(T event) onData) {
    return listen(
      onData,
      onError: (Object error, StackTrace stack) {
        debugPrint('Stream listener ended with an error: $error');
      },
    );
  }
}
