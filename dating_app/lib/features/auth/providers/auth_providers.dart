import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';

/// Swap MockAuthRepository() -> FirebaseAuthRepository() once a real
/// Firebase project exists. Nothing else in the app needs to change.
final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository());

/// Reactive stream of the signed-in user, driving both the router redirect
/// and any screen that needs to know who's logged in.
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
