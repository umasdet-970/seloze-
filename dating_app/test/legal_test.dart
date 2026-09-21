import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/core/constants/legal_content.dart';
import 'package:connect_dating_app/core/utils/geo_distance.dart';
import 'package:connect_dating_app/data/repositories/auth_repository.dart';
import 'package:connect_dating_app/data/repositories/user_profile_repository.dart';
import 'package:connect_dating_app/features/auth/providers/auth_providers.dart';
import 'package:connect_dating_app/features/auth/screens/age_verification_screen.dart';
import 'package:connect_dating_app/features/chat/providers/chat_providers.dart';
import 'package:connect_dating_app/features/legal/screens/legal_document_screen.dart';
import 'package:connect_dating_app/features/notifications/providers/notification_providers.dart';
import 'package:connect_dating_app/features/onboarding/providers/onboarding_providers.dart';
import 'package:connect_dating_app/features/onboarding/widgets/location_consent_tile.dart';
import 'package:connect_dating_app/features/profile/providers/presence_providers.dart';

/// Records what the age gate asks the auth layer to store.
class _RecordingAuth extends MockAuthRepository {
  int calls = 0;
  String? termsVersion;

  @override
  Future<void> setAgeVerified(DateTime dateOfBirth, {String? termsVersion}) async {
    calls++;
    this.termsVersion = termsVersion;
  }
}

void main() {
  final mockOverrides = [
    userProfileRepositoryProvider.overrideWithValue(MockUserProfileRepository()),
    newMessageWatcherProvider.overrideWith((ref) {}),
    pushRegistrarProvider.overrideWith((ref) {}),
    presenceRegistrarProvider.overrideWith((ref) {}),
  ];

  group('age gate + terms acceptance', () {
    Future<_RecordingAuth> openAgeGate(WidgetTester tester) async {
      final auth = _RecordingAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...mockOverrides, authRepositoryProvider.overrideWithValue(auth)],
          child: const MaterialApp(home: AgeVerificationScreen()),
        ),
      );
      // Pick the date the picker opens on (25 years ago), which is 18+.
      await tester.tap(find.text('Select date of birth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('links to all three documents', (tester) async {
      await openAgeGate(tester);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Community Guidelines'), findsOneWidget);
    });

    testWidgets('cannot continue until the terms are accepted', (tester) async {
      final auth = await openAgeGate(tester);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(auth.calls, 0);
      expect(find.textContaining('Please accept the Terms'), findsOneWidget);
    });

    testWidgets('accepting records which version of the terms was accepted', (tester) async {
      final auth = await openAgeGate(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(auth.calls, 1);
      expect(auth.termsVersion, kTermsVersion);
    });
  });

  group('legal documents', () {
    test('the Terms point to the Community Guidelines that now exist', () {
      expect(kTermsText, contains('Community Guidelines'));
      expect(kGuidelinesText, contains('## 7. Reporting and blocking'));
    });

    test('the Terms do not describe subscriptions that cannot be bought yet', () {
      expect(kTermsText, isNot(contains('renew automatically')));
      expect(kTermsText, isNot(contains('Apple App Store')));
      expect(kTermsText, contains('free to use at the moment'));
    });

    test('the Privacy Policy matches what the app really does with location', () {
      expect(kPrivacyPolicyText, contains('rounded to roughly 1 km'));
      expect(kPrivacyPolicyText, contains('only if you switch on'));
    });

    test('the Privacy Policy discloses sensitive preference data and retention exceptions', () {
      expect(kPrivacyPolicyText, contains('sexual orientation'));
      expect(kPrivacyPolicyText, contains('reports made about an account'));
    });

    test('the same contact address appears in all three documents', () {
      for (final doc in [kPrivacyPolicyText, kTermsText, kGuidelinesText]) {
        expect(doc, contains('umamaheswar.sdet@gmail.com'));
      }
    });

    testWidgets('no "draft" footer is shown to users', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LegalDocumentScreen(title: 'Community Guidelines', content: kGuidelinesText)),
      );
      expect(find.textContaining('draft'), findsNothing);
      expect(find.textContaining('lawyer'), findsNothing);
      expect(find.text('Our promise'), findsOneWidget);
    });
  });

  group('location', () {
    test('coordinates are rounded to about 1 km before storing', () {
      expect(roundCoordinate(18.520430), 18.52);
      expect(roundCoordinate(73.856744), 73.86);
      expect(roundCoordinate(-33.868820), -33.87);
      expect(roundCoordinate(0), 0);
    });

    testWidgets("the consent box explains the rounding and asks before the phone does", (tester) async {
      var ticked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => LocationConsentTile(
                value: ticked,
                onChanged: (v) => setState(() => ticked = v),
              ),
            ),
          ),
        ),
      );

      expect(find.text("Use my approximate location"), findsOneWidget);
      expect(find.textContaining("rounded to about 1 km"), findsOneWidget);
      expect(find.textContaining("Your phone will ask for permission next"), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(ticked, isTrue);
    });
  });
}
