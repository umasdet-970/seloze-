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

  /// One of 'active' | 'warned' | 'suspended' | 'banned' — mirrors the
  /// admin dashboard's `AccountStatus` enum by name (kept as a plain
  /// String here rather than a shared enum since the two Flutter apps
  /// don't share a package). Written only by admin moderation actions;
  /// the router redirects suspended/banned users to `/account-suspended`.
  final String accountStatus;

  const AppUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.ageVerified = false,
    this.dateOfBirth,
    this.accountStatus = 'active',
  });

  bool get isSuspendedOrBanned => accountStatus == 'suspended' || accountStatus == 'banned';

  AppUser copyWith({
    String? email,
    String? phoneNumber,
    String? displayName,
    bool? ageVerified,
    DateTime? dateOfBirth,
    String? accountStatus,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      ageVerified: ageVerified ?? this.ageVerified,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      accountStatus: accountStatus ?? this.accountStatus,
    );
  }
}
