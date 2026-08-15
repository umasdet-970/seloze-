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
- Chat: messages, read receipts, hidden conversations, typing indicators (`setTyping`, debounced from the composer), server-side push delivery (`sendPushOnNotificationCreate` Cloud Function — see "Cloud Functions" below)
- Online/offline presence: a foreground heartbeat (`PresenceService`) plus a staleness check at read time — see its doc comment for what this does and doesn't cover (no live disconnect detection, since that needs the Realtime Database, not Firestore)
- In-app notification center
- Settings (notification prefs, privacy)
- Analytics event logging
- Photo upload: the onboarding "Add photos" screen shows a real camera/gallery picker (via `image_picker`) when `kUseFirebase` is true, uploading straight to Firebase Storage (`FirebaseStorageUploader` in `lib/data/repositories/firebase/`) and storing the resulting download URL exactly like every other photo URL in the app. Mock mode (`kUseFirebase = false`) is untouched — still the URL-paste + sample-photo UI, verified unaffected by this change.
- Suspicious-profile risk scoring (`ProfileRiskScorer`, computed at profile save) and bot-detection swipe rate limiting — see the admin dashboard's flagged-profiles queue.
- Account moderation enforcement: `accountStatus` read from the user doc and enforced by the router (`/account-suspended`) — see "Admin dashboard fields" below.
- Real geo-distance in Discover, foreground push notifications, acquisition-source tracking, and cross-user cleanup on account deletion — see the sections below for each.

**Not implemented — separate integrations, not part of this pass:**
- **Billing** (`BillingRepository`) — needs RevenueCat + real Play Store/App Store developer accounts, has nothing to do with Firebase.
- **Moderation content classification** (`ModerationRepository`) — the mock's rule-based text/photo checks stay as-is; a real deployment swaps this for a hosted AI moderation API (Cloud Vision SafeSearch, Perspective API, etc.), which is a separate API integration. (Suspicious-*profile* scoring, as opposed to per-message content classification, is implemented — see above.)
- **Cloud Functions** — now written (`functions/`), still not deployed — see "Cloud Functions" section below. Ideally a future pass would also move the match/like-notification writes server-side per the rules file's note.

## Cloud Functions (added this pass)

`functions/` is a TypeScript Cloud Functions project (Node 20) with two
functions, closing the two gaps this doc used to list under "Not yet
wired":

- **`sendPushOnNotificationCreate`** — watches `users/{uid}/notifications/{id}`
  for new docs (written by every event: like, match, message, etc. — see
  `NotificationRepository`) and actually calls the FCM Admin SDK against
  that user's registered `fcmTokens`. Before this existed, tokens were
  collected client-side (`PushNotificationService`) but nothing ever sent
  a push — this is that missing half. Also prunes tokens FCM reports as
  dead (uninstalled app, cleared data) so the array doesn't grow forever.
- **`cleanupUserOnDelete`** — triggers when a Firebase Auth user is
  deleted and wipes that user's Firestore subcollections (`swipes`,
  `matches`, `likesReceived`, `blocked`, `reported`, `notifications`,
  `private`), which `AuthRepository.deleteAccount()` can't do itself
  since a client can only delete its own root doc. Also cleans up OTHER
  users' stale references to the deleted uid — a former match partner's
  own `matches/{deletedUid}` doc, and anyone whose `likesReceived/{deletedUid}`
  is still pending — via a collection-group query against the
  `otherUserId`/`fromUserId` fields those subcollections now carry (see
  `FirestoreSocialRepository`'s schema comment). `blocked`/`reported`
  cross-references and `conversations`/messages are deliberately left
  alone — see the function's doc comment in `functions/src/index.ts` for
  why each is safe to leave.

This was written and type-checked by inspection, not run — this
environment doesn't have Node.js installed, so `npm install` /
`npm run build` haven't actually been executed against it. Before
deploying:

```
cd functions
npm install
npm run build   # tsc — fix anything it flags before deploying
```

### Deploying

Cloud Functions require the **Blaze (pay-as-you-go) plan** — the free
Spark plan can't run them at all, even at zero usage. From the project
root (`dating_app/`):

```
firebase use <your-project-id>   # first time only; needs a project already selected
firebase deploy --only functions
```

### Testing

`npm run serve` (from `functions/`) runs the Firestore/Auth/Functions
emulators locally — point the app at the emulator suite (`useFirestoreEmulator`/
`useAuthEmulator` calls, not currently wired into `main.dart`, since
there was no functions project to test against before now) to exercise
both functions without touching production data. Once deployed for
real: sign up a test account, trigger a like/match/message and confirm
a push arrives; delete that account and confirm its subcollections are
gone from the Firestore console within a few seconds.

## Real AI moderation (added this pass)

`moderateImage`/`moderateText` (in `functions/src/moderation.ts`) call
Cloud Vision SafeSearch and Cloud Natural Language's `moderateText`
respectively, replacing the rule-based checks — gated by
`kUseCloudModeration` in `backend_config.dart` (default `false`, same
"written but not activated" pattern as everything else). Needs, beyond
what deploying `sendPushOnNotificationCreate`/`cleanupUserOnDelete`
already requires:

1. `npm install` in `functions/` (adds `@google-cloud/vision` and
   `@google-cloud/language`) and redeploy: `firebase deploy --only functions`.
2. Enable the **Cloud Vision API** and **Cloud Natural Language API** for
   this Firebase project in the GCP console — both pay-per-use on the
   same Blaze billing account Cloud Functions already needs, no separate
   account.
3. Set `kUseCloudModeration = true`.

If the callable fails for any reason (not deployed, network error), the
client falls back to the same rule-based check used when this flag is
`false` — see `CloudModerationRepository`'s doc comment. Not tested
against real Vision/Language responses, same Node.js caveat as the rest
of `functions/`.

## Real analytics (added this pass)

DAU, MAU, monthly churn, and the registration/conversion funnel in the
admin dashboard are now live Firestore queries, not placeholders — see
the doc comment at the top of `firestore_admin_repository.dart` for
exactly what's measured and how (they're proxies off `lastActiveAt`/
`createdAt`, not a stored daily-activity history, since that doesn't
exist). Two things to redeploy for these to work:

- **Firestore rules** — added `analyticsFunnel/{uid}` access.
- **Firestore indexes** — added a composite index on `users`
  (`createdAt`, `lastActiveAt`), needed for the retention queries.
  `firebase deploy --only firestore:indexes` and give it a few minutes
  to finish building before retention data appears (large collections
  can take longer; check progress in the Firebase console's Indexes tab).

Acquisition source is now real too (Android — see "Acquisition source"
below); CAC and LTV are real *computations* that stay at ₹0 until an
admin enters ad-spend data and RevenueCat sends webhooks respectively —
see "CAC/LTV data plumbing" below and `admin_dashboard/FIREBASE_SETUP.md`.

## Real geo-distance in Discover (added this pass)

`distanceKm` on Discover cards is now real haversine distance (see
`core/utils/geo_distance.dart`) between the viewer's and each
candidate's stored `{lat, lng}` — both written by `LocationService`,
best-effort at profile-save time (denied permission or disabled
location services never blocks finishing onboarding — see that class's
doc comment). Falls back to 0 whenever either side hasn't granted
location, same as before this pass, rather than a fabricated number.
Needs no extra Firebase setup — `lat`/`lng` ride along on the existing
`users/{uid}` doc, already covered by that doc's existing rules. Not
implemented: geohash-based query-level radius filtering (Firestore has
no native geoqueries) — this pass computes real distance for an
already-fetched batch, not "only fetch candidates within N km" at the
query level; that's a further scale optimization, not part of the ask.

## Foreground push notifications (added this pass)

`PushNotificationService` now shows an actual heads-up local
notification (via `flutter_local_notifications`) when a push arrives
while the app is open, instead of only logging it — tapping one
navigates to the relevant screen (likes/matches/chat/paywall) using the
same `NotificationType.route` mapping `NotificationsScreen` already
used. No Firebase-side setup needed beyond what `sendPushOnNotificationCreate`
already requires — this is purely a client-side presentation change.

## Acquisition source (added this pass)

`AcquisitionSourceService` captures the real Google Play Install
Referrer at first sign-up (Android only — free, first-party Play Store
API, no AdMob/MMP account needed) and writes it to
`users/{uid}.acquisitionSource`. iOS has no equivalent without a mobile
measurement partner (AppsFlyer/Adjust/Branch) and is honestly bucketed
as 'Organic/Direct' rather than guessed at — see that class's doc
comment. No extra Firebase setup needed; the admin dashboard reads this
field directly from the existing user-doc cache.

## CAC/LTV data plumbing (added this pass)

Real computations, not the mock's illustrative numbers, but both need
one more thing before they show a non-zero number:

- **CAC** = this month's `adSpend` ÷ users acquired via a paid channel
  this month. No automated spend writer exists (would need a Meta/Google
  Ads API integration — a further external-account dependency this pass
  doesn't add); an admin enters spend manually into the `adSpend/{id}`
  collection (`{channel, month: 'YYYY-MM', spendInr}`) until then —
  Firebase console's Data tab, or a future admin dashboard form.
- **LTV** = average realized revenue per paying user, from actual
  RevenueCat transaction history via a new Cloud Function,
  `revenueCatWebhook` (`functions/src/revenuecat_webhook.ts`). Needs,
  once you have a RevenueCat account (see BILLING_SETUP.md):
  1. Deploy functions (`firebase deploy --only functions`) and note the
     webhook's URL from the deploy output or Firebase console.
  2. Set the shared secret: `firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET`,
     then redeploy.
  3. RevenueCat dashboard → Project settings → Integrations → Webhooks →
     add that URL with a matching Authorization header value.

Both required a `firestore.rules` update (`revenueCatEvents` is
Admin-SDK-write-only, readable by admin; `adSpend` is admin read/write)
— redeploy rules: `firebase deploy --only firestore:rules`.

## Ads (added this pass)

`google_mobile_ads` is wired with Google's public **test** ad unit/app
IDs (`lib/core/config/ad_config.dart`) — these need no AdMob account and
work immediately, unlike everything else in this doc. Before a real
launch: create an AdMob account, replace the app IDs in
`AndroidManifest.xml`/`Info.plist` and the ad unit ID in
`ad_config.dart` with your real ones. Test ad units are policy-prohibited
in production builds submitted to either store.

## Admin dashboard fields (added this pass)

`users/{uid}` gained three fields the admin dashboard reads/writes —
see `admin_dashboard/FIREBASE_SETUP.md` for that app's setup:

- `accountStatus` (`'active'` | `'warned'` | `'suspended'` | `'banned'`) — written only by admin moderation actions. The router redirects a suspended/banned signed-in user to `/account-suspended` instead of the app; enforced client-side, not by security rules (rules can't block sign-in, only writes).
- `subscriptionTier` (`'free'` | `'premium'` | `'adFree'`) — best-effort, written by `RevenueCatBillingRepository` whenever it observes an entitlement change on this device. Not a substitute for RevenueCat webhooks (see BILLING_SETUP.md) — it can lag a change that happened on another device until this one reopens the app.
- `email` / `phoneNumber` — mirrored from Firebase Auth at first sign-in so the admin dashboard (a Firestore-only client, no Admin SDK access to Auth records) has something to display and search on.

`firestore.rules` gained an `isAdmin()` check (gated on an `admin`
custom claim — see `admin_dashboard/FIREBASE_SETUP.md` for how that's
granted) used to allow admin read/write on `users/{uid}`, admin
read/resolve on the top-level `reports` collection, and admin
`count()`-query access to the `matches` and `messages` collection
groups. Redeploy rules after pulling this change:
`firebase deploy --only firestore:rules`.
