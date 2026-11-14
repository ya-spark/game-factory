import 'package:yaml/yaml.dart';

import '../../engine/engine.dart';

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
    this.childDirected = true,
    this.maxAdContentRating = 'G',
    this.interstitialsEnabled = false,
    this.rewardedEnabled = false,
  });

  /// Always false in every profile: the studio shows no interstitial anywhere.
  final bool interstitialsEnabled;

  /// Rewarded ads (the Continue). Only an `adult` app can turn this on.
  final bool rewardedEnabled;

  final int interstitialMinIntervalSeconds;
  final int interstitialEveryNGameOvers;
  final int maxInterstitialsPerSession;
  final int noInterstitialFirstSeconds;
  final bool bannerEnabled;

  /// Child-directed ads (COPPA / under-age-of-consent): no personalised ads.
  final bool childDirected;

  /// AdMob max ad content rating: G, PG, T or MA.
  final String maxAdContentRating;
}

/// Who the app is for (`audience:` in `app.config.yaml`). It sets the ads, sign-in and parent
/// gate rules; `scripts/profile_check.sh` rejects unsafe combinations in CI.
enum Audience {
  child,
  teen,
  adult;

  static Audience parse(String? v) => switch (v) {
    'child' => Audience.child,
    'teen' => Audience.teen,
    _ => Audience.adult,
  };
}

/// Where a banner may show: before and after a game only. There is no in-play placement.
enum AdPlacement {
  menu('menu'),
  preGame('pre_game'),
  postGame('post_game');

  const AdPlacement(this.configName);
  final String configName;
}

/// Rules derived from the [Audience]. Pure Dart.
class AudiencePolicy {
  const AudiencePolicy(this.audience);
  final Audience audience;

  bool get isAdult => audience == Audience.adult;

  /// Child-directed ad treatment (child and teen).
  bool get childDirectedAds => !isAdult;

  /// A rewarded ad may exist (adult only).
  bool get rewardedAllowed => isAdult;

  /// Play Games sign-in: none in a child app, optional in teen and adult.
  bool get signInAllowed => audience != Audience.child;

  /// Parent gate on every real-money purchase and on coin spends for games.
  bool get parentGateOnPurchases => !isAdult;
  bool get parentGateOnCoinSpends => !isAdult;
}

/// `speech:` in `app.config.yaml`: reading aloud. Each app sets [autoRead] per level.
class SpeechConfig {
  const SpeechConfig({this.autoRead = false, this.locale = 'en-AU'});
  final bool autoRead;
  final String locale;
}

class RetentionConfig {
  const RetentionConfig({
    this.dailyReward = true,
    this.streaks = true,
    this.dailyChallenges = true,
    this.achievements = true,
    this.gameChallenges = false,
  });

  final bool dailyReward;
  final bool streaks;
  final bool dailyChallenges;
  final bool achievements;

  /// Hubs: the daily challenges are game-based (score in any game, play N different games, a
  /// streak goal) instead of the puzzle ones.
  final bool gameChallenges;
}

/// `shop:` in app.config.yaml: optional shop sections (the Mind hubs turn both on).
class ShopConfig {
  const ShopConfig({this.extraThemes = false, this.soundPacks = false});

  /// Four extra colour themes beside the four every app has.
  final bool extraThemes;

  /// Ambience packs bought with coins (the "Sounds" section).
  final bool soundPacks;
}

/// `goals_reminders:` in app.config.yaml (C4). The Craft apps turn [parentArea] on: goal presets
/// and reminders are set in the Parent area. [settingsRow] keeps the reminder switch in Settings
/// (Scout and Ranger turn it off; Champion keeps it). Default (off) leaves the Mind hubs as they were.
class GoalsRemindersConfig {
  const GoalsRemindersConfig({
    this.parentArea = false,
    this.settingsRow = true,
  });
  final bool parentArea;
  final bool settingsRow;
}

/// `exam_practice:` in app.config.yaml (C7). On for Champion (teen Craft); off elsewhere.
class ExamPracticeConfig {
  const ExamPracticeConfig({this.enabled = false});
  final bool enabled;
}

enum ShareLinkMode {
  internalTest,
  store,
  off;

  static ShareLinkMode parse(String? v) => switch (v) {
    'store' => store,
    'off' => off,
    _ => internalTest,
  };
}

class ShareConfig {
  const ShareConfig({
    this.linkMode = ShareLinkMode.internalTest,
    this.internalTestUrl = '',
  });

  /// Which link share texts carry; [ShareLinkMode.off] adds none and hides "Share app".
  final ShareLinkMode linkMode;

  /// Used by [ShareLinkMode.internalTest]; empty behaves like off.
  final String internalTestUrl;
}

enum MoreGameStatus {
  live,
  comingSoon,
  hidden;

  static MoreGameStatus parse(String? v) => switch (v) {
    'live' => live,
    'coming_soon' => comingSoon,
    _ => hidden,
  };
}

/// One other game by the studio, listed on the "More games" screen.
class MoreGame {
  const MoreGame({
    required this.id,
    required this.packageName,
    required this.name,
    required this.tagline,
    required this.status,
  });

  final String id;
  final String packageName;
  final String name;
  final String tagline;
  final MoreGameStatus status;
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

/// `web:` in `app.config.yaml`: the public web copy (not the Android app). Nothing here is
/// read by the Android build.
class WebConfig {
  const WebConfig({
    this.description = '',
    this.indexable = false,
    this.playStoreUrl = '',
  });

  /// Short page description (meta description, social preview, manifest).
  final String description;

  /// `web.indexable`: false (default) writes `noindex, nofollow`; the owner turns it on.
  final bool indexable;

  /// `web.play_store_url`: the "Get the Android app" link. Empty hides it.
  final String playStoreUrl;

  bool get hasPlayStoreLink => playStoreUrl.isNotEmpty;
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

/// `content:` in `app.config.yaml`: where learning content comes from and how it is released.
class ContentConfig {
  const ContentConfig({
    this.enabled = false,
    this.baseUrl = 'https://content.activemindcraft.com/v1/',
    this.signingPublicKey = 'PLACEHOLDER_SIGNING_PUBLIC_KEY',
    this.signingKeyId = 'PLACEHOLDER_SIGNING_KEY_ID',
    this.mobileConfirmMb = 20,
    this.dailyRelease = const ReleaseConfig(),
  });

  /// Learning games set this true: child profiles, the picker on every launch and the parent
  /// area. Off in the plain game template.
  final bool enabled;
  final String baseUrl;
  final String signingPublicKey;
  final String signingKeyId;
  final int mobileConfirmMb;
  final ReleaseConfig dailyRelease;

  /// While true the app accepts an unsigned index (no key added yet).
  bool get signingOff => signingPublicKey.startsWith('PLACEHOLDER');

  SigningConfig get signing =>
      SigningConfig(publicKey: signingPublicKey, keyId: signingKeyId);

  DownloadSettings downloadSettings({required bool wifiOnly}) =>
      DownloadSettings(
        wifiOnly: wifiOnly,
        mobileConfirmBytes: mobileConfirmMb * 1024 * 1024,
      );
}

/// `family_mode: in `app.config.yaml`: two players take turns in Tug of war on one device.
class FamilyModeConfig {
  const FamilyModeConfig({this.enabled = false});
  final bool enabled;
}

/// `minigames:` in `app.config.yaml`: the price of a coin-locked minigame.
class MiniGamesConfig {
  const MiniGamesConfig({this.coinPrice = 200});
  final int coinPrice;
}

RewardsConfig _parseRewards(YamlMap root) {
  final r = (root['rewards'] as YamlMap?) ?? YamlMap();
  final stars = (r['stars'] as YamlMap?) ?? YamlMap();
  final coins = (r['coins'] as YamlMap?) ?? YamlMap();
  const d = RewardsConfig();
  final ms = coins['streak_milestones'];
  return RewardsConfig(
    starsEnabled: stars['enabled'] as bool? ?? d.starsEnabled,
    perFirstPass: stars['per_first_pass'] as int? ?? d.perFirstPass,
    topicBonus: stars['topic_bonus'] as int? ?? d.topicBonus,
    streakBonus: stars['streak_bonus'] as int? ?? d.streakBonus,
    weeklyCapPerChild:
        coins['weekly_cap_per_child'] as int? ?? d.weeklyCapPerChild,
    topicCoins: coins['topic'] as int? ?? d.topicCoins,
    streakMilestones: ms is YamlMap
        ? {
            for (final e in ms.entries)
              if (int.tryParse('${e.key}') != null && e.value is int)
                int.parse('${e.key}'): e.value as int,
          }
        : d.streakMilestones,
    dailyGoalItems: coins['daily_goal_items'] as int? ?? d.dailyGoalItems,
    dailyGoalCoins: coins['daily_goal'] as int? ?? d.dailyGoalCoins,
    weeklyGoalItems: coins['weekly_goal_items'] as int? ?? d.weeklyGoalItems,
    weeklyGoalCoins: coins['weekly_goal'] as int? ?? d.weeklyGoalCoins,
    newQuestionsGoal: coins['new_questions_goal'] as int? ?? d.newQuestionsGoal,
    newQuestionsCoins: coins['new_questions'] as int? ?? d.newQuestionsCoins,
    newTopicCoins: coins['new_topic'] as int? ?? d.newTopicCoins,
    reviseGoal: coins['revise_goal'] as int? ?? d.reviseGoal,
    reviseCoins: coins['revise'] as int? ?? d.reviseCoins,
  );
}

/// Parsed `app.config.yaml`. Pure Dart.
class AppConfig {
  const AppConfig({
    required this.appId,
    required this.displayName,
    required this.packageName,
    required this.themeSeedColor,
    required this.themeDark,
    this.designId,
    required this.platforms,
    required this.admobDebug,
    required this.admobRelease,
    required this.adPacing,
    required this.retention,
    this.shop = const ShopConfig(),
    this.goalsReminders = const GoalsRemindersConfig(),
    this.examPractice = const ExamPracticeConfig(),
    required this.playGames,
    this.share = const ShareConfig(),
    this.moreGames = const [],
    this.content = const ContentConfig(),
    this.rewards = const RewardsConfig(),
    this.minigames = const MiniGamesConfig(),
    this.familyMode = const FamilyModeConfig(),
    this.aiEnabled = false,
    this.audience = Audience.adult,
    this.speech = const SpeechConfig(),
    this.privacyUrl = '',
    this.web = const WebConfig(),
  });

  /// The web copy's page settings (`web:`).
  final WebConfig web;

  /// `app.privacy_url`: the published privacy policy (https). Empty hides the Settings link.
  final String privacyUrl;

  final Audience audience;
  final SpeechConfig speech;
  AudiencePolicy get policy => AudiencePolicy(audience);

  final ContentConfig content;
  final RewardsConfig rewards;
  final MiniGamesConfig minigames;
  final FamilyModeConfig familyMode;

  /// `ai.enabled`. No AI feature ships, so this stays false.
  final bool aiEnabled;
  final String appId;
  final String displayName;
  final String packageName;
  final int themeSeedColor; // 0xAARRGGBB
  final bool themeDark;

  /// `theme.design`: the design app id (`craft_lowteen`, `mind_1`, ...) whose tokens, fonts and art
  /// are bundled under `assets/design/`. Null keeps the plain look (seed colour).
  final String? designId;
  final PlatformsConfig platforms;
  final AdmobIds admobDebug;
  final AdmobIds admobRelease;
  final AdPacingConfig adPacing;
  final RetentionConfig retention;
  final ShopConfig shop;
  final GoalsRemindersConfig goalsReminders;
  final ExamPracticeConfig examPractice;
  final PlayGamesConfig playGames;
  final ShareConfig share;

  /// Every `more_games:` entry as written in the config (bundled, no network).
  final List<MoreGame> moreGames;

  /// Entries the "More games" screen shows: not hidden, and never this game itself.
  List<MoreGame> get visibleMoreGames => [
    for (final g in moreGames)
      if (g.status != MoreGameStatus.hidden && g.packageName != packageName) g,
  ];

  /// Play Store page of this game, built from the package name.
  String get storeLink =>
      'https://play.google.com/store/apps/details?id=$packageName';

  /// The link added to share texts, or null when sharing carries no link (mode off, or
  /// internal_test with an empty URL).
  String? get shareLink => switch (share.linkMode) {
    ShareLinkMode.off => null,
    ShareLinkMode.store => storeLink,
    ShareLinkMode.internalTest =>
      share.internalTestUrl.isEmpty ? null : share.internalTestUrl,
  };

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
    final shop = (root['shop'] as YamlMap?) ?? YamlMap();
    final gr = (root['goals_reminders'] as YamlMap?) ?? YamlMap();
    final ep = (root['exam_practice'] as YamlMap?) ?? YamlMap();
    final pg = (root['play_games'] as YamlMap?) ?? YamlMap();
    final share = (root['share'] as YamlMap?) ?? YamlMap();
    final more = (root['more_games'] as YamlList?) ?? YamlList();
    final content = (root['content'] as YamlMap?) ?? YamlMap();
    final release = (content['daily_release'] as YamlMap?) ?? YamlMap();
    const dflt = ContentConfig();
    bool enabled(Object? p) =>
        p is YamlMap ? (p['enabled'] as bool? ?? false) : false;
    final mg = (root['minigames'] as YamlMap?) ?? YamlMap();
    final ai = (root['ai'] as YamlMap?) ?? YamlMap();
    final audience = Audience.parse(root['audience'] as String?);
    final policy = AudiencePolicy(audience);
    final speech = (root['speech'] as YamlMap?) ?? YamlMap();
    final webCfg = (root['web'] as YamlMap?) ?? YamlMap();
    return AppConfig(
      audience: audience,
      speech: SpeechConfig(
        autoRead: speech['auto_read'] as bool? ?? false,
        locale: speech['locale'] as String? ?? 'en-AU',
      ),
      rewards: _parseRewards(root),
      minigames: MiniGamesConfig(coinPrice: mg['coin_price'] as int? ?? 200),
      familyMode: FamilyModeConfig(enabled: enabled(root['family_mode'])),
      aiEnabled: ai['enabled'] as bool? ?? false,
      content: ContentConfig(
        enabled: content['enabled'] as bool? ?? false,
        baseUrl: content['base_url'] as String? ?? dflt.baseUrl,
        signingPublicKey:
            content['signing_public_key'] as String? ?? dflt.signingPublicKey,
        signingKeyId: content['signing_key_id'] as String? ?? dflt.signingKeyId,
        mobileConfirmMb:
            content['mobile_confirm_mb'] as int? ?? dflt.mobileConfirmMb,
        dailyRelease: ReleaseConfig(
          initialPerSubject: release['initial_per_subject'] as int? ?? 10,
          perDayPerSubject: release['per_day_per_subject'] as int? ?? 2,
          requirePassed: release['require_passed'] as bool? ?? true,
        ),
      ),
      appId: app['id'] as String,
      displayName: app['display_name'] as String,
      packageName: app['package_name'] as String,
      privacyUrl: app['privacy_url'] as String? ?? '',
      web: WebConfig(
        description: (webCfg['description'] as String? ?? '').trim(),
        indexable: webCfg['indexable'] as bool? ?? false,
        playStoreUrl: (webCfg['play_store_url'] as String? ?? '').trim(),
      ),
      themeSeedColor: _parseColor(theme['seed_color'] as String? ?? '#2EC4B6'),
      themeDark: theme['dark'] as bool? ?? true,
      designId: theme['design'] as String?,
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
        childDirected:
            policy.childDirectedAds || (ads['child_directed'] as bool? ?? true),
        interstitialsEnabled: false,
        rewardedEnabled:
            policy.rewardedAllowed &&
            (ads['rewarded_enabled'] as bool? ?? true),
        maxAdContentRating: ads['max_ad_content_rating'] as String? ?? 'G',
      ),
      retention: RetentionConfig(
        dailyReward: ret['daily_reward'] as bool? ?? true,
        streaks: ret['streaks'] as bool? ?? true,
        dailyChallenges: ret['daily_challenges'] as bool? ?? true,
        achievements: ret['achievements'] as bool? ?? true,
        gameChallenges: ret['game_challenges'] as bool? ?? false,
      ),
      shop: ShopConfig(
        extraThemes: shop['extra_themes'] as bool? ?? false,
        soundPacks: shop['sound_packs'] as bool? ?? false,
      ),
      goalsReminders: GoalsRemindersConfig(
        parentArea: gr['parent_area'] as bool? ?? false,
        settingsRow: gr['settings_row'] as bool? ?? true,
      ),
      examPractice: ExamPracticeConfig(
        enabled: ep['enabled'] as bool? ?? false,
      ),
      playGames: PlayGamesConfig(
        enabled: policy.signInAllowed && (pg['enabled'] as bool? ?? false),
        appId: pg['app_id'] as String? ?? 'PLACEHOLDER_PLAY_GAMES_APP_ID',
        leaderboardHighScore:
            pg['leaderboard_high_score'] as String? ??
            'PLACEHOLDER_LEADERBOARD_ID',
      ),
      share: ShareConfig(
        linkMode: ShareLinkMode.parse(share['link_mode'] as String?),
        internalTestUrl: (share['internal_test_url'] as String? ?? '').trim(),
      ),
      moreGames: [
        for (final e in more.whereType<YamlMap>())
          MoreGame(
            id: e['id'] as String,
            packageName: e['package_name'] as String,
            name: e['name'] as String,
            tagline: e['tagline'] as String? ?? '',
            status: MoreGameStatus.parse(e['status'] as String?),
          ),
      ],
    );
  }

  static int _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  }
}
