/// Single switch between the in-memory mock backend and real Firebase.
///
/// Flip to `true` only after:
/// 1. Running `flutterfire configure` from the project root (regenerates
///    `lib/firebase_options.dart` with your real project's keys).
/// 2. Creating the Firestore database and enabling the sign-in methods you
///    need (Email/Password, Phone, Google) in the Firebase console.
/// 3. Deploying the security rules in `firestore.rules`.
///
/// See FIREBASE_SETUP.md at the project root for the full checklist. Every
/// repository provider reads this flag to choose between its
/// `Mock*Repository` and `Firebase*`/`Firestore*Repository` implementation
/// — this is the only place that decision is made.
const bool kUseFirebase = false;

/// Same idea, for billing. Flip to `true` only after:
/// 1. Creating a RevenueCat account/project and adding your Android app.
/// 2. Configuring the Premium Monthly / Premium 3 Month / Ad-Free Monthly
///    subscriptions as products in Play Console, then importing them into
///    RevenueCat and attaching them to entitlements named exactly
///    `premium` and `ad_free` (see the identifiers documented in
///    `revenuecat_billing_repository.dart`).
/// 3. Replacing `_revenueCatApiKey` in that same file with your real
///    public SDK key from the RevenueCat dashboard.
///
/// Independent of [kUseFirebase] — you can have one on without the other.
const bool kUseRevenueCat = false;

/// Real AI moderation (spec section 12/19) — calls the `moderateImage`/
/// `moderateText` Cloud Functions (Cloud Vision SafeSearch / Cloud
/// Natural Language) instead of the client-side rule-based checks.
///
/// Flip to `true` only after:
/// 1. `kUseFirebase = true` and the Cloud Functions in `functions/`
///    (including `moderateImage`/`moderateText`, see `functions/src/moderation.ts`)
///    are deployed — this calls them, doesn't run them locally.
/// 2. The Cloud Vision API and Cloud Natural Language API are enabled
///    for this Firebase project in the GCP console (Blaze plan, same as
///    Cloud Functions itself — no separate account).
///
/// Falls back to the same rule-based checks used when this is `false`
/// if the Cloud Function call fails for any reason (not deployed yet,
/// network error) — see `CloudModerationRepository`.
const bool kUseCloudModeration = false;
