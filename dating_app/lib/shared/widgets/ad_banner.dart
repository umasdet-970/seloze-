import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/ad_config.dart';

/// Real banner ad (spec section 18) — shown to Free-tier users, replacing
/// the earlier static "Advertisement" placeholder. Loads Google's test
/// creative when `kUseAds` is true (the default — see ad_config.dart for
/// why this one doesn't need an account first). Renders nothing while
/// loading and nothing if the load fails, rather than reserving blank
/// space or showing an error — a failed ad load shouldn't be visible
/// UI breakage, just a quieter feed.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kUseAds) _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Without this, State.dispose() below would call
          // _bannerAd?.dispose() a second time on an already-disposed
          // native ad object.
          if (identical(_bannerAd, ad)) _bannerAd = null;
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!kUseAds || !_isLoaded || ad == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
