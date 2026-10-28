import '../clock.dart';
import '../config/app_config.dart';

/// Pure policy deciding whether an interstitial may be shown. No SDK imports.
class AdFrequencyPolicy {
  AdFrequencyPolicy(this.config, {Clock? clock})
    : _clock = clock ?? DateTime.now,
      _sessionStart = (clock ?? DateTime.now)();

  final AdPacingConfig config;
  final Clock _clock;
  final DateTime _sessionStart;

  DateTime? _lastInterstitial;
  int _shownThisSession = 0;
  int _gameOversSinceLast = 0;

  int get shownThisSession => _shownThisSession;

  /// Call once per finished game. Returns true if an interstitial should be shown now.
  bool shouldShowAfterGameOver() {
    _gameOversSinceLast++;
    final now = _clock();
    if (_shownThisSession >= config.maxInterstitialsPerSession) return false;
    if (_gameOversSinceLast < config.interstitialEveryNGameOvers) return false;
    if (now.difference(_sessionStart).inSeconds <
        config.noInterstitialFirstSeconds) {
      return false;
    }
    final last = _lastInterstitial;
    if (last != null &&
        now.difference(last).inSeconds <
            config.interstitialMinIntervalSeconds) {
      return false;
    }
    return true;
  }

  /// Call after an interstitial was actually shown.
  void recordShown() {
    _lastInterstitial = _clock();
    _shownThisSession++;
    _gameOversSinceLast = 0;
  }

  /// A rewarded ad the player chose to watch also resets the interstitial pacing, so we
  /// never show an interstitial right after a rewarded ad.
  void recordRewardedShown() {
    _lastInterstitial = _clock();
    _gameOversSinceLast = 0;
  }
}
