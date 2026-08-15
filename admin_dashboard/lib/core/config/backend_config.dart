/// Single switch between the in-memory mock backend and real Firebase.
/// Mirrors `dating_app/lib/core/config/backend_config.dart` — same idea,
/// same reasons, applied to the admin dashboard.
///
/// Flip to `true` only after:
/// 1. Registering a Web app in the SAME Firebase project as dating_app
///    (Firebase console → Project settings → Add app → Web), then running
///    `flutterfire configure` from this directory (regenerates
///    `lib/firebase_options.dart`).
/// 2. Granting the `admin` custom claim to the account(s) that should be
///    able to sign in here — Firestore rules can't grant this themselves,
///    it needs a one-time Admin SDK script. See FIREBASE_SETUP.md.
/// 3. Deploying the updated `firestore.rules` from `dating_app/` (it now
///    includes the admin-claim-gated rules this dashboard needs).
///
/// See FIREBASE_SETUP.md at this project's root for the full checklist.
const bool kUseFirebase = false;
