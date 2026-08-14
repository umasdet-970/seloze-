import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/admin_models.dart';

class StatusBadge extends StatelessWidget {
  final AccountStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AccountStatus.active => AppColors.success,
      AccountStatus.warned => AppColors.warning,
      AccountStatus.suspended => Colors.orange,
      AccountStatus.banned => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class TierBadge extends StatelessWidget {
  final SubscriptionTier tier;
  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = tier == SubscriptionTier.premium ? AppColors.primary : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(tier.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
