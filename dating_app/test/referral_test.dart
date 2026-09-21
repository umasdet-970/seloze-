import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/core/config/referral_config.dart';
import 'package:connect_dating_app/data/models/app_user.dart';
import 'package:connect_dating_app/data/repositories/auth_repository.dart';
import 'package:connect_dating_app/data/repositories/firebase/acquisition_source_service.dart';
import 'package:connect_dating_app/features/auth/providers/auth_providers.dart';
import 'package:connect_dating_app/features/referrals/providers/referral_providers.dart';
import 'package:connect_dating_app/features/referrals/widgets/invite_friends_card.dart';
import 'package:connect_dating_app/features/subscription/providers/subscription_providers.dart';

void main() {
  group('referralBonus', () {
    test('is 5 discoveries a day per friend', () {
      expect(referralBonus(0), 0);
      expect(referralBonus(1), 5);
      expect(referralBonus(3), 15);
    });

    test('is capped at $kMaxRewardedFriends friends', () {
      expect(referralBonus(kMaxRewardedFriends), kMaxRewardedFriends * kBonusDiscoveriesPerFriend);
      expect(referralBonus(50), kMaxRewardedFriends * kBonusDiscoveriesPerFriend);
    });

    test('never goes negative', () {
      expect(referralBonus(-3), 0);
    });
  });

  group('invite link <-> install referrer round trip', () {
    const uid = 'AbC123xyz789QWERTYuiop45';

    test('the link carries the inviter in the Play referrer parameter', () {
      final link = Uri.parse(buildInviteLink(uid));
      expect(link.host, 'play.google.com');
      expect(link.queryParameters['id'], kPlayStorePackage);
      // What Google's Install Referrer API hands the app on first launch:
      final referrer = link.queryParameters['referrer']!;
      expect(referrer, 'utm_source=invite&utm_content=$uid');
    });

    test('an invited install is attributed to the inviter', () {
      final referrer = Uri.parse(buildInviteLink(uid)).queryParameters['referrer'];
      final attribution = AcquisitionSourceService.parseReferrer(referrer);
      expect(attribution.source, 'Friend invite');
      expect(attribution.inviterUid, uid);
    });

    test('ordinary ad / organic installs have no inviter', () {
      expect(AcquisitionSourceService.parseReferrer('utm_source=google_ads').inviterUid, isNull);
      expect(AcquisitionSourceService.parseReferrer('utm_source=google_ads').source, 'Google Ads');
      expect(AcquisitionSourceService.parseReferrer(null).source, 'Organic/Direct');
      expect(AcquisitionSourceService.parseReferrer('').inviterUid, isNull);
    });

    test('a malformed or hostile inviter value is ignored, not stored', () {
      for (final bad in ['', 'x', 'has space in it', 'a/b/c/../../users', 'a' * 200, '../../etc']) {
        final a = AcquisitionSourceService.parseReferrer(
          'utm_source=invite&utm_content=${Uri.encodeQueryComponent(bad)}',
        );
        expect(a.source, 'Friend invite', reason: bad);
        expect(a.inviterUid, isNull, reason: 'should reject "$bad"');
      }
    });

    test('an invite link with no inviter is still just a Friend invite', () {
      final a = AcquisitionSourceService.parseReferrer('utm_source=invite');
      expect(a.source, 'Friend invite');
      expect(a.inviterUid, isNull);
    });
  });

  group('daily discovery limit', () {
    ProviderContainer containerWithFriends(int friends) {
      return ProviderContainer(overrides: [referralCountProvider.overrideWith((ref) => Stream.value(friends))]);
    }

    test('is the plain free limit (10) with no invited friends', () async {
      final c = containerWithFriends(0);
      addTearDown(c.dispose);
      await c.read(referralCountProvider.future);
      expect(c.read(dailyDiscoveryLimitProvider), 10);
    });

    test('grows by 5 for each invited friend', () async {
      final c = containerWithFriends(2);
      addTearDown(c.dispose);
      await c.read(referralCountProvider.future);
      expect(c.read(dailyDiscoveryLimitProvider), 20);
    });

    test('stops growing at the cap', () async {
      final c = containerWithFriends(40);
      addTearDown(c.dispose);
      await c.read(referralCountProvider.future);
      expect(c.read(dailyDiscoveryLimitProvider), 10 + kMaxRewardedFriends * kBonusDiscoveriesPerFriend);
    });
  });

  group('InviteFriendsCard', () {
    Future<List<String>> pumpCard(WidgetTester tester, {required int friends, String uid = 'uid1234567'}) async {
      final shared = <String>[];
      final auth = _SignedInAuth(uid);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            referralCountProvider.overrideWith((ref) => Stream.value(friends)),
            inviteSharerProvider.overrideWithValue((text) async => shared.add(text)),
          ],
          child: const MaterialApp(home: Scaffold(body: InviteFriendsCard())),
        ),
      );
      await tester.pumpAndSettle();
      return shared;
    }

    testWidgets('shows what each friend is worth and the current progress', (tester) async {
      await pumpCard(tester, friends: 2);
      expect(find.textContaining('+5 discoveries a day for each friend'), findsOneWidget);
      expect(find.text('2 of 5 friends joined · +10 a day so far'), findsOneWidget);
    });

    testWidgets('Invite friends shares a message containing this user\'s personal link', (tester) async {
      final shared = await pumpCard(tester, friends: 0, uid: 'uid1234567');
      await tester.tap(find.text('Invite friends'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single, contains('play.google.com'));
      expect(shared.single, contains(Uri.encodeComponent('utm_content=uid1234567')));
    });

    testWidgets('hides the share button once the maximum bonus is unlocked', (tester) async {
      await pumpCard(tester, friends: 7);
      expect(find.text('Invite friends'), findsNothing);
      expect(find.textContaining('All 5 friends joined'), findsOneWidget);
    });
  });
}

/// Auth repo that reports a signed-in user, so `currentUserIdProvider` has a uid.
class _SignedInAuth extends MockAuthRepository {
  _SignedInAuth(this.uid);
  final String uid;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(AppUser(uid: uid, email: 'a@b.c'));

  @override
  AppUser? get currentUser => AppUser(uid: uid, email: 'a@b.c');
}
