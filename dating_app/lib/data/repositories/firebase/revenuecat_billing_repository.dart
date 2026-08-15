import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/subscription_models.dart';
import '../billing_repository.dart';

/// RevenueCat public SDK key (Project settings → API keys → Public
/// app-specific key for Google Play in the RevenueCat dashboard). Public
/// keys are meant to be embedded client-side — this is not a secret.
const _revenueCatApiKey = 'YOUR_REVENUECAT_PUBLIC_SDK_KEY';

/// Package/product identifiers — must exactly match what you configure in
/// RevenueCat (Offerings → Packages), which in turn must match the
/// subscription product/base-plan IDs you create in Play Console. Pick
/// your own convention; these are just what this app's code expects.
const Map<SubscriptionPlan, String> _planToProductId = {
  SubscriptionPlan.premiumMonthly: 'premium_monthly',
  SubscriptionPlan.premium3Month: 'premium_3month',
  SubscriptionPlan.adFreeMonthly: 'ad_free_monthly',
};
final Map<String, SubscriptionPlan> _productIdToPlan = {
  for (final entry in _planToProductId.entries) entry.value: entry.key,
};

/// Call once at startup, gated behind `kUseRevenueCat` (see main.dart) —
/// must happen before any other `Purchases.*` call.
Future<void> configureRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.warn);
  await Purchases.configure(PurchasesConfiguration(_revenueCatApiKey));
}

/// `currentSubscription` must stay synchronous (same constraint as every
/// other repository's read-side in this app), so this caches the latest
/// [SubscriptionRecord] per uid, refreshed via RevenueCat's own
/// customer-info-update listener rather than polling.
class RevenueCatBillingRepository implements BillingRepository {
  RevenueCatBillingRepository() {
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
  }

  final _controller = StreamController<void>.broadcast();
  final Map<String, SubscriptionRecord> _cache = {};
  final Set<String> _loggedIn = {};

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _cache[info.originalAppUserId] = _recordFromCustomerInfo(info);
    _controller.add(null);
  }

  SubscriptionRecord _recordFromCustomerInfo(CustomerInfo info) {
    for (final entitlement in info.entitlements.active.values) {
      final plan = _productIdToPlan[entitlement.productIdentifier];
      if (plan == null) continue; // an entitlement RevenueCat knows about that this app doesn't map
      return SubscriptionRecord(
        plan: plan,
        purchasedAt: DateTime.tryParse(entitlement.latestPurchaseDate),
        expiresAt: entitlement.expirationDate == null ? null : DateTime.tryParse(entitlement.expirationDate!),
        autoRenew: entitlement.willRenew,
      );
    }
    return const SubscriptionRecord();
  }

  Future<void> _ensureLoggedIn(String uid) async {
    if (_loggedIn.contains(uid) || uid.isEmpty) return;
    _loggedIn.add(uid);
    // Links RevenueCat's (initially anonymous) app user id to our own
    // Firebase uid, so purchases follow the signed-in user across devices.
    final result = await Purchases.logIn(uid);
    _cache[uid] = _recordFromCustomerInfo(result.customerInfo);
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  SubscriptionRecord currentSubscription(String uid) {
    unawaited(_ensureLoggedIn(uid));
    return _cache[uid] ?? const SubscriptionRecord();
  }

  @override
  Future<void> purchase(String uid, SubscriptionPlan plan) async {
    await _ensureLoggedIn(uid);
    final productId = _planToProductId[plan]!;
    final offerings = await Purchases.getOfferings();

    Package? package;
    for (final p in offerings.current?.availablePackages ?? const <Package>[]) {
      if (p.storeProduct.identifier == productId || p.identifier == productId) {
        package = p;
        break;
      }
    }
    if (package == null) {
      throw StateError('No RevenueCat package found for "$productId" — check your Offerings configuration.');
    }

    // purchasePackage returns the CustomerInfo directly (unlike logIn,
    // which wraps it in a {customerInfo, created} result).
    final info = await Purchases.purchasePackage(package);
    _cache[uid] = _recordFromCustomerInfo(info);
    _controller.add(null);
  }

  @override
  Future<void> cancelAutoRenew(String uid) async {
    // Google Play Billing gives apps no API to cancel a subscription
    // directly — only Play Store's own subscription management screen
    // can. The best an app can do is deep-link there with the right SKU
    // pre-selected.
    final productId = switch (_cache[uid]?.plan) {
      final plan? => _planToProductId[plan],
      null => null,
    };
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '${productId != null ? '?sku=$productId&package=com.connect.connect_dating_app' : ''}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('Could not open subscription management.');
  }

  @override
  Future<void> restorePurchases(String uid) async {
    await _ensureLoggedIn(uid);
    final info = await Purchases.restorePurchases();
    _cache[uid] = _recordFromCustomerInfo(info);
    _controller.add(null);
  }
}
