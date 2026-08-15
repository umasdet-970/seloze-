# RevenueCat billing setup

Same story as `FIREBASE_SETUP.md`, for payments: `BillingRepository` has a
real `RevenueCatBillingRepository` implementation (in
`lib/data/repositories/firebase/revenuecat_billing_repository.dart` —
kept alongside the Firebase repos since it's the other half of "real
backend," even though RevenueCat itself is independent of Firebase),
chosen over the mock by the `kUseRevenueCat` flag in
`lib/core/config/backend_config.dart` (currently `false`). Written and
verified not to regress the mock app; never run against a real
RevenueCat/Play Billing setup, since that needs your accounts.

## 1. Play Console: create the subscription products

You need a Play Console developer account first (see the main Play Store
readiness report — this is one of the items only you can do). Create three
subscriptions with base plans matching what the code expects:

| Plan | Product/base-plan ID |
|---|---|
| Premium Monthly | `premium_monthly` |
| Premium 3 Months | `premium_3month` |
| Ad-Free Monthly | `ad_free_monthly` |

(These IDs are just this app's convention, defined in
`revenuecat_billing_repository.dart`'s `_planToProductId` map — free to
rename, as long as the map and Play Console agree.)

## 2. RevenueCat: create a project and import the products

1. Sign up at [revenuecat.com](https://www.revenuecat.com), create a project, add a Google Play app.
2. Link your Play Console account (RevenueCat needs a service account with API access — their onboarding walks through this).
3. Import the three products created in step 1.
4. Create two **entitlements**: `premium` (attached to both Premium products) and `ad_free` (attached to the Ad-Free product) — these exact identifiers are what `revenuecat_billing_repository.dart` checks for.
5. Create an **Offering** (the "current" one) with three **Packages**, each pointing at one product. Package identifiers should match the product IDs above, or update `_planToProductId` to match whatever you chose.

## 3. Add your API key

Copy the public Google Play SDK key from RevenueCat's dashboard (Project
settings → API keys) into `_revenueCatApiKey` in
`revenuecat_billing_repository.dart`. This is a public key — safe to
commit, not a secret.

## 4. Flip the flag

Set `kUseRevenueCat = true` in `lib/core/config/backend_config.dart`.

## 5. Test against real Play Billing

Play Billing subscriptions can only be tested with a build installed via
Play Console's internal testing track (not a sideloaded debug/release
APK) and a tester account added to a Play Console license testing list —
this can't be verified in this environment. Once you have that set up,
test: purchasing each plan, `restorePurchases`, and `cancelAutoRenew`
(which deep-links to Play Store's subscription management — Play Billing
gives apps no API to cancel a subscription directly).

## What this doesn't cover

- **Server-side receipt validation / webhook handling** — RevenueCat does this for you and is the source of truth `currentSubscription()` reads from, so this is less of a gap than with a from-scratch Play Billing integration, but you should still set up RevenueCat's webhooks if the admin dashboard needs subscription events.
- **iOS** — this app's Android-only right now (matches the "Play Store launch" goal); the RevenueCat repository code itself is platform-agnostic, but Play Console/App Store product setup would need a matching App Store Connect pass.
