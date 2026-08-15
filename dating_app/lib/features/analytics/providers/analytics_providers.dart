import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../data/repositories/firebase/firebase_analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return kUseFirebase ? FirebaseAnalyticsRepository() : ConsoleAnalyticsRepository();
});
