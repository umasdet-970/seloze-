import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../admin/providers/admin_providers.dart';

/// User search & management (spec section 16): search, verify, warn,
/// suspend, ban.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userSearchResultsProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Users', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${users.length} users', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
            ),
            onChanged: (v) => ref.read(userSearchQueryProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: users.isEmpty
                  ? const Center(child: Text('No users match your search', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) => _UserRow(user: users[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  final AdminUser user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.12), child: Text(user.name[0], style: const TextStyle(color: AppColors.primary))),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (user.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: AppColors.primary),
                    ],
                  ],
                ),
                Text(user.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Expanded(child: Text(user.country, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(DateFormat('d MMM y').format(user.joinedAt), style: const TextStyle(fontSize: 12))),
          Expanded(child: TierBadge(tier: user.tier)),
          Expanded(child: StatusBadge(status: user.status)),
          PopupMenuButton<String>(
            onSelected: (action) => _handle(ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'verify', child: Text(user.isVerified ? 'Remove verification' : 'Verify profile')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'active', child: Text('Set active')),
              const PopupMenuItem(value: 'warned', child: Text('Warn')),
              const PopupMenuItem(value: 'suspended', child: Text('Suspend')),
              const PopupMenuItem(value: 'banned', child: Text('Ban')),
            ],
          ),
        ],
      ),
    );
  }

  void _handle(WidgetRef ref, String action) {
    final repo = ref.read(adminRepositoryProvider);
    switch (action) {
      case 'verify':
        repo.setVerified(user.id, !user.isVerified);
        break;
      case 'active':
        repo.setUserStatus(user.id, AccountStatus.active);
        break;
      case 'warned':
        repo.setUserStatus(user.id, AccountStatus.warned);
        break;
      case 'suspended':
        repo.setUserStatus(user.id, AccountStatus.suspended);
        break;
      case 'banned':
        repo.setUserStatus(user.id, AccountStatus.banned);
        break;
    }
  }
}
