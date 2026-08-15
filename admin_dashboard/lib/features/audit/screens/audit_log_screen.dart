import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../admin/providers/admin_providers.dart';

/// Audit log (spec section 20): who did what, and when. Read-only —
/// entries are written automatically by AdminRepository whenever a
/// moderation action runs, never edited or deleted from here.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditLogProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Audit Log', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'A record of every moderation action taken from this dashboard — who, what, and when.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            const Text('No actions recorded yet.', style: TextStyle(color: AppColors.textMuted))
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) _AuditRow(entry: entries[i], showDivider: i > 0),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final AuditLogEntry entry;
  final bool showDivider;
  const _AuditRow({required this.entry, required this.showDivider});

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider) const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 13),
                        children: [
                          TextSpan(text: entry.adminEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' — '),
                          TextSpan(text: entry.action),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${entry.targetUserName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    if (entry.details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(entry.details, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              Text(_formatTime(entry.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
