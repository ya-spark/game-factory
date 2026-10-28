import 'package:yaml/yaml.dart';

/// AdMob unit IDs for one build mode.
class AdmobIds {
  const AdmobIds({
    required this.appId,
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String appId;
  final String banner;
  final String interstitial;
  final String rewarded;

  /// Google's published sample publisher; every sample ID contains this number.
  static const String testPublisher = 'ca-app-pub-3940256099942544';

  /// True while a value is still the factory placeholder (no real AdMob ID yet).
  static bool isPlaceholder(String id) => id.startsWith('PLACEHOLDER');

  static bool isTestId(String id) => id.startsWith(testPublisher);

  bool get hasPlaceholders =>
      [appId, banner, interstitial, rewarded].any(isPlaceholder);

  bool get allTest => [appId, banner, interstitial, rewarded].every(isTestId);

  factory AdmobIds.fromYaml(YamlMap m) => AdmobIds(
    appId: m['app_id'] as String,
    banner: m['banner'] as String,
    interstitial: m['interstitial'] as String,
    rewarded: m['rewarded'] as String,
  );
}

class AdPacingConfig {
  const AdPacingConfig({
    this.interstitialMinIntervalSeconds = 90,
    this.interstitialEveryNGameOvers = 2,
    this.maxInterstitialsPerSession = 6,
    this.noInterstitialFirstSeconds = 60,
    this.bannerEnabled = true,
  });

  final int interstitialMinIntervalSeconds;
  final int interstitialEveryNGameOvers;
  final int maxInterstitialsPerSession;
  final int noInterstitialFirstSeconds;
  final bool bannerEnabled;
}

class RetentionConfig {
  const RetentionConfig({
    this.dailyReward = true,
    this.streaks = true,
    this.dailyChallenges = true,
    this.achievements = true,
  });

  final bool dailyReward;
  final bool streaks;
  final bool dailyChallenges;
  final bool achievements;
}

class PlatformsConfig {
  const PlatformsConfig({
    this.android = true,
    this.ios = false,
    this.web = false,
  });

  final bool android;
  final bool ios;
  final bool web;
}

class PlayGamesConfig {
  const PlayGamesConfig({
    this.enabled = false,
    this.appId = 'PLACEHOLDER_PLAY_GAMES_APP_ID',
    this.leaderboardHighScore = 'PLACEHOLDER_LEADERBOARD_ID',
  });

  final bool enabled;
  final String appId;
  final String leaderboardHighScore;
}

/// Parsed `app.config.yaml`. Pure Dart.
class AppConfig {
  const AppConfig({
    required this.appId,
    required this.displayName,
    required this.packageName,
    required this.themeSeedColor,
    required this.themeDark,
    required this.platforms,
    required this.admobDebug,
    required this.admobRelease,
    required this.adPacing,
    required this.retention,
    required this.playGames,
  });

  final String appId;
  final String displayName;
  final String packageName;
  final int themeSeedColor; // 0xAARRGGBB
  final bool themeDark;
  final PlatformsConfig platforms;
  final AdmobIds admobDebug;
  final AdmobIds admobRelease;
  final AdPacingConfig adPacing;
  final RetentionConfig retention;
  final PlayGamesConfig playGames;

  /// IDs to use for the current build mode. Debug always yields test IDs.
  AdmobIds admobFor({required bool release}) {
    if (release) return admobRelease;
    if (!admobDebug.allTest) {
      throw StateError(
        'app.config.yaml admob.debug contains a non-test AdMob ID. '
        'Debug builds must only use Google test IDs.',
      );
    }
    return admobDebug;
  }

  factory AppConfig.fromYamlString(String source) {
    final root = loadYaml(source) as YamlMap;
    final app = root['app'] as YamlMap;
    final theme = (root['theme'] as YamlMap?) ?? YamlMap();
    final platforms = (root['platforms'] as YamlMap?) ?? YamlMap();
    final admob = root['admob'] as YamlMap;
    final ads = (root['ads'] as YamlMap?) ?? YamlMap();
    final ret = (root['retention'] as YamlMap?) ?? YamlMap();
    final pg = (root['play_games'] as YamlMap?) ?? YamlMap();
    bool enabled(Object? p) =>
        p is YamlMap ? (p['enabled'] as bool? ?? false) : false;
    return AppConfig(
      appId: app['id'] as String,
      displayName: app['display_name'] as String,
      packageName: app['package_name'] as String,
      themeSeedColor: _parseColor(theme['seed_color'] as String? ?? '#2EC4B6'),
      themeDark: theme['dark'] as bool? ?? true,
      platforms: PlatformsConfig(
        android: enabled(platforms['android']),
        ios: enabled(platforms['ios']),
        web: enabled(platforms['web']),
      ),
      admobDebug: AdmobIds.fromYaml(admob['debug'] as YamlMap),
      admobRelease: AdmobIds.fromYaml(admob['release'] as YamlMap),
      adPacing: AdPacingConfig(
        interstitialMinIntervalSeconds:
            ads['interstitial_min_interval_seconds'] as int? ?? 90,
        interstitialEveryNGameOvers:
            ads['interstitial_every_n_game_overs'] as int? ?? 2,
        maxInterstitialsPerSession:
            ads['max_interstitials_per_session'] as int? ?? 6,
        noInterstitialFirstSeconds:
            ads['no_interstitial_first_seconds'] as int? ?? 60,
        bannerEnabled: ads['banner_enabled'] as bool? ?? true,
      ),
      retention: RetentionConfig(
        dailyReward: ret['daily_reward'] as bool? ?? true,
        streaks: ret['streaks'] as bool? ?? true,
        dailyChallenges: ret['daily_challenges'] as bool? ?? true,
        achievements: ret['achievements'] as bool? ?? true,
      ),
      playGames: PlayGamesConfig(
        enabled: pg['enabled'] as bool? ?? false,
        appId: pg['app_id'] as String? ?? 'PLACEHOLDER_PLAY_GAMES_APP_ID',
        leaderboardHighScore:
            pg['leaderboard_high_score'] as String? ??
            'PLACEHOLDER_LEADERBOARD_ID',
      ),
    );
  }

  static int _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  }
}
