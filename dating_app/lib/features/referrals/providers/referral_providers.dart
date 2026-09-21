import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/config/referral_config.dart';
import '../../discover/providers/discover_providers.dart';

/// How many invited friends have joined (completed their profile). Read-only
/// on the client: `users/{uid}/private/rewards.referralCount` is written by
/// the creditReferralOnProfileComplete Cloud Function only (firestore.rules
/// blocks client writes), so it can't be faked.
final referralCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (!kUseFirebase || uid.isEmpty) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('rewards')
      .snapshots()
      .map((doc) => (doc.data()?['referralCount'] as num?)?.toInt() ?? 0);
});

/// Extra daily discoveries earned from invites (0 until the count loads).
final referralBonusProvider = Provider<int>((ref) {
  return referralBonus(ref.watch(referralCountProvider).valueOrNull ?? 0);
});

/// Opens the system share sheet. A provider so tests can swap it out.
final inviteSharerProvider = Provider<Future<void> Function(String text)>((ref) {
  return (text) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Join me on Seloze'));
  };
});
