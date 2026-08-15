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
const bool kUseAds = true;

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
