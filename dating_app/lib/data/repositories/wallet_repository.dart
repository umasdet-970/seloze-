import 'dart:async';

/// Thrown by [WalletRepository.debit] when [uid] doesn't have enough coins
/// — callers should check [WalletRepository.balance] before offering a
/// spend action, so this is mainly a defense against a stale UI (balance
/// changed between render and tap) rather than the primary gate.
class InsufficientCoinsException implements Exception {
  final int balance;
  final int needed;
  const InsufficientCoinsException({required this.balance, required this.needed});

  @override
  String toString() => "You have $balance coins, but this costs $needed.";
}

/// The coins/credits economy (spec: Badoo-style Superpowers — see
/// core/config/wallet_config.dart). Owner-writable, same trust model as
/// the discovery quota/ad-bonus/rose-count docs elsewhere in this app
/// (documented there too): a modified client could inflate its own
/// balance. Kept consistent with those rather than singled out for
/// server-only writes, since a coin balance here only ever buys
/// visibility perks (Boost/Rose), not real money or anything
/// irreversible — a materially smaller risk than e.g. the referral
/// `rewards` doc, which stays server-only for exactly that reason.
abstract class WalletRepository {
  Stream<void> changes();
  int balance(String uid);
  Future<void> credit(String uid, int amount, {required String reason});
  /// Throws [InsufficientCoinsException] if [uid] has fewer than [amount]
  /// coins. Never goes negative.
  Future<void> debit(String uid, int amount, {required String reason});
}

class MockWalletRepository implements WalletRepository {
  final _controller = StreamController<void>.broadcast();
  final Map<String, int> _balances = {};

  @override
  Stream<void> changes() => _controller.stream;

  @override
  int balance(String uid) => _balances[uid] ?? 0;

  @override
  Future<void> credit(String uid, int amount, {required String reason}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _balances[uid] = balance(uid) + amount;
    _controller.add(null);
  }

  @override
  Future<void> debit(String uid, int amount, {required String reason}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final current = balance(uid);
    if (current < amount) throw InsufficientCoinsException(balance: current, needed: amount);
    _balances[uid] = current - amount;
    _controller.add(null);
  }
}
