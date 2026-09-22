import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/stream_safety.dart';
import '../wallet_repository.dart';

/// Firestore schema: `users/{uid}/private/wallet` `{balance: int}`.
class FirestoreWalletRepository implements WalletRepository {
  FirestoreWalletRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _controller = StreamController<void>.broadcast();
  final Map<String, int> _balanceCache = {};
  final Set<String> _listening = {};

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid).collection('private').doc('wallet');

  void _ensureListening(String uid) {
    if (_listening.contains(uid)) return;
    _listening.add(uid);
    _doc(uid).snapshots().listenSafely((doc) {
      _balanceCache[uid] = (doc.data()?['balance'] as num?)?.toInt() ?? 0;
      _controller.add(null);
    });
  }

  @override
  Stream<void> changes() => _controller.stream;

  @override
  int balance(String uid) {
    _ensureListening(uid);
    return _balanceCache[uid] ?? 0;
  }

  @override
  Future<void> credit(String uid, int amount, {required String reason}) async {
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(_doc(uid));
      final current = (snap.data()?['balance'] as num?)?.toInt() ?? 0;
      transaction.set(_doc(uid), {'balance': current + amount}, SetOptions(merge: true));
    });
  }

  @override
  Future<void> debit(String uid, int amount, {required String reason}) async {
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(_doc(uid));
      final current = (snap.data()?['balance'] as num?)?.toInt() ?? 0;
      if (current < amount) throw InsufficientCoinsException(balance: current, needed: amount);
      transaction.set(_doc(uid), {'balance': current - amount}, SetOptions(merge: true));
    });
  }
}
