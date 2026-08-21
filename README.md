# Seloze

A dating app for iOS/Android built with Flutter, Riverpod, and Firebase, plus an admin dashboard for moderation and analytics.

- **`dating_app/`** — the Flutter mobile app (published name: **Seloze**, package `com.connect.connect_dating_app`)
- **`admin_dashboard/`** — internal admin/moderation dashboard

## Status (as of 2026-08-21)

### Done and verified live
- Real Firebase backend: Authentication (Email/Password, Google, Phone all enabled), Firestore, Storage
- Real Cloud Functions deployed: `moderateImage`, `moderateText` (Cloud Vision + Cloud Natural Language AI moderation), `revenueCatWebhook`, `sendPushOnNotificationCreate`, `cleanupUserOnDelete`
- Real photo uploads to Firebase Storage, with AI moderation on every upload
- Google Sign-In working end-to-end (debug + release signing both registered)
- Privacy Policy / Terms hosted publicly via Firebase Hosting:
  - https://connect-dating-app-e2ad4.web.app/privacy.html
  - https://connect-dating-app-e2ad4.web.app/terms.html
- Release signing keystore generated and verified (see `SELOZE_SECRETS_BACKUP/` — kept out of git on purpose, back it up separately)
- Google Play Console developer account created, app entry created, identity verified
- Fixed: Discover screen hamburger menu (was a dead button), hardcoded Likes/Matches badge counts (now real Firestore-backed counts)

### Pending
- **RevenueCat subscriptions** — code is fully written (`RevenueCatBillingRepository`), but `kUseRevenueCat` is still `false` and the API key is still a placeholder in `revenuecat_billing_repository.dart`. Blocked on:
  - BillDesk merchant account verification (RBI PA-CB requirement for Indian developers selling on Play Store) — in progress, requires a Video KYC call from the address on file
  - Creating the real subscription products in Play Console once merchant verification clears
  - Importing those products into RevenueCat as entitlements/offerings
- **Real AdMob account** — ads currently use Google's public *test* ad unit IDs (no real revenue yet). Needs a real AdMob account, then swap IDs in `dating_app/lib/core/config/ad_config.dart` and `AndroidManifest.xml`
- Placeholder support email (`support@connect.app`) in the account-suspended screen — needs a real domain

## Setup

See `dating_app/FIREBASE_SETUP.md` for the full Firebase setup checklist (already completed for the connected project, `connect-dating-app-e2ad4`).

Secrets required to build a release APK (keystore, `key.properties`, RevenueCat webhook secret) are **not** in this repo — see the separate `SELOZE_SECRETS_BACKUP/` folder (kept outside git) for those.
