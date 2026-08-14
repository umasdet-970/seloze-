import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../admin/providers/admin_providers.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Subscription management & revenue (spec section 16, 18).
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final users = ref.watch(userSearchResultsProvider);
    final subscribers = users.where((u) => u.tier != SubscriptionTier.free).toList()
      ..sort((a, b) => a.tier.index.compareTo(b.tier.index));

    // India price used as the illustrative rate; a real backend would sum
    // actual transactions per region instead of estimating from headcount.
    final premiumMrr = stats.premiumUsers * 899.0;
    final adFreeMrr = stats.adFreeUsers * 99.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subscriptions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Active plans and estimated recurring revenue', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(label: 'Premium subscribers', value: '${stats.premiumUsers}', sub: '${_inr.format(premiumMrr)}/mo est.'),
              _MetricCard(label: 'Ad-Free subscribers', value: '${stats.adFreeUsers}', sub: '${_inr.format(adFreeMrr)}/mo est.'),
              _MetricCard(
                label: 'Total MRR (est.)',
                value: _inr.format(premiumMrr + adFreeMrr),
                sub: 'Illustrative — real MRR needs store transaction data',
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active subscribers', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (subscribers.isEmpty)
                  const Text('No active subscribers', style: TextStyle(color: AppColors.textMuted))
                else
                  for (final u in subscribers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(u.name, style: const TextStyle(fontSize: 13))),
                          Expanded(child: Text(u.country, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                          TierBadge(tier: u.tier),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool highlight;

  const _MetricCard({required this.label, required this.value, required this.sub, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: highlight ? Colors.white70 : AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: highlight ? Colors.white : AppColors.textDark)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 11, color: highlight ? Colors.white70 : AppColors.textMuted)),
        ],
      ),
    );
  }
}
