import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/data/models/profile.dart';
import 'package:connect_dating_app/data/repositories/social_repository.dart';
import 'package:connect_dating_app/data/repositories/user_profile_repository.dart';
import 'package:connect_dating_app/features/discover/providers/discover_providers.dart';

Profile _profile(String id, {bool incognito = false, String city = '', String country = '', DateTime? boostedUntil}) {
  return Profile(
    id: id,
    name: id,
    age: 25,
    profession: '',
    company: '',
    education: '',
    bio: '',
    photoUrls: const [],
    interests: const [],
    distanceKm: 0,
    incognito: incognito,
    city: city,
    country: country,
    boostedUntil: boostedUntil,
  );
}

void main() {
  group('Profile.isBoosted', () {
    test('true for a future boostedUntil, false for null or a past one', () {
      expect(_profile('a').isBoosted, isFalse);
      expect(_profile('a', boostedUntil: DateTime.now().add(const Duration(minutes: 1))).isBoosted, isTrue);
      expect(_profile('a', boostedUntil: DateTime.now().subtract(const Duration(minutes: 1))).isBoosted, isFalse);
    });
  });

  group('excludeIncognito', () {
    test('hides an incognito profile from someone it never liked', () {
      final visible = _profile('a');
      final hidden = _profile('b', incognito: true);
      final result = excludeIncognito([visible, hidden], receivedFrom: {});
      expect(result.map((p) => p.id).toList(), ['a']);
    });

    test('still shows an incognito profile that already liked the viewer', () {
      final likedMe = _profile('b', incognito: true);
      final result = excludeIncognito([likedMe], receivedFrom: {'b'});
      expect(result.map((p) => p.id).toList(), ['b']);
    });

    test('non-incognito profiles are always shown', () {
      final profiles = [_profile('a'), _profile('b'), _profile('c')];
      expect(excludeIncognito(profiles, receivedFrom: {}), hasLength(3));
    });
  });

  group('applyPassportFilter', () {
    final mumbai = _profile('a', city: 'Mumbai', country: 'India');
    final tokyo = _profile('b', city: 'Tokyo', country: 'Japan');

    test('null/blank location returns everything unchanged', () {
      expect(applyPassportFilter([mumbai, tokyo], null), [mumbai, tokyo]);
      expect(applyPassportFilter([mumbai, tokyo], '  '), [mumbai, tokyo]);
    });

    test('matches by city, case-insensitively', () {
      expect(applyPassportFilter([mumbai, tokyo], 'mumbai').map((p) => p.id), ['a']);
    });

    test('matches by country too', () {
      expect(applyPassportFilter([mumbai, tokyo], 'Japan').map((p) => p.id), ['b']);
    });

    test('no match gives an empty list, not an error', () {
      expect(applyPassportFilter([mumbai, tokyo], 'Paris'), isEmpty);
    });
  });

  group('sortBoostedFirst', () {
    test('boosted profiles come first, each group keeping its order', () {
      final future = DateTime.now().add(const Duration(minutes: 10));
      final a = _profile('a');
      final b = _profile('b', boostedUntil: future);
      final c = _profile('c');
      final d = _profile('d', boostedUntil: future);

      expect(sortBoostedFirst([a, b, c, d]).map((p) => p.id).toList(), ['b', 'd', 'a', 'c']);
    });

    test('an expired boost does not count as boosted (order is unchanged, not moved to front)', () {
      final past = DateTime.now().subtract(const Duration(minutes: 10));
      final a = _profile('a');
      final expired = _profile('b', boostedUntil: past);
      expect(sortBoostedFirst([expired, a]).map((p) => p.id).toList(), ['b', 'a']);
    });

    test('nothing boosted keeps the original order', () {
      final profiles = [_profile('a'), _profile('b'), _profile('c')];
      expect(sortBoostedFirst(profiles), profiles);
    });
  });

  group('MockSocialRepository.undoSwipe (Rewind)', () {
    test('undoes a pass — the target is no longer in swipedIds', () async {
      final social = MockSocialRepository();
      await social.pass('alice', 'bob');
      expect(social.swipedIds('alice'), contains('bob'));
      await social.undoSwipe('alice', 'bob');
      expect(social.swipedIds('alice'), isNot(contains('bob')));
    });

    test('undoes a like that had not matched — removes the pending like too', () async {
      final social = MockSocialRepository();
      await social.like('alice', 'bob');
      expect(social.swipedIds('alice'), contains('bob'));
      expect(social.receivedLikeIds('bob'), contains('alice'));

      await social.undoSwipe('alice', 'bob');
      expect(social.swipedIds('alice'), isNot(contains('bob')));
      expect(social.receivedLikeIds('bob'), isNot(contains('alice')));
    });
  });

  group('MockUserProfileRepository Boost/Incognito', () {
    test('activateBoost sets a future boostedUntil; activeBoostUntil reflects it', () async {
      final repo = MockUserProfileRepository();
      await repo.saveProfile('alice', _profile('alice'));
      expect(repo.activeBoostUntil('alice'), isNull);

      await repo.activateBoost('alice', duration: const Duration(minutes: 30));
      final until = repo.activeBoostUntil('alice');
      expect(until, isNotNull);
      expect(until!.isAfter(DateTime.now()), isTrue);
    });

    test('setIncognito flips the flag on the stored profile', () async {
      final repo = MockUserProfileRepository();
      await repo.saveProfile('alice', _profile('alice'));
      expect((await repo.fetchMyProfile('alice'))!.incognito, isFalse);

      await repo.setIncognito('alice', true);
      expect((await repo.fetchMyProfile('alice'))!.incognito, isTrue);
    });
  });
}
