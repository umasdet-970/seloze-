import 'dart:io';

/// Real ad SDK (spec section 18: "Ads for free users"), using Google's
/// publicly documented TEST ad unit and app IDs — these work with no
/// AdMob account at all, unlike every other integration in this app
/// (Firebase, RevenueCat, Cloud Functions), which is why this defaults
/// `true` rather than `false`.
///
/// Before a real launch:
/// 1. Create an AdMob account and app at admob.google.com, linked to
///    this app's Play Store/App Store listing.
/// 2. Replace the app IDs in `android/app/src/main/AndroidManifest.xml`
///    (`com.google.android.gms.ads.APPLICATION_ID`) and
///    `ios/Runner/Info.plist` (`GADApplicationIdentifier`) with your
///    real ones.
/// 3. Replace `_bannerAdUnitId` below with your real banner ad unit ID.
/// 4. iOS also needs a real `SKAdNetworkItems` list in Info.plist for
///    ad-attribution (Google's docs have the current list) — not added
///    here since it's a large static list unrelated to app logic.
// Off for the first Play Store release: the IDs below are Google's TEST ad
// units, which AdMob policy forbids serving to real users, and there is no
// real banner ad unit created yet (only a rewarded one — see kUseRewardedAds
// below). Flip to `true` only after creating a real banner ad unit too.
const bool kUseAds = false;

/// Google's public test banner ad unit IDs — documented at
/// https://developers.google.com/admob/flutter/test-ads. Guaranteed to
/// always serve a test creative, safe to ship in a debug/staging build,
/// NOT safe to ship to production (AdMob policy prohibits real traffic
/// on test ad units — swap before submitting to either store).
String get bannerAdUnitId {
  if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
  if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
  throw UnsupportedError('Ads are only wired for Android/iOS.');
}

/// Rewarded ad — "watch a short ad for +1 discovery today" — independent of
/// [kUseAds]/the banner. Real AdMob app + ad unit exist (admob.google.com,
/// app "Seloze-Global Dating App"), but AdMob's post-signup review (up to
/// ~24h) and the payment profile weren't both done yet as of wiring this in.
/// Flip to `true` once AdMob shows the account/app as fully approved AND
/// payment details are added — serving real ads before that risks the
/// account being suspended.
const bool kUseRewardedAds = false;

/// Real rewarded ad unit ID for the "+1 discovery" bonus (Android only —
/// no iOS ad unit created since this app isn't on iOS yet).
String get rewardedAdUnitId {
  if (Platform.isAndroid) return 'ca-app-pub-4841811327884657/6247534448';
  // Google's public test rewarded ad unit — safe fallback, never actually
  // reachable while kUseRewardedAds is gated to Android-only callers.
  return 'ca-app-pub-3940256099942544/5224354917';
}

/// Daily cap on the ad-bonus discoveries a user can earn by watching
/// rewarded ads, on top of their plan + referral bonus (see
/// referral_config.dart for the equivalent invite-a-friend cap).
const int kMaxAdBonusPerDay = 3;
