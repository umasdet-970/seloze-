import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';

/// Acquisition source (spec section 17), captured once at first sign-up
/// — see `_ensureUserDoc` in firebase_auth_repository.dart, which writes
/// the result to `users/{uid}.acquisitionSource`.
///
/// **Android only, real data**: queries the Google Play Install
/// Referrer API — a free, first-party Play Store capability available
/// to any app regardless of AdMob/MMP account status, and parses the
/// `utm_source`/`utm_medium` query-string-style referrer Play attaches
/// when the install came from a tracked link (e.g. a Google/Meta ad
/// click-through). Returns 'Organic/Direct' whenever there's no
/// referrer to parse — a sideloaded/debug build, an organic Play Store
/// search result, or (always) an iOS device.
///
/// **iOS has no equivalent captured here.** Apple doesn't expose an
/// install-referrer API the way Play does; real iOS attribution needs
/// either a mobile measurement partner (AppsFlyer/Adjust/Branch — a
/// third-party account and SDK this pass doesn't add) or SKAdNetwork
/// (postback-based, campaign-ID granularity only, no channel name).
/// iOS installs are honestly bucketed as 'Organic/Direct' rather than
/// guessed at.
class AcquisitionSourceService {
  static const _channelBySource = {
    'google-play': 'Organic/Direct',
    'googleadwords_int': 'Google Ads',
    'googleads': 'Google Ads',
    'google_ads': 'Google Ads',
    'facebook': 'Meta Ads',
    'meta': 'Meta Ads',
    'instagram': 'Meta Ads',
    'fb': 'Meta Ads',
    'youtube': 'YouTube',
  };

  Future<String> captureSource() async {
    if (!Platform.isAndroid) return 'Organic/Direct';

    try {
      final details = await AndroidPlayInstallReferrer.installReferrer;
      final referrer = details.installReferrer;
      if (referrer == null || referrer.isEmpty) return 'Organic/Direct';

      final params = Uri.splitQueryString(referrer);
      final source = params['utm_source']?.toLowerCase().trim();
      if (source == null || source.isEmpty) return 'Organic/Direct';

      return _channelBySource[source] ?? 'Organic/Direct';
    } catch (_) {
      // Play Install Referrer API unavailable (no Play Services, an
      // emulator without the Play Store, a very old device, etc.) — an
      // unknown acquisition source is exactly 'Organic/Direct', not an
      // error worth surfacing anywhere.
      return 'Organic/Direct';
    }
  }
}
