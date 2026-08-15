import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../admin/providers/admin_providers.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Funnel, retention, acquisition, CAC/LTV (spec section 17). DAU/MAU,
/// churn, premium/ad-free conversion, the registration funnel, and
/// (Android) acquisition source are real Firestore queries once
/// `kUseFirebase` is on. CAC/LTV are real computations too, but stay at
/// ₹0 until, respectively, an admin enters ad-spend data and RevenueCat
/// is configured to send webhooks — see FirestoreAdminRepository's doc
/// comment. The mock still shows illustrative figures for all of it.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final funnel = ref.watch(registrationFunnelProvider);
    final retention = ref.watch(retentionCurveProvider);
    final sources = ref.watch(acquisitionSourcesProvider);
    final growth = ref.watch(growthMetricsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'CAC needs ad-spend entered manually (or a future Ads API integration); LTV needs RevenueCat webhooks configured — both ₹0 until then, everything else here is live.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricTile(label: 'Daily active users', value: '${stats.dailyActiveUsers}'),
              _MetricTile(label: 'Monthly active users', value: '${stats.monthlyActiveUsers}'),
              _MetricTile(label: 'Premium conversion', value: '${growth.premiumConversionPct}%'),
              _MetricTile(label: 'Ad-Free conversion', value: '${growth.adFreeConversionPct}%'),
              _MetricTile(label: 'Monthly churn (est.)', value: '${growth.monthlyChurnPct}%'),
              _MetricTile(label: 'CAC', value: _inr.format(growth.cacInr)),
              _MetricTile(label: 'LTV', value: _inr.format(growth.ltvInr), highlight: true),
            ],
          ),
          const SizedBox(height: 24),
          _Card(title: 'Registration & conversion funnel', child: _FunnelChart(steps: funnel)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              final retentionCard = _Card(title: 'Retention curve', child: _RetentionChart(points: retention));
              final acquisitionCard = _Card(title: 'Acquisition source', child: _AcquisitionChart(sources: sources));
              if (!wide) return Column(children: [retentionCard, const SizedBox(height: 16), acquisitionCard]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: retentionCard),
                  const SizedBox(width: 16),
                  Expanded(child: acquisitionCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _MetricTile({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: highlight ? Colors.white : AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: highlight ? Colors.white70 : AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FunnelChart extends StatelessWidget {
  final List<FunnelStep> steps;
  const _FunnelChart({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final maxUsers = steps.first.users;
    // With real (not illustrative-mock) data, the first stage can
    // genuinely be 0 on a freshly-deployed project with no signups yet —
    // dividing by it would produce NaN/Infinity and break the progress
    // bars, so every ratio falls back to 0 instead.
    double ratio(int users) => maxUsers == 0 ? 0 : users / maxUsers;

    return Column(
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 140, child: Text(step.label, style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio(step.users),
                      minHeight: 20,
                      backgroundColor: Colors.grey.shade100,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${step.users} (${(ratio(step.users) * 100).round()}%)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RetentionChart extends StatelessWidget {
  final List<RetentionPoint> points;
  const _RetentionChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[index].label, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: points[i].retentionPct, color: AppColors.primary, width: 32, borderRadius: BorderRadius.circular(6)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _AcquisitionChart extends StatelessWidget {
  final List<AcquisitionSource> sources;
  const _AcquisitionChart({required this.sources});

  static const _colors = [AppColors.primary, Color(0xFF22C55E), Color(0xFFF59E0B), AppColors.textMuted];

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const Text(
        'Not tracked yet — needs install-referrer capture at sign-up (Play/App Store attribution APIs), which isn\'t wired in.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    final total = sources.fold<int>(0, (sum, s) => sum + s.users);
    return Column(
      children: [
        for (var i = 0; i < sources.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(sources[i].channel, style: const TextStyle(fontSize: 13))),
                Text(
                  '${sources[i].users} (${(sources[i].users / total * 100).round()}%)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
