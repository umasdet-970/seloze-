import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../admin/providers/admin_providers.dart';

/// Reports & Moderation queue (spec section 11-12): review reports, act
/// with Warning / Suspension / Permanent ban escalation.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportQueueProvider);
    final pending = reports.where((r) => r.status == ReportStatus.pending).toList();
    final resolved = reports.where((r) => r.status == ReportStatus.resolved).toList();
    final flagged = ref.watch(flaggedProfilesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reports & Moderation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${pending.length} pending review', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          for (final r in pending) _ReportCard(report: r),
          if (resolved.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Resolved', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            for (final r in resolved) _ReportCard(report: r),
          ],
          const SizedBox(height: 32),
          const Text('Flagged profiles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Automated suspicious-profile detection — no one reported these, '
            'the signals below were computed when the profile was saved.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text('${flagged.length} awaiting review', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (flagged.isEmpty)
            const Text('Nothing flagged right now.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final u in flagged) _FlaggedProfileCard(user: u),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final ReportQueueItem report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = report.status == ReportStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isPending ? AppColors.warning.withOpacity(0.4) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(text: report.reporterName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' reported '),
                      TextSpan(text: report.target.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              StatusBadge(status: report.target.status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(report.reason, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
              if (report.target.reportCount > 1)
                Chip(
                  label: Text('${report.target.reportCount} total reports', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.danger.withOpacity(0.08),
                ),
            ],
          ),
          if (report.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(report.details, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 12),
          if (isPending)
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => ref.read(adminRepositoryProvider).resolveReport(report.id, ModerationAction.dismissed),
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                  onPressed: () => ref.read(adminRepositoryProvider).resolveReport(report.id, ModerationAction.warning),
                  child: const Text('Warn'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  onPressed: () => ref.read(adminRepositoryProvider).resolveReport(report.id, ModerationAction.suspension),
                  child: const Text('Suspend'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => ref.read(adminRepositoryProvider).resolveReport(report.id, ModerationAction.ban),
                  child: const Text('Ban'),
                ),
              ],
            )
          else
            Text('Action: ${report.actionTaken?.label ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FlaggedProfileCard extends ConsumerWidget {
  final AdminUser user;
  const _FlaggedProfileCard({required this.user});

  Color _riskColor() {
    if (user.riskScore >= 50) return AppColors.danger;
    if (user.riskScore >= 25) return AppColors.warning;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _riskColor().withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _riskColor().withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Risk ${user.riskScore}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _riskColor()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (user.riskSignals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: user.riskSignals
                  .map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => ref.read(adminRepositoryProvider).setVerified(user.id, true),
                child: const Text('Verify (legitimate)'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                onPressed: () => ref.read(adminRepositoryProvider).setUserStatus(user.id, AccountStatus.suspended),
                child: const Text('Suspend'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => ref.read(adminRepositoryProvider).setUserStatus(user.id, AccountStatus.banned),
                child: const Text('Ban'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
