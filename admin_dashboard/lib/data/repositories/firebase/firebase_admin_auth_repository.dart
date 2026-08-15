import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../admin_auth_repository.dart';

/// Real Firebase Auth, gated by the `admin` custom claim rather than any
/// Firestore role document — claims travel on the ID token itself, so
/// Firestore security rules (`request.auth.token.admin == true`) can
/// check them without an extra read. See FIREBASE_SETUP.md for how the
/// claim gets set (it can't be set from client code, by design).
class FirebaseAdminAuthRepository implements AdminAuthRepository {
  FirebaseAdminAuthRepository({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onFirebaseUserChanged);
  }

  final fb.FirebaseAuth _auth;
  final _controller = StreamController<bool>.broadcast();
  bool _signedInAsAdmin = false;

  @override
  bool get isSignedIn => _signedInAsAdmin;

  @override
  Stream<bool> authStateChanges() => _controller.stream;

  Future<void> _onFirebaseUserChanged(fb.User? user) async {
    if (user == null) {
      _signedInAsAdmin = false;
      _controller.add(false);
      return;
    }
    // Firebase caches the ID token client-side; force a refresh so a
    // claim granted moments ago (or revoked) is reflected immediately
    // rather than after the token's normal ~1hr refresh cycle.
    final result = await user.getIdTokenResult(true);
    _signedInAsAdmin = result.claims?['admin'] == true;
    if (!_signedInAsAdmin) {
      // Signed into Firebase Auth successfully, but not an admin — don't
      // leave a half-authenticated session sitting around.
      await _auth.signOut();
    }
    _controller.add(_signedInAsAdmin);
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final result = await credential.user!.getIdTokenResult(true);
      if (result.claims?['admin'] != true) {
        await _auth.signOut();
        throw Exception('This account is not authorized for admin access.');
      }
    } on fb.FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Network error. Check your connection and try again.',
        _ => e.message ?? 'Something went wrong. Please try again.',
      };
      throw Exception(message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
