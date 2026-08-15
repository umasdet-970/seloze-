import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/admin_auth_providers.dart';

/// Persistent sidebar nav — the desktop-appropriate equivalent of the
/// mobile app's bottom nav shell.
class AdminShell extends ConsumerWidget {
  final Widget child;
  final int currentIndex;

  const AdminShell({super.key, required this.child, required this.currentIndex});

  static const _routes = ['/', '/users', '/moderation', '/subscriptions', '/analytics', '/audit-log'];
  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
    (Icons.people_outline, Icons.people, 'Users'),
    (Icons.flag_outlined, Icons.flag, 'Reports & Moderation'),
    (Icons.workspace_premium_outlined, Icons.workspace_premium, 'Subscriptions'),
    (Icons.insights_outlined, Icons.insights, 'Analytics'),
    (Icons.history_outlined, Icons.history, 'Audit Log'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: AppColors.sidebar,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Row(
                      children: [
                        Icon(Icons.favorite, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'Connect Admin',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < _items.length; i++) _navItem(context, i),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.white70),
                        title: const Text('Log out', style: TextStyle(color: Colors.white70)),
                        onTap: () => ref.read(adminAuthRepositoryProvider).signOut(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index) {
    final selected = index == currentIndex;
    final (outline, filled, label) = _items[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(selected ? filled : outline, color: selected ? Colors.white : Colors.white60, size: 20),
          title: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 13)),
          onTap: () => context.go(_routes[index]),
        ),
      ),
    );
  }
}
