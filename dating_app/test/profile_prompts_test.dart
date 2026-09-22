import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/core/constants/profile_prompts.dart';
import 'package:connect_dating_app/data/models/profile.dart';
import 'package:connect_dating_app/features/discover/widgets/profile_details_sheet.dart';

void main() {
  group('ProfilePrompt / Profile.prompts', () {
    test('round-trips through toMap/fromMap', () {
      const profile = Profile(
        id: 'p1',
        name: 'Asha',
        age: 27,
        profession: '',
        company: '',
        education: '',
        bio: '',
        photoUrls: [],
        interests: [],
        distanceKm: 0,
        prompts: [
          ProfilePrompt(question: 'A perfect first date looks like...', answer: 'Somewhere with good coffee.'),
        ],
      );

      final restored = Profile.fromMap('p1', profile.toMap());
      expect(restored.prompts, hasLength(1));
      expect(restored.prompts.single.question, 'A perfect first date looks like...');
      expect(restored.prompts.single.answer, 'Somewhere with good coffee.');
    });

    test('a profile with no prompts round-trips to an empty list, not null/crash', () {
      const profile = Profile(
        id: 'p1',
        name: 'Asha',
        age: 27,
        profession: '',
        company: '',
        education: '',
        bio: '',
        photoUrls: [],
        interests: [],
        distanceKm: 0,
      );
      expect(Profile.fromMap('p1', profile.toMap()).prompts, isEmpty);
    });

    test('kMaxProfilePrompts is fewer than the question bank (so a full picker never runs dry)', () {
      expect(kMaxProfilePrompts, lessThan(kProfilePromptQuestions.length));
    });
  });

  group('Profile details sheet with prompts', () {
    testWidgets('shows each answered prompt\'s question and answer', (tester) async {
      const profile = Profile(
        id: 'p1',
        name: 'Asha',
        age: 27,
        profession: '',
        company: '',
        education: '',
        bio: '',
        photoUrls: [],
        interests: [],
        distanceKm: 0,
        prompts: [
          ProfilePrompt(question: 'A perfect first date looks like...', answer: 'A walk and good conversation.'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showProfileDetailsSheet(context, profile),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('A perfect first date looks like...'), findsOneWidget);
      expect(find.text('A walk and good conversation.'), findsOneWidget);
    });

    testWidgets('shows nothing extra when there are no prompts', (tester) async {
      const profile = Profile(
        id: 'p1',
        name: 'Asha',
        age: 27,
        profession: '',
        company: '',
        education: '',
        bio: 'hi',
        photoUrls: [],
        interests: [],
        distanceKm: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showProfileDetailsSheet(context, profile),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final q in kProfilePromptQuestions) {
        expect(find.text(q), findsNothing);
      }
    });
  });
}
