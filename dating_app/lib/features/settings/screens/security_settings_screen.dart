import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _sending = false;

  Future<void> _sendPasswordReset() async {
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset is only available for email accounts.')),
      );
      return;
    }
    setState(() => _sending = true);
    await ref.read(authRepositoryProvider).sendPasswordResetEmail(user!.email!);
    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to ${user.email}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Security settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Change password'),
            subtitle: Text(user?.email ?? 'Not available for phone/social accounts'),
            trailing: _sending
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: _sending ? null : _sendPasswordReset,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.devices_outlined),
            title: Text('Active sessions'),
            subtitle: Text('Session management requires a live backend — coming with Firebase Auth.'),
          ),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Sign-in alerts'),
            subtitle: Text("We'll notify you of new sign-ins — see Notifications."),
          ),
        ],
      ),
    );
  }
}
