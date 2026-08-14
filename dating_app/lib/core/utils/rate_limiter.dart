/// Simple sliding-window rate limiter (spec section 12/20: rate
/// limiting). A real backend needs this enforced server-side (Cloud
/// Functions / Firestore security rules) since a client-side check alone
/// can be bypassed — this mirrors that logic for the mock repositories so
/// the UI paths and UX are already correct when that swap happens.
class RateLimiter {
  final int maxEvents;
  final Duration window;
  final Map<String, List<DateTime>> _events = {};

  RateLimiter({required this.maxEvents, required this.window});

  /// Returns true and records the event if [key] is under the limit.
  bool allow(String key) {
    final now = DateTime.now();
    final events = _events.putIfAbsent(key, () => []);
    events.removeWhere((t) => now.difference(t) > window);
    if (events.length >= maxEvents) return false;
    events.add(now);
    return true;
  }
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => message;
}
