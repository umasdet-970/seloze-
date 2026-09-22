import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/repositories/firebase/firestore_wallet_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../discover/providers/discover_providers.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return kUseFirebase ? FirestoreWalletRepository() : MockWalletRepository();
});

final _walletTickProvider = StreamProvider<void>((ref) => ref.watch(walletRepositoryProvider).changes());

/// The signed-in user's coin balance (see core/config/wallet_config.dart).
final coinBalanceProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid.isEmpty) return 0;
  final wallet = ref.watch(walletRepositoryProvider);
  ref.watch(_walletTickProvider);
  return wallet.balance(uid);
});
