import 'dart:async';

import '../models/subscription_models.dart';

/// Purchase flow (spec sections 8-9, 18). When ready, write
/// `RevenueCatBillingRepository implements BillingRepository` — that swap
/// also needs real App Store/Play Store product IDs configured in
/// RevenueCat's dashboard, which requires store developer accounts this
/// environment doesn't have.
abstract class BillingRepository {
  Stream<void> changes();
  SubscriptionRecord currentSubscription(String uid);
  Future<void> purchase(String uid, SubscriptionPlan plan);
  Future<void> cancelAutoRenew(String uid);
  Future<void> restorePurchases(String uid);
}

class MockBillingRepository implements BillingRepository {
  final _controller = StreamController<void>.broadcast();
  final Map<String, SubscriptionRecord> _subscriptions = {};

  @override
  Stream<void> changes() => _controller.stream;

  @override
  SubscriptionRecord currentSubscription(String uid) => _subscriptions[uid] ?? const SubscriptionRecord();

  @override
  Future<void> purchase(String uid, SubscriptionPlan plan) async {
    // Simulates the store checkout sheet round-trip.
    await Future.delayed(const Duration(milliseconds: 1400));
    final now = DateTime.now();
    _subscriptions[uid] = SubscriptionRecord(
      plan: plan,
      purchasedAt: now,
      expiresAt: now.add(plan.duration),
      autoRenew: true,
    );
    _controller.add(null);
  }

  @override
  Future<void> cancelAutoRenew(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = _subscriptions[uid];
    if (current != null) {
      _subscriptions[uid] = SubscriptionRecord(
        plan: current.plan,
        purchasedAt: current.purchasedAt,
        expiresAt: current.expiresAt,
        autoRenew: false,
      );
    }
    _controller.add(null);
  }

  @override
  Future<void> restorePurchases(String uid) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // Nothing to restore against an in-memory mock store.
  }
}
