# Firebase setup (admin dashboard)

The admin dashboard's data layer is already written against real Firestore
— `AdminRepository` has both a `Mock` implementation (in-memory, what the
dashboard runs on today) and a real `FirestoreAdminRepository`
(`lib/data/repositories/firebase/`), chosen by one flag: `kUseFirebase` in
`lib/core/config/backend_config.dart`. Same pattern as `dating_app/`.

This dashboard reads the **same Firebase project and Firestore database**
as the mobile app — it's a second client on shared data, not a separate
backend. None of this has been run against a real project. This is the
checklist to turn it on, assuming `dating_app/FIREBASE_SETUP.md` has
already been done first.

## 1. Register a Web app in the same Firebase project

1. Firebase console → the same project used for `dating_app` → Project
   settings → Add app → Web.
2. From this directory (`admin_dashboard/`):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Select the **same project**, and only the **web** platform — this
   overwrites `lib/firebase_options.dart` with real keys.

## 2. Create an admin account and grant the `admin` custom claim

Admin access is gated by a Firebase Auth **custom claim**
(`admin: true`), not a Firestore role document — `firestore.rules` (in
`dating_app/`, shared by both apps) checks
`request.auth.token.admin == true` directly off the ID token. Custom
claims can only be set server-side with the Admin SDK; there's no
console UI toggle and no way to do this from either Flutter app.

1. Create the admin's account normally (Firebase console → Authentication
   → Add user, or have them sign up once from this dashboard while
   `kUseFirebase` is still `false` — either way you just need their UID).
2. Run this once, from any machine with Node and a service account key
   (Project settings → Service accounts → Generate new private key):

   ```js
   // grant-admin.js
   const admin = require('firebase-admin');
   admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });

   const uid = 'PASTE_THE_ADMIN_USERS_UID_HERE';
   admin.auth().setCustomUserClaims(uid, { admin: true })
     .then(() => console.log('Granted admin claim to', uid))
     .then(() => process.exit(0));
   ```

   ```
   npm install firebase-admin
   node grant-admin.js
   ```

3. That admin needs to sign out/in once (or wait for their existing
   session's token to refresh) before the claim takes effect — Firebase
   ID tokens are cached client-side for up to an hour.

To revoke access, call `setCustomUserClaims(uid, {})` the same way.

## 3. Deploy the updated Firestore rules

`firestore.rules` (in `dating_app/`) was extended this pass with an
`isAdmin()` check and the read/write access this dashboard needs — same
file, same deploy command as the mobile app:

```
firebase deploy --only firestore:rules
```

If you deployed rules before this pass and only redeploy `dating_app`'s
changes going forward, remember this dashboard's access depends on that
same rules file — redeploy it after pulling any future rules changes too.

## 4. Flip the flag

Set `kUseFirebase = true` in `lib/core/config/backend_config.dart`.

## 5. Test against the real project

Sign in with the admin account from step 2, and confirm: the Overview
screen shows real user/match/message counts (not the mock's fabricated
64 users), Users search finds real accounts, and resolving a report in
the Moderation screen actually changes that user's status in Firestore
(verify from the Firebase console's Data tab, or by having that user's
mobile session get redirected to the suspended screen).

## What's real vs. estimated vs. not yet available

See the doc comment at the top of `firestore_admin_repository.dart` for
the full field-by-field breakdown. Short version:

**Real, direct Firestore reads:**
- Total users, new registrations today, tier breakdown, verification
  status, account status (all via `users/{uid}`)
- Total matches, total messages (via `count()` aggregate queries)
- User search
- Report queue, including resolving a report and escalating the
  reported user's account status

**Estimated, not fabricated:**
- Monthly revenue: real subscriber counts × the real published prices
  (`₹899`/`₹99`) — not actual RevenueCat transaction totals, since that
  needs RevenueCat webhooks (see `dating_app/BILLING_SETUP.md`). Skews
  low if many Premium subscribers are on the 3-month plan rather than
  monthly, since `subscriptionTier` alone can't distinguish those.
- 14-day revenue trend: a flat line at today's estimate — there's no
  transaction history to show a real trend yet.

**Honestly empty, not mocked:**
- Daily active users (no presence/`lastActiveAt` tracking exists yet)
- Registration funnel, retention curve (need analytics event
  aggregation over time — a Cloud Functions + time-series pipeline, not
  a live query)
- Acquisition source (UTM/referrer isn't captured at sign-up today)
- CAC / LTV / churn (need Meta/Google/YouTube ad-spend data and
  realized revenue per cohort over months)

These return `[]` / `0` in `FirestoreAdminRepository` rather than
plausible-looking placeholder numbers, so the dashboard visibly shows
"no data" instead of quietly presenting estimates as measured facts.
