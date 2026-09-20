import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/support_config.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

/// Shown instead of the app when an admin has set the signed-in user's
/// account to `suspended` or `banned` (spec section 11/12: safety
/// escalation). The user stays authenticated with Firebase — this screen
/// just blocks the router from reaching any other route — so they can
/// still explicitly sign out, but can't swipe past this to Discover.
class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authStateChangesProvider).valueOrNull?.accountStatus ?? 'suspended';
    final banned = status == 'banned';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 24),
                Text(
                  banned ? 'Account banned' : 'Account suspended',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  banned
                      ? 'Your account has been permanently banned for violating our community guidelines.'
                      : 'Your account has been temporarily suspended for violating our community guidelines.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If you think this is a mistake, contact support at $kSupportEmail.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                    } catch (e) {
                      // This screen is a dead end otherwise — signing out
                      // is the only way off it, so a silent failure here
                      // would leave someone stuck with no indication the
                      // button didn't work.
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
