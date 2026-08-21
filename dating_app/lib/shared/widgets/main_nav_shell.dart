import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/likes/providers/likes_providers.dart';
import '../../features/matches/providers/matches_providers.dart';

/// Wraps the 5 tabs from spec section 22 (Discover / Likes / Matches /
/// Messages / Profile) with a bottom nav bar and badge counts.
class MainNavShell extends ConsumerWidget {
  final Widget child;
  final int currentIndex;

  const MainNavShell({super.key, required this.child, required this.currentIndex});

  static const _routes = ['/discover', '/likes', '/matches', '/chat', '/profile'];

  void _onTap(BuildContext context, int index) {
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real-time counts, not placeholders — a brand-new user with no likes
    // or matches yet correctly shows 0 on both badges.
    final likesCount = ref.watch(receivedLikesProvider).valueOrNull?.length ?? 0;
    final matchesCount = ref.watch(matchesProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
        items: [
          _navItem(Icons.explore_outlined, Icons.explore, 'Discover'),
          _badgedNavItem(Icons.favorite_border, Icons.favorite, 'Likes', count: likesCount),
          _badgedNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Matches', count: matchesCount),
          _navItem(Icons.forum_outlined, Icons.forum, 'Chat'),
          _navItem(Icons.person_outline, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData outline, IconData filled, String label) {
    return BottomNavigationBarItem(icon: Icon(outline), activeIcon: Icon(filled), label: label);
  }

  BottomNavigationBarItem _badgedNavItem(IconData outline, IconData filled, String label, {required int count}) {
    Widget withBadge(IconData icon) => Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          child: Icon(icon),
        );
    return BottomNavigationBarItem(icon: withBadge(outline), activeIcon: withBadge(filled), label: label);
  }
}
