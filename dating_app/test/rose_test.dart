import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/core/config/rose_config.dart';
import 'package:connect_dating_app/data/models/subscription_models.dart';
import 'package:connect_dating_app/data/repositories/social_repository.dart';

void main() {
  group('roseLimitFor', () {
    test('free tier gets 1 a day, Premium gets 3', () {
      expect(roseLimitFor(SubscriptionTier.free), 1);
      expect(roseLimitFor(SubscriptionTier.adFree), 1);
      expect(roseLimitFor(SubscriptionTier.premium), 3);
    });
  });

  group('MockSocialRepository.sendRose', () {
    test('reveals the sender: the receiver sees them in roseSenderIds', () async {
      final social = MockSocialRepository();
      await social.sendRose('alice', 'bob');
      expect(social.roseSenderIds('bob'), contains('alice'));
      expect(social.receivedLikeIds('bob'), contains('alice'));
    });

    test('counts against the sender\'s daily quota', () async {
      final social = MockSocialRepository();
      expect(social.roseUsedToday('alice'), 0);
      await social.sendRose('alice', 'bob');
      expect(social.roseUsedToday('alice'), 1);
      await social.sendRose('alice', 'carol');
      expect(social.roseUsedToday('alice'), 2);
    });

    test('an instant match (they already liked you) does not spend a rose', () async {
      final social = MockSocialRepository();
      await social.like('bob', 'alice'); // bob likes alice first
      final result = await social.sendRose('alice', 'bob'); // alice roses bob back
      expect(result.matched, isTrue);
      expect(social.roseUsedToday('alice'), 0);
    });

    test('a plain like from someone else does not show up as a rose', () async {
      final social = MockSocialRepository();
      await social.like('dave', 'bob');
      expect(social.roseSenderIds('bob'), isNot(contains('dave')));
      expect(social.receivedLikeIds('bob'), contains('dave'));
    });
  });
}
