import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/core/config/ad_config.dart';
import 'package:connect_dating_app/data/repositories/social_repository.dart';

void main() {
  group('rewarded-ad discovery bonus (MockSocialRepository)', () {
    test('starts at 0 for a user who has never watched an ad', () {
      final social = MockSocialRepository();
      expect(social.adBonusUsedToday('alice'), 0);
    });

    test('each earned reward adds 1, up to $kMaxAdBonusPerDay a day', () {
      final social = MockSocialRepository();
      for (var i = 0; i < kMaxAdBonusPerDay; i++) {
        social.recordAdBonusEarned('alice');
        expect(social.adBonusUsedToday('alice'), i + 1);
      }
    });

    test('stops crediting once the daily cap is reached', () {
      final social = MockSocialRepository();
      for (var i = 0; i < kMaxAdBonusPerDay + 5; i++) {
        social.recordAdBonusEarned('alice');
      }
      expect(social.adBonusUsedToday('alice'), kMaxAdBonusPerDay);
    });

    test("one user's ad bonus doesn't affect another's", () {
      final social = MockSocialRepository();
      social.recordAdBonusEarned('alice');
      social.recordAdBonusEarned('alice');
      expect(social.adBonusUsedToday('alice'), 2);
      expect(social.adBonusUsedToday('bob'), 0);
    });

    test('notifies listeners so the Discover feed refreshes after earning a bonus', () async {
      final social = MockSocialRepository();
      final events = <void>[];
      final sub = social.changes().listen(events.add);
      social.recordAdBonusEarned('alice');
      await Future<void>.delayed(Duration.zero);
      expect(events, isNotEmpty);
      await sub.cancel();
    });
  });
}
