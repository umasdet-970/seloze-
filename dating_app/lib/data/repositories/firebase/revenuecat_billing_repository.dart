import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/backend_config.dart';
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
    final record = _recordFromCustomerInfo(info);
    _cache[info.originalAppUserId] = record;
    _controller.add(null);
    unawaited(_syncTierToFirestore(info.originalAppUserId, record));
  }

  /// Best-effort write-back so the admin dashboard (a Firestore-only
  /// client with no RevenueCat access of its own) can show real tier
  /// counts and an estimated MRR instead of fabricated numbers. Not a
  /// substitute for RevenueCat webhooks — see BILLING_SETUP.md — this
  /// only reflects entitlement state this device has actually observed,
  /// so it can lag a cancellation/renewal that happened elsewhere until
  /// the app is next opened.
  Future<void> _syncTierToFirestore(String uid, SubscriptionRecord record) async {
    if (!kUseFirebase || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'subscriptionTier': record.tier.name},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-critical: admin stats staying a step behind isn't worth
      // surfacing an error from a billing-state listener callback.
    }
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
    try {
      // Links RevenueCat's (initially anonymous) app user id to our own
      // Firebase uid, so purchases follow the signed-in user across devices.
      final result = await Purchases.logIn(uid);
      _cache[uid] = _recordFromCustomerInfo(result.customerInfo);
    } catch (e) {
      // Without this, a transient failure (offline on first launch,
      // RevenueCat misconfigured) would mark this uid "already logged
      // in" forever — every later call becomes a silent no-op that
      // never retries, permanently stuck showing Free tier even once
      // connectivity/config is fixed.
      _loggedIn.remove(uid);
      rethrow;
    }
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  SubscriptionRecord currentSubscription(String uid) {
    // `currentSubscription` is a synchronous getter called from UI
    // builds — a login failure has to be swallowed here (not left
    // unhandled), unlike purchase()/restorePurchases() below, which
    // `await _ensureLoggedIn` directly and want the error to propagate
    // to whoever tapped "Subscribe"/"Restore".
    unawaited(_ensureLoggedIn(uid).catchError((_) {}));
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
    final record = _recordFromCustomerInfo(info);
    _cache[uid] = record;
    _controller.add(null);
    unawaited(_syncTierToFirestore(uid, record));
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
    final record = _recordFromCustomerInfo(info);
    _cache[uid] = record;
    _controller.add(null);
    unawaited(_syncTierToFirestore(uid, record));
  }
}
