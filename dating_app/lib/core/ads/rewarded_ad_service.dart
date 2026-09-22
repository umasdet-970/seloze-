import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

/// Loads and shows the "+1 discovery" rewarded ad (see ad_config.dart).
/// One instance per app run, reused across Discover visits — a fresh ad is
/// pre-loaded after each show/failure so the button rarely has to wait on
/// a cold load.
class RewardedAdService {
  RewardedAdService._();
  static final instance = RewardedAdService._();

  RewardedAd? _ad;
  bool _loading = false;

  /// True once an ad has finished loading and is ready to show immediately.
  bool get isReady => _ad != null;

  void preload() {
    if (!kUseRewardedAds || _loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          // Best-effort — a failed load just means the "+1" button stays
          // hidden/disabled until the next preload succeeds, never a
          // crash or a blocking error surfaced to the user.
          _loading = false;
          _ad = null;
        },
      ),
    );
  }

  /// Shows the pre-loaded ad if one is ready. [onEarned] fires only when the
  /// user watches to completion (AdMob's own reward callback) — never on a
  /// skip or an early close, so it can't be gamed by dismissing early.
  /// Returns false immediately (no-op) if no ad is ready yet, otherwise
  /// resolves once the ad is dismissed/fails, true iff the reward was
  /// earned. Deliberately does NOT trust RewardedAd.show()'s own Future,
  /// which completes as soon as the show request is sent — before the
  /// reward or dismissal callbacks fire — so a caller awaiting it directly
  /// would read `earned` too early.
  Future<bool> show({required void Function() onEarned}) async {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null; // consumed — never show the same instance twice
    var earned = false;
    final done = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload(); // line up the next one
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preload();
        if (!done.isCompleted) done.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
        onEarned();
      },
    );
    return done.future;
  }
}
