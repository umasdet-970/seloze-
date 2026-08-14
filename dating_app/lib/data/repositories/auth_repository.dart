import 'dart:async';

import '../models/app_user.dart';

/// Contract the UI/providers depend on. When you're ready to plug in
/// Firebase, write `FirebaseAuthRepository implements AuthRepository`
/// and swap it in `auth_providers.dart` — nothing else changes.
abstract class AuthRepository {
  /// Synchronous snapshot of the signed-in user, used by GoRouter's
  /// `redirect` (which must be synchronous).
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<AppUser> signUpWithEmail({required String email, required String password});
  Future<AppUser> signInWithEmail({required String email, required String password});

  Future<void> sendPhoneOtp(String phoneNumber);
  Future<AppUser> verifyPhoneOtp({required String phoneNumber, required String smsCode});

  Future<AppUser> signInWithGoogle();

  Future<void> sendPasswordResetEmail(String email);

  /// Records date of birth and marks the current user as age-verified.
  /// Throws [AuthException] if under 18 (spec section 1: age verification).
  Future<void> setAgeVerified(DateTime dateOfBirth);

  Future<void> signOut();
  Future<void> deleteAccount();
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class _MockAccount {
  final String password;
  AppUser user;
  _MockAccount({required this.password, required this.user});
}

/// In-memory auth so the full Registration & Login flow (spec section 1)
/// can be built and tested end-to-end before a real Firebase project
/// exists. State resets on app restart — that's expected for this phase.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  final Map<String, _MockAccount> _accountsByEmail = {};
  final Map<String, _MockAccount> _accountsByPhone = {};

  AppUser? _currentUser;
  String? _pendingOtpPhone;

  static const _mockOtpCode = '123456';

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  void _setUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 500));

  @override
  Future<AppUser> signUpWithEmail({required String email, required String password}) async {
    await _delay();
    if (password.length < 6) {
      throw AuthException('Password must be at least 6 characters.');
    }
    if (_accountsByEmail.containsKey(email)) {
      throw AuthException('An account with this email already exists.');
    }
    final user = AppUser(uid: 'uid-${DateTime.now().microsecondsSinceEpoch}', email: email);
    _accountsByEmail[email] = _MockAccount(password: password, user: user);
    _setUser(user);
    return user;
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    await _delay();
    final account = _accountsByEmail[email];
    if (account == null || account.password != password) {
      throw AuthException('Incorrect email or password.');
    }
    _setUser(account.user);
    return account.user;
  }

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async {
    await _delay();
    _pendingOtpPhone = phoneNumber;
  }

  @override
  Future<AppUser> verifyPhoneOtp({required String phoneNumber, required String smsCode}) async {
    await _delay();
    if (_pendingOtpPhone != phoneNumber) {
      throw AuthException('Request a new OTP for this number first.');
    }
    if (smsCode != _mockOtpCode) {
      throw AuthException('Invalid code. (Mock build: use $_mockOtpCode.)');
    }
    final existing = _accountsByPhone[phoneNumber]?.user;
    final user = existing ??
        AppUser(uid: 'uid-${DateTime.now().microsecondsSinceEpoch}', phoneNumber: phoneNumber);
    _accountsByPhone[phoneNumber] = _MockAccount(password: '', user: user);
    _pendingOtpPhone = null;
    _setUser(user);
    return user;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await _delay();
    const user = AppUser(
      uid: 'uid-google-demo',
      email: 'demo.google.user@gmail.com',
      displayName: 'Demo Google User',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _delay();
    // Intentionally succeeds even for unknown emails to avoid leaking
    // which addresses have accounts (matches Firebase Auth best practice).
  }

  @override
  Future<void> setAgeVerified(DateTime dateOfBirth) async {
    await _delay();
    final user = _currentUser;
    if (user == null) throw AuthException('No signed-in user.');

    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    if (age < 18) {
      throw AuthException('You must be at least 18 years old to use Connect.');
    }

    final updated = user.copyWith(ageVerified: true, dateOfBirth: dateOfBirth);
    if (user.email != null) _accountsByEmail[user.email!]?.user = updated;
    if (user.phoneNumber != null) _accountsByPhone[user.phoneNumber!]?.user = updated;
    _setUser(updated);
  }

  @override
  Future<void> signOut() async {
    await _delay();
    _setUser(null);
  }

  @override
  Future<void> deleteAccount() async {
    await _delay();
    final user = _currentUser;
    if (user != null) {
      _accountsByEmail.removeWhere((_, a) => a.user.uid == user.uid);
      _accountsByPhone.removeWhere((_, a) => a.user.uid == user.uid);
    }
    _setUser(null);
  }
}
