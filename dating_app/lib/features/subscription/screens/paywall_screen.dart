import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_item.dart';
import '../../../data/models/subscription_models.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../providers/subscription_providers.dart';

/// Purchase flow (spec sections 8-9): Premium (monthly/3-month) and
/// Ad-Free plans, priced per region, with a mock checkout since real
/// billing needs App Store/Play Store products this environment can't
/// configure.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  SubscriptionPlan? _purchasing;
  bool _restoring = false;

  Future<void> _purchase(SubscriptionPlan plan) async {
    setState(() => _purchasing = plan);
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(billingRepositoryProvider).purchase(uid, plan);
    } catch (e) {
      // Without this, a failed or user-cancelled purchase (both routine —
      // RevenueCat/store checkout throws on cancel, not just real errors)
      // would leave `_purchasing` set forever: the button's `onPressed`
      // is gated on `!isPurchasing`, so this plan's buy button would be
      // permanently stuck showing a spinner until the app restarts.
      if (mounted) {
        setState(() => _purchasing = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _purchasing = null);
    HapticFeedback.heavyImpact();

    final record = ref.read(subscriptionRecordProvider);
    ref.read(notificationRepositoryProvider).add(
          uid,
          NotificationType.subscriptionPurchase,
          '${plan.title} activated 🎉',
          'Your subscription is active${record.expiresAt != null ? ' until ${_formatDate(record.expiresAt!)}' : ''}.',
        );
    ref.read(analyticsRepositoryProvider).logEvent('subscription_purchase', params: {
      'plan': plan.name,
      'tier': plan.tier.name,
    });
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(plan.tier == SubscriptionTier.premium ? 'Welcome to Premium 🎉' : "You're Ad-Free 🎉"),
        content: Text(
          '${plan.title} is active'
          '${record.expiresAt != null ? ' until ${_formatDate(record.expiresAt!)}' : ''}.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Great!'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelAutoRenew() async {
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(billingRepositoryProvider).cancelAutoRenew(uid);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-renew turned off. Your plan stays active until it expires.')),
      );
    }
  }

  // Apple's App Store Review Guidelines (3.1.1) require a restore
  // mechanism for any app selling auto-renewable subscriptions — the
  // repository method already existed (BillingRepository.restorePurchases,
  // both Mock and RevenueCat implementations), it just had no UI calling
  // it anywhere. Without this button, the app fails App Store review.
  Future<void> _restore() async {
    setState(() => _restoring = true);
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(billingRepositoryProvider).restorePurchases(uid);
      if (mounted) {
        final record = ref.read(subscriptionRecordProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(record.isActive ? 'Purchases restored.' : 'No previous purchases found.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(billingRegionProvider);
    final record = ref.watch(subscriptionRecordProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Choose your plan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                DropdownButton<BillingRegion>(
                  value: region,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: BillingRegion.india, child: Text('🇮🇳 India')),
                    DropdownMenuItem(value: BillingRegion.international, child: Text('🌍 International')),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(billingRegionProvider.notifier).state = v;
                  },
                ),
              ],
            ),
            const Text('Prices shown for your billing region', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            if (record.isActive) ...[
              _CurrentPlanCard(record: record, onCancelAutoRenew: _cancelAutoRenew, formatDate: _formatDate),
              const SizedBox(height: 20),
            ],
            ...SubscriptionPlan.values.map((plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PlanCard(
                    plan: plan,
                    region: region,
                    isCurrent: record.plan == plan && record.isActive,
                    isPurchasing: _purchasing == plan,
                    onSubscribe: () => _purchase(plan),
                  ),
                )),
            Center(
              child: TextButton(
                onPressed: _restoring ? null : _restore,
                child: _restoring
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Restore purchases'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionRecord record;
  final VoidCallback onCancelAutoRenew;
  final String Function(DateTime) formatDate;

  const _CurrentPlanCard({required this.record, required this.onCancelAutoRenew, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan: ${record.plan!.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (record.expiresAt != null)
                  Text(
                    record.autoRenew
                        ? 'Renews ${formatDate(record.expiresAt!)}'
                        : 'Ends ${formatDate(record.expiresAt!)} (auto-renew off)',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (record.autoRenew) TextButton(onPressed: onCancelAutoRenew, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final BillingRegion region;
  final bool isCurrent;
  final bool isPurchasing;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.region,
    required this.isCurrent,
    required this.isPurchasing,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = plan == SubscriptionPlan.premium3Month;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight ? AppColors.primary : Colors.grey.shade200, width: highlight ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              if (highlight)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Best value', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(plan.priceLabel(region), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          ...plan.benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isCurrent || isPurchasing ? null : onSubscribe,
              child: isPurchasing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isCurrent ? 'Current plan' : 'Subscribe'),
            ),
          ),
        ],
      ),
    );
  }
}
