import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../discover/providers/discover_providers.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: blockedAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text("You haven't blocked anyone", style: TextStyle(color: AppColors.textMuted)));
          }
          return ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey.shade300),
                  ),
                ),
                title: Text(profile.name),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(socialRepositoryProvider).unblock(ref.read(currentUserIdProvider), profile.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}
