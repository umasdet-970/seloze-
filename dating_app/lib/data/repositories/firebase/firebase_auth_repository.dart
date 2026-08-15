import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/app_user.dart';
import '../auth_repository.dart';

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
      );
      _controller.add(_cachedUser);
    });
  }

  Future<void> _ensureUserDoc(fb.User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'ageVerified': false,
      }, SetOptions(merge: true));
    }
  }

  AuthException _mapAuthError(fb.FirebaseAuthException e) {
    final message = switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account with this email already exists.',
      'weak-password' => 'Password must be at least 6 characters.',
      'invalid-email' => 'That email address looks invalid.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Network error. Check your connection and try again.',
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
    return AuthException(message);
  }

  @override
  Future<AppUser> signUpWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _ensureUserDoc(credential.user!);
      return currentUser!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
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
      await _auth.sendPasswordResetEmail(email: email);
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
      throw AuthException('You must be at least 18 years old to use Connect.');
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
    // must be cleaned up separately. A Cloud Function trigger on user
    // deletion is the reliable way to do this server-side; deleting just
    // the root doc here is a best-effort client-side fallback.
    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
  }
}
