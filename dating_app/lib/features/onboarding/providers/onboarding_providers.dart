import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../discover/providers/discover_providers.dart';

/// Swap MockUserProfileRepository() -> FirestoreUserProfileRepository()
/// once Firebase is wired in.
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return MockUserProfileRepository();
});

/// The signed-in user's own profile, re-fetched whenever it changes
/// (created, edited, or verification status updates).
final myProfileProvider = StreamProvider<Profile?>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(userProfileRepositoryProvider);
  if (uid.isEmpty) {
    yield null;
    return;
  }
  yield await repo.fetchMyProfile(uid);
  await for (final _ in repo.profileChanges()) {
    yield await repo.fetchMyProfile(uid);
  }
});
