import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/auth/providers/admin_auth_providers.dart';
import '../../features/auth/screens/admin_login_screen.dart';
import '../../features/dashboard/screens/overview_screen.dart';
import '../../features/moderation/screens/moderation_screen.dart';
import '../../features/subscriptions/screens/subscriptions_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../shared/widgets/admin_shell.dart';

const _tabRoutes = ['/', '/users', '/moderation', '/subscriptions', '/analytics'];

final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(adminAuthRepositoryProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges()),
    redirect: (context, state) {
      final signedIn = authRepository.isSignedIn;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          final index = _tabRoutes.indexOf(state.matchedLocation);
          return AdminShell(currentIndex: index == -1 ? 0 : index, child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const OverviewScreen()),
          GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
          GoRoute(path: '/moderation', builder: (context, state) => const ModerationScreen()),
          GoRoute(path: '/subscriptions', builder: (context, state) => const SubscriptionsScreen()),
          GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
