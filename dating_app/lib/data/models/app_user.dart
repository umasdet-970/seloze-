/// Authenticated user. Mirrors what will eventually come from
/// Firebase Auth's `User` plus the `users/{uid}` Firestore doc's
/// age-verification flag.
class AppUser {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final bool ageVerified;
  final DateTime? dateOfBirth;

  const AppUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.ageVerified = false,
    this.dateOfBirth,
  });

  AppUser copyWith({
    String? email,
    String? phoneNumber,
    String? displayName,
    bool? ageVerified,
    DateTime? dateOfBirth,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      ageVerified: ageVerified ?? this.ageVerified,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
