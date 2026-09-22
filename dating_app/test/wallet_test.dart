import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/data/repositories/wallet_repository.dart';

void main() {
  group('MockWalletRepository', () {
    test('starts at 0 for a new user', () {
      final wallet = MockWalletRepository();
      expect(wallet.balance('alice'), 0);
    });

    test('credit increases the balance', () async {
      final wallet = MockWalletRepository();
      await wallet.credit('alice', 30, reason: 'referral');
      await wallet.credit('alice', 20, reason: 'welcome');
      expect(wallet.balance('alice'), 50);
    });

    test('debit decreases the balance when there is enough', () async {
      final wallet = MockWalletRepository();
      await wallet.credit('alice', 100, reason: 'welcome');
      await wallet.debit('alice', 50, reason: 'boost');
      expect(wallet.balance('alice'), 50);
    });

    test('debit throws and leaves the balance unchanged when insufficient', () async {
      final wallet = MockWalletRepository();
      await wallet.credit('alice', 10, reason: 'welcome');
      await expectLater(
        wallet.debit('alice', 50, reason: 'boost'),
        throwsA(isA<InsufficientCoinsException>()),
      );
      expect(wallet.balance('alice'), 10);
    });

    test("one user's balance is independent of another's", () async {
      final wallet = MockWalletRepository();
      await wallet.credit('alice', 100, reason: 'welcome');
      expect(wallet.balance('bob'), 0);
    });

    test('InsufficientCoinsException carries the actual numbers', () async {
      final wallet = MockWalletRepository();
      await wallet.credit('alice', 10, reason: 'welcome');
      try {
        await wallet.debit('alice', 50, reason: 'boost');
        fail('expected InsufficientCoinsException');
      } on InsufficientCoinsException catch (e) {
        expect(e.balance, 10);
        expect(e.needed, 50);
      }
    });
  });
}
