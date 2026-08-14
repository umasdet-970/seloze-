import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';

/// Settings hub (spec section 14). Discovery/location preferences live in
/// the Edit Profile wizard (step 3) rather than a separate screen, since
/// they're the same data the onboarding flow already collects.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _tile(context, icon: Icons.edit_outlined, label: 'Edit profile', onTap: () => context.push('/edit-profile')),
          _tile(context, icon: Icons.notifications_outlined, label: 'Notification settings',
              onTap: () => context.push('/settings/notifications')),
          _tile(context, icon: Icons.lock_outline, label: 'Privacy settings', onTap: () => context.push('/settings/privacy')),
          _tile(context, icon: Icons.block, label: 'Blocked users', onTap: () => context.push('/settings/blocked')),
          _tile(context, icon: Icons.security, label: 'Security settings', onTap: () => context.push('/settings/security')),
          _tile(context, icon: Icons.workspace_premium_outlined, label: 'Subscription', onTap: () => context.push('/paywall')),
          const Divider(height: 32),
          _tile(context, icon: Icons.description_outlined, label: 'Terms & Conditions', onTap: () => context.push('/legal/terms')),
          _tile(context, icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => context.push('/legal/privacy')),
          const Divider(height: 32),
          _tile(
            context,
            icon: Icons.logout,
            label: 'Log out',
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          _tile(
            context,
            icon: Icons.delete_outline,
            label: 'Delete account',
            iconColor: Colors.red,
            labelColor: Colors.red,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? labelColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textDark),
      title: Text(label, style: TextStyle(color: labelColor)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?'),
        content: const Text('This permanently deletes your account. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(authRepositoryProvider).deleteAccount();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
