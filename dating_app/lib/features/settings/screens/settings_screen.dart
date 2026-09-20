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
            onTap: () async {
              try {
                await ref.read(authRepositoryProvider).signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
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

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authRepositoryProvider);
    final needsPassword = auth.deletionNeedsPassword;
    // Grabbed before any await: deleting the account signs the user out
    // and the router replaces this screen, after which `context` is dead
    // — an error snackbar shown through it would silently never appear.
    final messenger = ScaffoldMessenger.of(context);

    // null = cancelled; otherwise the typed password ('' when not needed).
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteAccountDialog(needsPassword: needsPassword),
    );
    if (password == null) return;

    try {
      await auth.deleteAccount(password: needsPassword ? password : null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final bool needsPassword;
  const _DeleteAccountDialog({required this.needsPassword});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This permanently deletes your account, profile and photos. This cannot be undone.'),
          if (widget.needsPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm your password', border: OutlineInputBorder()),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, _password.text),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
