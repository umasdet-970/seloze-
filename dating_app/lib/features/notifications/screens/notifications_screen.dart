import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_item.dart';
import '../../discover/providers/discover_providers.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllRead(ref.read(currentUserIdProvider));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications yet', style: TextStyle(color: AppColors.textMuted)))
          : ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return ListTile(
                  tileColor: n.read ? null : AppColors.primary.withValues(alpha: 0.05),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Icon(n.type.icon, color: AppColors.primary, size: 20),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body, style: const TextStyle(fontSize: 12)),
                  trailing: Text(_relativeTime(n.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  onTap: () async {
                    try {
                      await ref.read(notificationRepositoryProvider).markRead(ref.read(currentUserIdProvider), n.id);
                    } catch (_) {
                      // Non-critical — still navigate even if marking
                      // read failed, rather than leaving the tap dead.
                    }
                    final route = n.type.route;
                    if (route != null && context.mounted) context.push(route);
                  },
                );
              },
            ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
