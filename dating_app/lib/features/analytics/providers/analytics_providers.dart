import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/analytics_repository.dart';

/// Swap ConsoleAnalyticsRepository() -> FirebaseAnalyticsRepository()
/// once Firebase is wired in.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) => ConsoleAnalyticsRepository());
