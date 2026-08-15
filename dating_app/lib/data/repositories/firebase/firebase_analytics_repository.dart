import 'package:firebase_analytics/firebase_analytics.dart';

import '../analytics_repository.dart';

class FirebaseAnalyticsRepository implements AnalyticsRepository {
  FirebaseAnalyticsRepository({FirebaseAnalytics? analytics}) : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    // FirebaseAnalytics requires non-null, non-empty param maps to omit
    // the `parameters` argument entirely rather than pass an empty map.
    _analytics.logEvent(name: name, parameters: params.isEmpty ? null : Map<String, Object>.from(params));
  }

  @override
  void setUserId(String? uid) {
    _analytics.setUserId(id: uid);
  }
}
