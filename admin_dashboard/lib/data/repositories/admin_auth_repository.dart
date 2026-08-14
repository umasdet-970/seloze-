import 'dart:async';

/// Real admin auth needs proper role-gated Firebase Auth (custom claims)
/// once a backend exists. Mock accepts one fixed demo credential.
abstract class AdminAuthRepository {
  bool get isSignedIn;
  Stream<bool> authStateChanges();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

class MockAdminAuthRepository implements AdminAuthRepository {
  final _controller = StreamController<bool>.broadcast();
  bool _signedIn = false;

  static const demoEmail = 'admin@connect.app';
  static const demoPassword = 'admin123';

  @override
  bool get isSignedIn => _signedIn;

  @override
  Stream<bool> authStateChanges() => _controller.stream;

  @override
  Future<void> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (email.trim().toLowerCase() != demoEmail || password != demoPassword) {
      throw Exception('Invalid admin credentials.');
    }
    _signedIn = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _signedIn = false;
    _controller.add(false);
  }
}
