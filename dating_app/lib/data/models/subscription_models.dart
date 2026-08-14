/// Effective access level, derived from the active [SubscriptionRecord].
/// This is what every feature gate (Discover limits, Likes teaser, Chat
/// lock) actually checks.
enum SubscriptionTier { free, premium, adFree }

/// Real billing will detect this from the store account; mocked via a
/// dev toggle on the paywall until RevenueCat is wired in.
enum BillingRegion { india, international }

/// The three purchasable products (spec section 8-9).
enum SubscriptionPlan { premiumMonthly, premium3Month, adFreeMonthly }

extension SubscriptionPlanInfo on SubscriptionPlan {
  String get title => switch (this) {
        SubscriptionPlan.premiumMonthly => 'Premium Monthly',
        SubscriptionPlan.premium3Month => 'Premium 3 Months',
        SubscriptionPlan.adFreeMonthly => 'Ad-Free Monthly',
      };

  SubscriptionTier get tier =>
      this == SubscriptionPlan.adFreeMonthly ? SubscriptionTier.adFree : SubscriptionTier.premium;

  Duration get duration => switch (this) {
        SubscriptionPlan.premiumMonthly => const Duration(days: 30),
        SubscriptionPlan.premium3Month => const Duration(days: 90),
        SubscriptionPlan.adFreeMonthly => const Duration(days: 30),
      };

  String priceLabel(BillingRegion region) {
    final india = region == BillingRegion.india;
    return switch (this) {
      SubscriptionPlan.premiumMonthly => india ? '₹899/month' : '\$25/month',
      SubscriptionPlan.premium3Month => india ? '₹1,899/3 months' : '\$50/3 months',
      SubscriptionPlan.adFreeMonthly => india ? '₹99/month' : '\$9/month',
    };
  }

  List<String> get benefits => switch (this) {
        SubscriptionPlan.premiumMonthly || SubscriptionPlan.premium3Month => const [
            '50 profile discoveries/day',
            '50 likes/day',
            'Unlimited messaging',
            'Premium filters & dating features',
            'No advertisements',
          ],
        SubscriptionPlan.adFreeMonthly => const [
            'No advertisements',
            'Basic discovery access',
            'Premium chat & features stay locked',
          ],
      };
}

/// The signed-in user's active subscription — null [plan] means Free.
class SubscriptionRecord {
  final SubscriptionPlan? plan;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;
  final bool autoRenew;

  const SubscriptionRecord({this.plan, this.purchasedAt, this.expiresAt, this.autoRenew = true});

  bool get isActive => plan != null && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  SubscriptionTier get tier => isActive ? plan!.tier : SubscriptionTier.free;
}
