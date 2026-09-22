import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/models/call_models.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/repositories/firebase/firestore_call_repository.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return kUseFirebase ? FirestoreCallRepository() : MockCallRepository();
});

final _callTickProvider = StreamProvider<void>((ref) => ref.watch(callRepositoryProvider).changes());

/// The current call (if any) on a conversation — ringing, accepted, or
/// its terminal state right after ending. Used both by ChatDetailScreen
/// (to show an incoming-call banner) and CallScreen (to drive its state
/// machine).
final currentCallProvider = Provider.family<CallInvite?, String>((ref, conversationId) {
  ref.watch(_callTickProvider);
  return ref.watch(callRepositoryProvider).currentCall(conversationId);
});
