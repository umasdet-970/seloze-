import 'package:flutter/foundation.dart';

/// Event tracking (spec section 17). Real implementation sends to
/// Firebase Analytics (+ BigQuery export for the admin dashboard's
/// funnel/retention/CAC/LTV views) — this mock just logs to the debug
/// console, but every call site is already instrumented with the events
/// that matter, so the swap is a one-line repository change.
abstract class AnalyticsRepository {
  void logEvent(String name, {Map<String, Object?> params});
  void setUserId(String? uid);
}

class ConsoleAnalyticsRepository implements AnalyticsRepository {
  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    if (kDebugMode) {
      debugPrint('[analytics] $name${params.isEmpty ? '' : ' $params'}');
    }
  }

  @override
  void setUserId(String? uid) {
    if (kDebugMode) {
      debugPrint('[analytics] set_user_id $uid');
    }
  }
}
