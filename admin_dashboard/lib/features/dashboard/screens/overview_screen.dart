import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../admin/providers/admin_providers.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Overview / KPI dashboard (spec section 16-17): totals, active users,
/// registrations, tier split, revenue trend, top countries.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final revenue = ref.watch(revenueTrendProvider);
    final countries = ref.watch(countryStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Live snapshot across the platform', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(label: 'Total users', value: '${stats.totalUsers}', icon: Icons.people_outline),
              _StatCard(label: 'Daily active users', value: '${stats.dailyActiveUsers}', icon: Icons.bolt_outlined),
              _StatCard(label: 'New today', value: '${stats.newRegistrationsToday}', icon: Icons.person_add_alt_outlined),
              _StatCard(label: 'Matches', value: '${stats.totalMatches}', icon: Icons.favorite_outline),
              _StatCard(label: 'Messages', value: '${stats.totalMessages}', icon: Icons.chat_bubble_outline),
              _StatCard(
                label: 'Monthly revenue',
                value: _inr.format(stats.monthlyRevenueInr),
                icon: Icons.currency_rupee,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              final revenueCard = _ChartCard(title: '14-day revenue trend', child: _RevenueChart(points: revenue));
              final tierCard = _ChartCard(title: 'Users by tier', child: _TierChart(stats: stats));
              if (!wide) {
                return Column(children: [revenueCard, const SizedBox(height: 16), tierCard]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: revenueCard),
                  const SizedBox(width: 16),
                  Expanded(child: tierCard),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _ChartCard(title: 'Country-wise stats', child: _CountryTable(countries: countries)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _StatCard({required this.label, required this.value, required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? Colors.white : AppColors.primary, size: 20),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: highlight ? Colors.white : AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: highlight ? Colors.white70 : AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
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

class _RevenueChart extends StatelessWidget {
  final List<RevenuePoint> points;
  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('d MMM').format(points[index].date), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].amountInr)],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChart extends StatelessWidget {
  final DashboardStats stats;
  const _TierChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.freeUsers + stats.premiumUsers + stats.adFreeUsers;
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                PieChartSectionData(value: stats.freeUsers.toDouble(), color: AppColors.textMuted, title: '', radius: 40),
                PieChartSectionData(value: stats.premiumUsers.toDouble(), color: AppColors.primary, title: '', radius: 40),
                PieChartSectionData(value: stats.adFreeUsers.toDouble(), color: AppColors.warning, title: '', radius: 40),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _legendRow('Free', stats.freeUsers, total, AppColors.textMuted),
        _legendRow('Premium', stats.premiumUsers, total, AppColors.primary),
        _legendRow('Ad-Free', stats.adFreeUsers, total, AppColors.warning),
      ],
    );
  }

  Widget _legendRow(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0 : (value / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text('$value ($pct%)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _CountryTable extends StatelessWidget {
  final List<CountryStat> countries;
  const _CountryTable({required this.countries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(flex: 2, child: Text('Country', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Expanded(child: Text('Users', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Expanded(child: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          ],
        ),
        const Divider(),
        for (final c in countries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(c.country, style: const TextStyle(fontSize: 13))),
                Expanded(child: Text('${c.users}', style: const TextStyle(fontSize: 13))),
                Expanded(child: Text(_inr.format(c.revenueInr), style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}
