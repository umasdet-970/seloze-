# Firebase setup

The app's data layer is already written against real Firebase/Firestore —
every repository interface has both a `Mock*` implementation (in-memory,
what the app runs on today) and a real `Firebase*`/`Firestore*`
implementation (in `lib/data/repositories/firebase/`), chosen by a single
flag: `kUseFirebase` in `lib/core/config/backend_config.dart`.

None of this has been run against a real project — it can't be, without
your Firebase account. This is the checklist to actually turn it on.

## 1. Create the Firebase project

1. Go to the [Firebase console](https://console.firebase.google.com), create a project (or use an existing one).
2. Add an Android app with package name `com.connect.connect_dating_app` (must match `applicationId` in `android/app/build.gradle.kts`).
3. Enable **Authentication** → Sign-in methods: Email/Password, Phone, Google.
4. Enable **Firestore Database** (start in production mode — the rules below replace the defaults).
5. Enable **Storage** (for profile photo uploads, once that upload flow is built — see "Not yet wired" below).

## 2. Run FlutterFire CLI

From the project root (`dating_app/`):

```
dart pub global activate flutterfire_cli
flutterfire configure
```

This walks you through selecting the Firebase project and platforms, and
**overwrites `lib/firebase_options.dart`** with your real project's keys
(replacing the placeholder that's there now, which intentionally throws if
used). It also drops `google-services.json` into `android/app/`.

## 3. Apply the Google Services Gradle plugin

`flutterfire configure` does NOT modify `android/build.gradle.kts` /
`android/app/build.gradle.kts` for you on newer Flutter templates. Add:

- In `android/settings.gradle.kts`, inside the `plugins` block: `id("com.google.gms.google-services") version "4.4.2" apply false`
- In `android/app/build.gradle.kts`, inside the `plugins` block: `id("com.google.gms.google-services")`

(This step was deliberately left undone — applying that plugin without
`google-services.json` present fails the build outright, and that file
only exists after step 2.)

## 4. Deploy Firestore rules and indexes

Both are already written, at the project root:

```
firebase deploy --only firestore:rules,firestore:indexes
```

`firestore.rules` documents one known simplification inline (matches and
like-notifications require one user's client to write into another user's
subcollection — noted in a comment, with the production hardening path).

## 5. Flip the flag

In `lib/core/config/backend_config.dart`, set `kUseFirebase = true`. Every
provider in the app reads this flag — nothing else needs to change.

## 6. Test against the real project

Run the app, sign up, complete onboarding, and manually walk the same
flows this session verified against the mock backend: sign-in, profile
creation, discover/like/match, chat, notifications, settings. Watch the
Firestore console's Data tab to confirm documents are landing where
expected.

## What's implemented vs. not

**Implemented** (in `lib/data/repositories/firebase/`):
- Auth (email/password, phone OTP, Google, password reset, age verification)
- User's own profile + dating preferences
- Discover feed + profile lookups
- Social graph: likes, matches (via a Firestore transaction), blocks, reports, daily discovery quota
- Chat: messages, read receipts, hidden conversations
- In-app notification center
- Settings (notification prefs, privacy)
- Analytics event logging
- Photo upload: the onboarding "Add photos" screen shows a real camera/gallery picker (via `image_picker`) when `kUseFirebase` is true, uploading straight to Firebase Storage (`FirebaseStorageUploader` in `lib/data/repositories/firebase/`) and storing the resulting download URL exactly like every other photo URL in the app. Mock mode (`kUseFirebase = false`) is untouched — still the URL-paste + sample-photo UI, verified unaffected by this change.

**Not implemented — separate integrations, not part of this pass:**
- **Billing** (`BillingRepository`) — needs RevenueCat + real Play Store/App Store developer accounts, has nothing to do with Firebase.
- **Moderation** (`ModerationRepository`) — the mock's rule-based text/photo checks stay as-is; a real deployment swaps this for a hosted AI moderation API (Cloud Vision SafeSearch, Perspective API, etc.), which is a separate API integration.
- **Push notification delivery (server side)** — the client half is done: `PushNotificationService` (in `lib/data/repositories/firebase/`) requests notification permission, registers/refreshes this device's FCM token onto `users/{uid}.fcmTokens`, and has foreground/background message handlers wired via `pushRegistrarProvider` (watched app-wide in `main.dart`, no-ops unless `kUseFirebase`). What's still missing: a Cloud Function that watches `users/{uid}/notifications` for new docs and actually calls the FCM Admin SDK to send to those tokens — without it, tokens get collected but nothing is ever pushed. Foreground messages are also only logged, not surfaced as a local notification or in-app banner (would need `flutter_local_notifications` for that).
- **Chat typing indicators** — `isTyping()` reads real Firestore data, but nothing currently writes to it (the interface has no "set typing" method) — see the comment in `firestore_chat_repository.dart`.
- **Geo-distance for Discover** — `distanceKm` comes back as a placeholder; real distance needs geohashing (Firestore has no native geoqueries).
- **Cloud Functions** — none deployed. A production app would want at minimum: a user-deletion cleanup function (wiping subcollections when an auth user is deleted, since the client can only delete its own root doc), and ideally moving the match/like-notification writes server-side per the rules file's note.
