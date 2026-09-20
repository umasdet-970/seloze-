import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/models/subscription_models.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../../data/repositories/firebase/revenuecat_billing_repository.dart';
import '../../discover/providers/discover_providers.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return kUseRevenueCat ? RevenueCatBillingRepository() : MockBillingRepository();
});

/// Dev-only region preview until real billing detects it from the store
/// account. Surfaced explicitly on the paywall, not hidden.
final billingRegionProvider = StateProvider<BillingRegion>((ref) => BillingRegion.india);

final _billingTickProvider = StreamProvider<void>((ref) {
  return ref.watch(billingRepositoryProvider).changes();
});

/// The signed-in user's active subscription — read-only. The only way to
/// change tier is a real purchase via [BillingRepository.purchase].
final subscriptionRecordProvider = Provider<SubscriptionRecord>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(billingRepositoryProvider);
  ref.watch(_billingTickProvider);
  if (uid.isEmpty) return const SubscriptionRecord();
  return repo.currentSubscription(uid);
});

final subscriptionTierProvider = Provider<SubscriptionTier>((ref) {
  return ref.watch(subscriptionRecordProvider).tier;
});

/// Whether the signed-in user may chat. Premium-only once real billing is
/// live (`kUseRevenueCat`), per the spec. While billing is off there is no
/// way to become Premium, so gating chat would mean nobody can message
/// anyone — it opens up for everyone until RevenueCat is switched on, then
/// locks for free users automatically.
final chatUnlockedProvider = Provider<bool>((ref) {
  if (!kUseRevenueCat) return true;
  return ref.watch(subscriptionTierProvider) == SubscriptionTier.premium;
});

/// Free vs Premium gating (spec section 4: 10 vs 50 discoveries/day).
final dailyDiscoveryLimitProvider = Provider<int>((ref) {
  final tier = ref.watch(subscriptionTierProvider);
  return tier == SubscriptionTier.premium ? 50 : 10;
});

/// (used, limit) for today — drives the "X of Y discoveries left" UI and
/// the paywall empty state once exhausted.
final discoveryQuotaProvider = Provider<(int used, int limit)>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final limit = ref.watch(dailyDiscoveryLimitProvider);
  ref.watch(discoverFeedProvider); // rebuild when the feed changes usage
  final social = ref.watch(socialRepositoryProvider);
  return (uid.isEmpty ? 0 : social.discoveriesUsedToday(uid), limit);
});
