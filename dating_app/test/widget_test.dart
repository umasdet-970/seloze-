import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/core/utils/geo_distance.dart';
import 'package:connect_dating_app/data/models/discover_filters.dart';
import 'package:connect_dating_app/data/models/profile.dart';
import 'package:connect_dating_app/data/repositories/auth_repository.dart';
import 'package:connect_dating_app/data/repositories/user_profile_repository.dart';
import 'package:connect_dating_app/features/auth/providers/auth_providers.dart';
import 'package:connect_dating_app/features/auth/screens/login_screen.dart';
import 'package:connect_dating_app/features/chat/providers/chat_providers.dart';
import 'package:connect_dating_app/features/discover/widgets/profile_details_sheet.dart';
import 'package:connect_dating_app/features/notifications/providers/notification_providers.dart';
import 'package:connect_dating_app/features/onboarding/screens/create_profile_screen.dart';
import 'package:connect_dating_app/features/onboarding/providers/onboarding_providers.dart';
import 'package:connect_dating_app/features/profile/providers/presence_providers.dart';
import 'package:connect_dating_app/features/settings/screens/settings_screen.dart';
import 'package:connect_dating_app/features/subscription/screens/paywall_screen.dart';
import 'package:connect_dating_app/main.dart';

/// Records what the Settings screen asks the auth layer to do.
class _FakeAuth extends MockAuthRepository {
  _FakeAuth({required this.needsPassword, this.failWith});

  final bool needsPassword;
  final AuthException? failWith;
  int deleteCalls = 0;
  String? deletedWithPassword;

  @override
  bool get deletionNeedsPassword => needsPassword;

  @override
  Future<void> deleteAccount({String? password}) async {
    deleteCalls++;
    deletedWithPassword = password;
    if (failWith != null) throw failWith!;
  }
}

void main() {
  // The app is built with `kUseFirebase = true`, so its real repositories
  // need a live Firebase app. Tests swap in the in-memory mocks (and no-op
  // the three app-wide background watchers) so they run with no backend.
  final mockOverrides = [
    authRepositoryProvider.overrideWithValue(MockAuthRepository()),
    userProfileRepositoryProvider.overrideWithValue(MockUserProfileRepository()),
    newMessageWatcherProvider.overrideWith((ref) {}),
    pushRegistrarProvider.overrideWith((ref) {}),
    presenceRegistrarProvider.overrideWith((ref) {}),
  ];

  testWidgets('App boots to the login screen when signed out', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: mockOverrides, child: const ConnectApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Paywall shows "coming soon" — no prices or Subscribe buttons — while billing is off',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: mockOverrides, child: const MaterialApp(home: PaywallScreen())),
    );
    await tester.pump();

    expect(find.text('Premium is coming soon'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('Login form shows an email error while typing and clears it once the email is valid',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: mockOverrides, child: const MaterialApp(home: LoginScreen())),
    );
    final emailField = find.byType(TextFormField).first;

    await tester.enterText(emailField, 'abc');
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    // Only the field being edited is validated — the untouched password
    // field must not turn red while someone is still typing their email.
    expect(find.text('At least 6 characters'), findsNothing);

    // Previously this error stayed on screen until the submit button was
    // pressed again, even though the email was now fine.
    await tester.enterText(emailField, 'abc@example.com');
    await tester.pump();
    expect(find.text('Enter a valid email'), findsNothing);
  });

  testWidgets('Profile screen marks required fields with a red * and leaves optional ones plain',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: mockOverrides, child: const MaterialApp(home: CreateProfileScreen())),
    );
    await tester.pumpAndSettle();

    Finder rich(String plain) =>
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == plain);

    // Enforced by the wizard (name + gender + bio to leave step 1).
    expect(rich('Name *'), findsOneWidget);
    expect(rich('Gender *'), findsOneWidget);
    expect(rich('Bio *'), findsOneWidget);
    expect(rich('* Required'), findsOneWidget); // the legend

    // Optional — no star.
    expect(rich('Profession *'), findsNothing);
    expect(rich('Education *'), findsNothing);
  });

  group('Delete account', () {
    Future<_FakeAuth> openDeleteDialog(WidgetTester tester, _FakeAuth auth) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('asks for the password and passes it to deleteAccount', (tester) async {
      final auth = await openDeleteDialog(tester, _FakeAuth(needsPassword: true));
      expect(find.text('Confirm your password'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'secret1');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(auth.deletedWithPassword, 'secret1');
    });

    testWidgets('does not ask for a password for Google/phone accounts', (tester) async {
      final auth = await openDeleteDialog(tester, _FakeAuth(needsPassword: false));
      expect(find.text('Confirm your password'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(auth.deleteCalls, 1);
      expect(auth.deletedWithPassword, isNull);
    });

    testWidgets('Cancel deletes nothing', (tester) async {
      final auth = await openDeleteDialog(tester, _FakeAuth(needsPassword: true));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.deleteCalls, 0);
    });

    testWidgets('shows the error when deletion fails instead of failing silently', (tester) async {
      final auth = await openDeleteDialog(
        tester,
        _FakeAuth(needsPassword: true, failWith: AuthException('That password is incorrect.')),
      );
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(auth.deleteCalls, 1);
      expect(find.text('That password is incorrect.'), findsOneWidget);
    });
  });

  group('formatDistanceKm', () {
    test('returns null when the distance is unknown (0)', () {
      expect(formatDistanceKm(0), isNull);
    });

    test('rounds to whole km instead of printing raw doubles', () {
      expect(formatDistanceKm(12.3456789), '12 km');
      expect(formatDistanceKm(12.6), '13 km');
    });

    test('shows <1 km for very close profiles', () {
      expect(formatDistanceKm(0.4), '<1 km');
    });
  });

  group('DiscoverFilters.differsFrom', () {
    test('is false when nothing changed from the saved defaults', () {
      const base = DiscoverFilters(minAge: 18, maxAge: 45, maxDistanceKm: 50);
      expect(base.differsFrom(base), isFalse);
    });

    test('is true when the age range differs from the saved defaults', () {
      const base = DiscoverFilters(minAge: 18, maxAge: 45, maxDistanceKm: 50);
      expect(base.copyWith(maxAge: 60).differsFrom(base), isTrue);
    });

    test('is true when a search is active even if the ranges match', () {
      const base = DiscoverFilters(minAge: 18, maxAge: 45, maxDistanceKm: 50);
      expect(base.copyWith(searchQuery: 'ana').differsFrom(base), isTrue);
    });
  });

  testWidgets('Profile details sheet shows the full bio, interests and location', (tester) async {
    const profile = Profile(
      id: 'p1',
      name: 'Asha',
      age: 27,
      profession: 'Designer',
      company: '',
      education: 'NID',
      bio: 'A long bio that the card would have truncated to two lines.',
      photoUrls: [],
      interests: ['Travel', 'Music', 'Yoga', 'Art'],
      city: 'Pune',
      country: 'India',
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

    expect(find.text('Asha, 27'), findsOneWidget);
    expect(find.text('Pune, India'), findsOneWidget); // distance unknown -> no "0.0 km"
    expect(find.text('Designer'), findsOneWidget); // no dangling " at " when company is empty
    expect(find.textContaining('A long bio'), findsOneWidget);
    for (final interest in profile.interests) {
      expect(find.text(interest), findsOneWidget);
    }
  });
}
