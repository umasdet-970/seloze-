import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/account_suspended_screen.dart';
import '../../features/auth/screens/age_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/chat/screens/chat_detail_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/likes/screens/likes_screen.dart';
import '../../features/matches/screens/matches_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/providers/onboarding_providers.dart';
import '../../features/onboarding/screens/create_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/blocked_users_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/privacy_settings_screen.dart';
import '../../features/settings/screens/security_settings_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/subscription/screens/paywall_screen.dart';
import '../../shared/widgets/main_nav_shell.dart';
import '../../data/models/profile.dart';
import '../../features/legal/screens/legal_document_screen.dart';
import '../constants/legal_content.dart';
import 'navigation_key.dart';

const _authRoutes = ['/login', '/signup', '/otp', '/forgot-password'];
const _tabRoutes = ['/discover', '/likes', '/matches', '/chat', '/profile'];

/// Accessible regardless of auth state — you should be able to read the
/// Terms/Privacy Policy before creating an account, not just after.
const _publicRoutes = ['/legal/terms', '/legal/privacy', '/legal/guidelines'];

/// Router is a provider (not a top-level const) so its `redirect` can read
/// live auth/profile state and `refreshListenable` can react to
/// sign-in/out, age verification, and profile completion — without the
/// app ever needing to navigate manually.
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final userProfileRepository = ref.watch(userProfileRepositoryProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream([
      authRepository.authStateChanges(),
      userProfileRepository.profileChanges(),
    ]),
    redirect: (context, state) {
      if (_publicRoutes.contains(state.matchedLocation)) return null;
      final user = authRepository.currentUser;
      final onAuthRoute = _authRoutes.contains(state.matchedLocation);
      final onAgeGate = state.matchedLocation == '/age-verify';
      final onProfileGate = state.matchedLocation == '/create-profile';
      final onSuspendedGate = state.matchedLocation == '/account-suspended';

      if (user == null) return onAuthRoute ? null : '/login';
      // Checked before age/profile gates — a suspended/banned user
      // shouldn't be routed through onboarding just because those
      // steps happen not to be complete yet.
      if (user.isSuspendedOrBanned) return onSuspendedGate ? null : '/account-suspended';
      if (!user.ageVerified) return onAgeGate ? null : '/age-verify';
      if (!userProfileRepository.hasCompletedProfile(user.uid)) {
        return onProfileGate ? null : '/create-profile';
      }
      if (onAuthRoute || onAgeGate || onProfileGate || onSuspendedGate) return '/discover';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/age-verify', builder: (context, state) => const AgeVerificationScreen()),
      GoRoute(path: '/account-suspended', builder: (context, state) => const AccountSuspendedScreen()),
      GoRoute(path: '/create-profile', builder: (context, state) => const CreateProfileScreen()),
      GoRoute(path: '/edit-profile', builder: (context, state) => const CreateProfileScreen()),
      GoRoute(path: '/paywall', builder: (context, state) => const PaywallScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/settings/notifications', builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(path: '/settings/privacy', builder: (context, state) => const PrivacySettingsScreen()),
      GoRoute(path: '/settings/blocked', builder: (context, state) => const BlockedUsersScreen()),
      GoRoute(path: '/settings/security', builder: (context, state) => const SecuritySettingsScreen()),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalDocumentScreen(title: 'Terms & Conditions', content: kTermsText),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalDocumentScreen(title: 'Privacy Policy', content: kPrivacyPolicyText),
      ),
      GoRoute(
        path: '/legal/guidelines',
        builder: (context, state) => const LegalDocumentScreen(title: 'Community Guidelines', content: kGuidelinesText),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatDetailScreen(
          conversationId: state.pathParameters['id']!,
          profile: state.extra as Profile?,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final index = _tabRoutes.indexOf(state.matchedLocation);
          return MainNavShell(currentIndex: index == -1 ? 0 : index, child: child);
        },
        routes: [
          GoRoute(path: '/discover', builder: (context, state) => const DiscoverScreen()),
          GoRoute(path: '/likes', builder: (context, state) => const LikesScreen()),
          GoRoute(path: '/matches', builder: (context, state) => const MatchesScreen()),
          GoRoute(path: '/chat', builder: (context, state) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

/// Bridges one or more Streams into a Listenable so GoRouter re-evaluates
/// `redirect` whenever auth or profile state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(List<Stream<dynamic>> streams) {
    notifyListeners();
    for (final stream in streams) {
      _subscriptions.add(stream.asBroadcastStream().listen((_) => notifyListeners()));
    }
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
