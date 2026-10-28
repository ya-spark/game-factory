import 'package:flutter/widgets.dart';

enum AdPlacement { gameOver, revive }

/// All advertising goes through this interface. UI/game code never imports an ad SDK.
abstract interface class AdService {
  Future<void> initialize();

  /// Ads are served and allowed (consent given, not removed, IDs configured).
  bool get adsEnabled;

  /// Player bought "remove ads": banner and interstitials stop; rewarded stays available.
  set adsRemoved(bool value);

  bool get isRewardedReady;

  /// Shows a rewarded ad. Returns true only if the player earned the reward.
  Future<bool> showRewarded(AdPlacement placement);

  /// Shows an interstitial if the frequency policy allows it. Returns true if shown.
  Future<bool> maybeShowInterstitialAfterGameOver();

  /// Banner widget (empty box when no ad is available / ads removed).
  Widget buildBanner();

  /// GDPR/UMP: re-open the privacy options form, if one is required for this user.
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
}

/// Used by widget tests and when ads are unavailable. Rewarded ads always "succeed".
class FakeAdService implements AdService {
  FakeAdService({this.rewardResult = true});
  bool rewardResult;
  int rewardedShown = 0;
  int interstitialsShown = 0;
  bool _removed = false;

  @override
  Future<void> initialize() async {}
  @override
  bool get adsEnabled => !_removed;
  @override
  set adsRemoved(bool value) => _removed = value;
  @override
  bool get isRewardedReady => true;
  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    rewardedShown++;
    return rewardResult;
  }

  @override
  Future<bool> maybeShowInterstitialAfterGameOver() async => false;
  @override
  Widget buildBanner() => const SizedBox.shrink();
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptions() async {}
}
