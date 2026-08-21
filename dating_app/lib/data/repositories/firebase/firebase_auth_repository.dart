import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/app_user.dart';
import '../auth_repository.dart';
import 'acquisition_source_service.dart';

/// Real Firebase Auth + `users/{uid}` Firestore doc backing.
///
/// `currentUser` must stay synchronous (GoRouter's redirect requires it),
/// so this caches the latest [AppUser] every time Firebase's own auth
/// state or the Firestore profile doc changes, rather than fetching on
/// each read.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore, GoogleSignIn? googleSignIn})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email']) {
    _auth.authStateChanges().listen(_onFirebaseUserChanged);
  }

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _cachedUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  String? _pendingOtpVerificationId;

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  Future<void> _onFirebaseUserChanged(fb.User? user) async {
    await _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _cachedUser = null;
      _controller.add(null);
      return;
    }

    // Seed from the auth record immediately so the app doesn't sit on a
    // stale/null user while the first Firestore snapshot is in flight.
    _cachedUser = AppUser(uid: user.uid, email: user.email, phoneNumber: user.phoneNumber, displayName: user.displayName);
    _controller.add(_cachedUser);

    _profileSub = _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
      final data = doc.data();
      _cachedUser = AppUser(
        uid: user.uid,
        email: user.email,
        phoneNumber: user.phoneNumber,
        displayName: (data?['name'] as String?) ?? user.displayName,
        ageVerified: data?['ageVerified'] as bool? ?? false,
        dateOfBirth: (data?['dateOfBirth'] as Timestamp?)?.toDate(),
        accountStatus: data?['accountStatus'] as String? ?? 'active',
      );
      _controller.add(_cachedUser);
    });
  }

  Future<void> _ensureUserDoc(fb.User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      // Only meaningful captured once, right at the true first sign-up —
      // `_ensureUserDoc` already only reaches this branch that one time
      // (guarded by `!snap.exists` above), which is exactly the right
      // hook. Never throws — see AcquisitionSourceService's doc comment.
      final acquisitionSource = await AcquisitionSourceService().captureSource();

      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'ageVerified': false,
        'accountStatus': 'active',
        'acquisitionSource': acquisitionSource,
        // Mirrored from Firebase Auth (not read from there directly) so
        // the admin dashboard — a plain Firestore client with no Admin
        // SDK access to Auth records — has something to display/search.
        if (user.email != null) 'email': user.email,
        if (user.phoneNumber != null) 'phoneNumber': user.phoneNumber,
      }, SetOptions(merge: true));
    }
  }

  /// Trim + lowercase so "User@Example.com " (signup) and "user@example.com"
  /// (login) are treated as the same account — Firebase Auth's own uniqueness
  /// check is already case-insensitive, but sending inconsistent casing to
  /// `sendPasswordResetEmail`/error messages should still look the same.
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  AuthException _mapAuthError(fb.FirebaseAuthException e) {
    final message = switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account with this email already exists.',
      'weak-password' => 'Password must be at least 6 characters.',
      'invalid-email' => 'That email address looks invalid.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Network error. Check your connection and try again.',
      // Firebase Auth requires a *recent* sign-in for sensitive
      // operations (account deletion here) — a session signed in hours
      // ago routinely hits this. Without this case, deleteAccount()
      // would surface Firebase's raw English message instead of
      // something actionable.
      'requires-recent-login' => 'For your security, please sign out and sign back in before deleting your account.',
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
    return AuthException(message);
  }

  @override
  Future<AppUser> signUpWithEmail({required String email, required String password}) async {
    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(email: _normalizeEmail(email), password: password);
      await _ensureUserDoc(credential.user!);
      return currentUser!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: _normalizeEmail(email), password: password);
      return currentUser!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async {
    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {}, // Android auto-retrieval; verifyPhoneOtp still completes the flow explicitly.
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(_mapAuthError(e));
      },
      codeSent: (verificationId, _) {
        _pendingOtpVerificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _pendingOtpVerificationId = verificationId;
      },
    );
    return completer.future;
  }

  @override
  Future<AppUser> verifyPhoneOtp({required String phoneNumber, required String smsCode}) async {
    final verificationId = _pendingOtpVerificationId;
    if (verificationId == null) {
      throw AuthException('Request a new OTP for this number first.');
    }
    try {
      final credential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      final result = await _auth.signInWithCredential(credential);
      await _ensureUserDoc(result.user!);
      _pendingOtpVerificationId = null;
      return currentUser!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw AuthException('Google sign-in was cancelled.');
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      await _ensureUserDoc(result.user!);
      return currentUser!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: _normalizeEmail(email));
    } on fb.FirebaseAuthException catch (e) {
      // Deliberately swallow user-not-found — matches the mock's behavior
      // of not leaking which emails have accounts.
      if (e.code != 'user-not-found') throw _mapAuthError(e);
    }
  }

  @override
  Future<void> setAgeVerified(DateTime dateOfBirth) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('No signed-in user.');

    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    if (age < 18) {
      throw AuthException('You must be at least 18 years old to use Seloze.');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'ageVerified': true,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Deleting the auth user only removes login credentials — the
    // Firestore doc (and subcollections: likes, matches, messages, etc.)
    // must be cleaned up separately. `cleanupUserOnDelete` (see
    // functions/) does this reliably server-side via the Admin SDK,
    // which isn't subject to Firestore rules; this is a best-effort
    // client-side attempt at just the root doc, run first because it
    // has to — this uid's own auth context (required by firestore.rules)
    // only exists until `user.delete()` below succeeds. If this fails,
    // we still proceed to delete the Auth account rather than abort:
    // that's the half that actually matters for "can this person still
    // sign in and see my data", and the Cloud Function sweeps up
    // anything left behind here regardless of whether this succeeded.
    try {
      await _firestore.collection('users').doc(user.uid).delete();
    } catch (_) {}

    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      // Most common real-world case: 'requires-recent-login' — Firebase
      // rejects sensitive operations like this on a session that isn't
      // fresh. Mapped to an actionable AuthException instead of
      // propagating Firebase's raw exception type, consistent with
      // every other method in this repository.
      throw _mapAuthError(e);
    }
  }
}
