import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/repositories/admin_auth_repository.dart';
import '../../../data/repositories/firebase/firebase_admin_auth_repository.dart';

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return kUseFirebase ? FirebaseAdminAuthRepository() : MockAdminAuthRepository();
});

final adminAuthStateProvider = StreamProvider<bool>((ref) async* {
  final repo = ref.watch(adminAuthRepositoryProvider);
  yield repo.isSignedIn;
  yield* repo.authStateChanges();
});
