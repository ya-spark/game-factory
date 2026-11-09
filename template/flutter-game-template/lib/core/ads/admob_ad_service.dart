import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import 'ad_service.dart';

/// AdMob implementation (the only file besides ad_banner usage that imports the ad SDK).
///
/// Unit IDs come from [AdmobIds]: debug builds use Google's TEST IDs only, release builds use
/// the real IDs from app.config.yaml. While real IDs are still placeholders, ads stay off.
/// No interstitials exist; rewarded ads only when `pacing.rewardedEnabled` (adult profile).
class AdMobAdService implements AdService {
  AdMobAdService({
    required this.ids,
    required this.pacing,
    required this.isReleaseBuild,
  }) {
    if (!isReleaseBuild && !ids.allTest) {
      throw StateError('Debug build must use AdMob test IDs only.');
    }
    if (isReleaseBuild && ids.allTest) {
      throw StateError('Release build must not use AdMob test IDs.');
    }
  }

  final AdmobIds ids;
  final AdPacingConfig pacing;
  final bool isReleaseBuild;

  bool _removed = false;
  bool _initialized = false;
  bool _canRequest = false;
  RewardedAd? _rewarded;

  @override
  set adsRemoved(bool value) => _removed = value;

  bool get _configured => !ids.hasPlaceholders;

  @override
  bool get adsEnabled =>
      _initialized && _canRequest && _configured && !_removed;

  @override
  bool get isRewardedReady =>
      pacing.rewardedEnabled &&
      _initialized &&
      _canRequest &&
      _configured &&
      _rewarded != null;

  @override
  bool get privacyOptionsRequired => _privacyRequired;
  bool _privacyRequired = false;

  @override
  Future<void> initialize() async {
    if (!_configured) {
      debugPrint('AdMob: real ad IDs are still placeholders; ads disabled.');
      return;
    }
    await _applyRequestConfiguration();
    await _gatherConsent();
    if (!_canRequest) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadRewarded();
  }

  /// Child-directed treatment and content rating, from app.config.yaml `ads:`.
  Future<void> _applyRequestConfiguration() {
    final child = pacing.childDirected;
    final rating = switch (pacing.maxAdContentRating.toUpperCase()) {
      'PG' => MaxAdContentRating.pg,
      'T' => MaxAdContentRating.t,
      'MA' => MaxAdContentRating.ma,
      _ => MaxAdContentRating.g,
    };
    return MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        ageRestrictedTreatment: child
            ? AgeRestrictedTreatment.child
            : AgeRestrictedTreatment.unspecified,
        maxAdContentRating: rating,
      ),
    );
  }

  /// UMP consent (GDPR/EEA/UK). Shows the form only when required.
  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: pacing.childDirected),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        _canRequest = await ConsentInformation.instance.canRequestAds();
        _privacyRequired =
            await ConsentInformation.instance
                .getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
        if (!done.isCompleted) done.complete();
      },
      (FormError e) {
        debugPrint('UMP error: ${e.message}');
        // Fall back to whatever consent state we already have.
        ConsentInformation.instance
            .canRequestAds()
            .then((v) => _canRequest = v)
            .whenComplete(() {
              if (!done.isCompleted) done.complete();
            });
      },
    );
    await done.future;
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  }

  void _loadRewarded() {
    if (!pacing.rewardedEnabled) return;
    if (!(_initialized && _canRequest && _configured)) return;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => debugPrint('Rewarded failed: ${e.message}'),
      ),
    );
  }

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    final ad = _rewarded;
    if (ad == null || !isRewardedReady) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    return earned;
  }

  @override
  Widget buildBanner(AdPlacement placement) {
    // Every AdPlacement is a menu or a before/after-game screen; none is in play.
    if (!adsEnabled || !pacing.bannerEnabled) return const SizedBox.shrink();
    return _BannerSlot(adUnitId: ids.banner);
  }
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot({required this.adUnitId});
  final String adUnitId;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, e) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox(height: 50);
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
