import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/data/models/profile.dart';
import 'package:connect_dating_app/features/discover/providers/discover_providers.dart';

Profile _profile(
  String id, {
  bool verified = false,
  String bio = '',
  List<String> photos = const [],
  List<ProfilePrompt> prompts = const [],
}) {
  return Profile(
    id: id,
    name: id,
    age: 25,
    profession: '',
    company: '',
    education: '',
    bio: bio,
    photoUrls: photos,
    interests: const [],
    distanceKm: 0,
    isVerified: verified,
    prompts: prompts,
  );
}

void main() {
  group('selectStandouts', () {
    const prompt = ProfilePrompt(question: 'q', answer: 'a');

    test('only verified profiles with a photo, a bio, and a prompt qualify', () {
      final complete = _profile('complete', verified: true, bio: 'hi', photos: const ['x'], prompts: const [prompt]);
      final unverified = _profile('unverified', bio: 'hi', photos: const ['x'], prompts: const [prompt]);
      final noBio = _profile('noBio', verified: true, photos: const ['x'], prompts: const [prompt]);
      final noPhoto = _profile('noPhoto', verified: true, bio: 'hi', prompts: const [prompt]);
      final noPrompt = _profile('noPrompt', verified: true, bio: 'hi', photos: const ['x']);

      final result = selectStandouts([complete, unverified, noBio, noPhoto, noPrompt]);
      expect(result.map((p) => p.id).toList(), ['complete']);
    });

    test('is capped at 10 even with more qualifying profiles', () {
      final many =
          List.generate(15, (i) => _profile('p$i', verified: true, bio: 'hi', photos: const ['x'], prompts: const [prompt]));
      expect(selectStandouts(many), hasLength(10));
    });

    test('empty input gives an empty list, not an error', () {
      expect(selectStandouts(const []), isEmpty);
    });

    test('nothing qualifying gives an empty list', () {
      final incomplete = _profile('incomplete', verified: true, bio: 'hi');
      expect(selectStandouts([incomplete]), isEmpty);
    });
  });
}
