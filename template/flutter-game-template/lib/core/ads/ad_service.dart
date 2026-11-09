import 'package:flutter/widgets.dart';

import '../config/app_config.dart';

/// Rewarded ads exist only for the Continue, and only in the adult profile.
enum RewardedPlacement { revive }

/// All advertising goes through this interface. UI/game code never imports an ad SDK.
abstract interface class AdService {
  Future<void> initialize();

  /// Ads are served and allowed (consent given, not removed, IDs configured).
  bool get adsEnabled;

  /// Player bought "remove ads": no banner, interstitial or rewarded ad (the UI grants rewards directly).
  set adsRemoved(bool value);

  bool get isRewardedReady;

  /// Shows a rewarded ad. Returns true only if the player earned the reward. Always false
  /// outside the adult profile. There are no interstitials anywhere.
  Future<bool> showRewarded(RewardedPlacement placement);

  /// Banner for a placement before or after a game (menu, pre_game, post_game). There is no
  /// in-play placement. An empty box when no ad is available, ads are removed or it is off.
  Widget buildBanner(AdPlacement placement);

  /// GDPR/UMP: re-open the privacy options form, if one is required for this user.
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
}

/// Used by widget tests and when ads are unavailable. Rewarded ads always "succeed".
class FakeAdService implements AdService {
  FakeAdService({this.rewardResult = true});
  bool rewardResult;
  int rewardedShown = 0;
  final List<AdPlacement> bannersBuilt = [];
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
  Future<bool> showRewarded(RewardedPlacement placement) async {
    rewardedShown++;
    return rewardResult;
  }

  @override
  Widget buildBanner(AdPlacement placement) {
    bannersBuilt.add(placement);
    return const SizedBox.shrink();
  }

  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptions() async {}
}
