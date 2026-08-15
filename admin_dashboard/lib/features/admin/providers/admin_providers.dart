import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/firebase/firestore_admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return kUseFirebase ? FirestoreAdminRepository() : MockAdminRepository();
});

final _adminTickProvider = StreamProvider<void>((ref) => ref.watch(adminRepositoryProvider).changes());

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).dashboardStats();
});

final revenueTrendProvider = Provider<List<RevenuePoint>>((ref) {
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).revenueTrend();
});

final countryStatsProvider = Provider<List<CountryStat>>((ref) {
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).countryStats();
});

final userSearchQueryProvider = StateProvider<String>((ref) => '');

final userSearchResultsProvider = Provider<List<AdminUser>>((ref) {
  final query = ref.watch(userSearchQueryProvider);
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).searchUsers(query);
});

final reportQueueProvider = Provider<List<ReportQueueItem>>((ref) {
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).reportQueue();
});

final flaggedProfilesProvider = Provider<List<AdminUser>>((ref) {
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).flaggedProfiles();
});

final auditLogProvider = Provider<List<AuditLogEntry>>((ref) {
  ref.watch(_adminTickProvider);
  return ref.watch(adminRepositoryProvider).auditLog();
});

final registrationFunnelProvider = Provider<List<FunnelStep>>((ref) {
  return ref.watch(adminRepositoryProvider).registrationFunnel();
});

final retentionCurveProvider = Provider<List<RetentionPoint>>((ref) {
  return ref.watch(adminRepositoryProvider).retentionCurve();
});

final acquisitionSourcesProvider = Provider<List<AcquisitionSource>>((ref) {
  return ref.watch(adminRepositoryProvider).acquisitionSources();
});

final growthMetricsProvider = Provider<GrowthMetrics>((ref) {
  return ref.watch(adminRepositoryProvider).growthMetrics();
});
