import 'dart:io';

import 'package:flutter/services.dart';

const _installReferrerChannel = MethodChannel('connect/install_referrer');

/// Acquisition source (spec section 17), captured once at first sign-up
/// — see `_ensureUserDoc` in firebase_auth_repository.dart, which writes
/// the result to `users/{uid}.acquisitionSource`.
///
/// **Android only, real data**: queries the Google Play Install
/// Referrer API — a free, first-party Play Store capability available
/// to any app regardless of AdMob/MMP account status — via a
/// MethodChannel straight to Google's own
/// `com.android.installreferrer` library (implemented natively in
/// `android/.../MainActivity.kt`), not the `android_play_install_referrer`
/// pub.dev wrapper. That wrapper is stuck at compileSdk 33 with no
/// newer release, which fails Gradle's AAR-metadata check once other
/// dependencies (google_mobile_ads, Firebase) require compileSdk 34+ —
/// see MainActivity.kt's doc comment for the full story. Parses the
/// same `utm_source`/`utm_medium` query-string-style referrer Play
/// attaches when the install came from a tracked link (e.g. a
/// Google/Meta ad click-through). Returns 'Organic/Direct' whenever
/// there's no referrer to parse — a sideloaded/debug build, an organic
/// Play Store search result, or (always) an iOS device.
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
    // Our own "Invite friends" links (see core/config/referral_config.dart).
    'invite': 'Friend invite',
  };

  /// Firebase uids are plain alphanumerics; anything else in an invite link
  /// is malformed (or hostile) and is ignored rather than stored.
  static final _uidPattern = RegExp(r'^[A-Za-z0-9]{6,128}$');

  /// Pure parser for the Play install-referrer string (unit-tested).
  static InstallAttribution parseReferrer(String? referrer) {
    const organic = InstallAttribution('Organic/Direct');
    if (referrer == null || referrer.isEmpty) return organic;

    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(referrer);
    } catch (_) {
      return organic;
    }
    final source = params['utm_source']?.toLowerCase().trim();
    if (source == null || source.isEmpty) return organic;

    final channel = _channelBySource[source] ?? 'Organic/Direct';
    if (source == 'invite') {
      final inviter = params['utm_content']?.trim();
      final valid = inviter != null && _uidPattern.hasMatch(inviter);
      return InstallAttribution(channel, inviterUid: valid ? inviter : null);
    }
    return InstallAttribution(channel);
  }

  /// Channel + (for invite links) who invited this install.
  Future<InstallAttribution> captureAttribution() async {
    if (!Platform.isAndroid) return const InstallAttribution('Organic/Direct');

    try {
      // The native side always resolves (never throws) — a timeout here
      // is still worth having in case the InstallReferrerClient
      // connection callback never fires on some OEM's Play Services
      // build, which would otherwise hang first sign-up indefinitely.
      final referrer = await _installReferrerChannel
          .invokeMethod<String>('getInstallReferrer')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      return parseReferrer(referrer);
    } catch (_) {
      // Play Install Referrer API unavailable (no Play Services, an
      // emulator without the Play Store, a very old device, etc.) — an
      // unknown acquisition source is exactly 'Organic/Direct', not an
      // error worth surfacing anywhere.
      return const InstallAttribution('Organic/Direct');
    }
  }

  Future<String> captureSource() async => (await captureAttribution()).source;
}

class InstallAttribution {
  const InstallAttribution(this.source, {this.inviterUid});

  /// Acquisition channel shown in the admin dashboard.
  final String source;

  /// The uid of the user whose invite link this install came from, if any.
  final String? inviterUid;
}
