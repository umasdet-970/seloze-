import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/admin_auth_repository.dart';

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) => MockAdminAuthRepository());

final adminAuthStateProvider = StreamProvider<bool>((ref) async* {
  final repo = ref.watch(adminAuthRepositoryProvider);
  yield repo.isSignedIn;
  yield* repo.authStateChanges();
});
