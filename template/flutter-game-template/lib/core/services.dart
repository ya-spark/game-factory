import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/admob_ad_service.dart';
import 'ads/ad_service.dart';
import 'analytics/analytics_service.dart';
import 'audio/audio_service.dart';
import 'audio/audioplayers_audio_service.dart';
import '../engine/engine.dart';
import 'config/app_config.dart';
import 'content/connectivity_probe.dart';
import 'content/content_io.dart';
import 'content/learning_service.dart';
import 'config/products.dart';
import 'identity/identity_service.dart';
import 'leaderboard/leaderboard_service.dart';
import 'links/external_link_service.dart';
import 'links/url_external_link_service.dart';
import 'notifications/local_notification_service.dart';
import 'notifications/notification_service.dart';
import 'profile/profile_store.dart';
import 'purchase/parent_gate_guard.dart';
import 'purchase/play_purchase_service.dart';
import 'purchase/purchase_service.dart';
import 'remote_config/remote_config_service.dart';
import 'save/play_games_save.dart';
import 'save/save_service.dart';
import 'share/share_service.dart';
import 'share/system_share_service.dart';
import 'tips/tip_service.dart';

/// Composition root: every service the game and UI use, behind interfaces.
/// This is the ONLY place that picks vendor implementations.
class Services {
  Services({
    required this.config,
    required this.catalog,
    required this.identity,
    required this.saves,
    required this.leaderboard,
    required this.ads,
    required this.purchases,
    required this.notifications,
    required this.analytics,
    required this.remoteConfig,
    required this.profile,
    required this.share,
    required this.audio,
    ExternalLinkService? links,
    this.learning,
    TipService? tips,
    ParentGateGuard? parentGate,
  }) : links = links ?? FakeExternalLinkService(),
       tips = tips ?? TipService(),
       parentGate = parentGate ?? ParentGateGuard();

  /// True while the game screen is on the navigator (set by `GameScreen`). The home tip of the day
  /// never opens while it is true, whatever the route stack looks like.
  bool inRun = false;

  /// Parent gate rules and lock state, shared so the lock survives closing the dialog.
  final ParentGateGuard parentGate;

  final AppConfig config;
  final ProductCatalog catalog;
  final IdentityService identity;
  final SaveService saves;
  final LeaderboardService leaderboard;
  final AdService ads;
  final PurchaseService purchases;
  final NotificationService notifications;
  final AnalyticsService analytics;
  final RemoteConfigService remoteConfig;
  final ProfileStore profile;
  final ShareService share;
  final AudioService audio;
  final TipService tips;

  /// Learning content, release and packs. Null in tests that do not need it.
  final LearningService? learning;

  /// Opens Play Store pages ("More games").
  final ExternalLinkService links;

  /// Production wiring (Android v1).
  static Future<Services> create({
    required AppConfig config,
    required ProductCatalog catalog,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final local = LocalIdentityService(prefs);
    final playGames = config.playGames.enabled;
    final saves = SyncingSaveService(
      LocalSaveService(prefs),
      playGames ? PlayGamesCloudSave() : const NoCloudSave(),
    );
    final profile = ProfileStore(saves: saves, retention: config.retention);
    await profile.init();

    final ads = AdMobAdService(
      ids: config.admobFor(release: kReleaseMode),
      pacing: config.adPacing,
      isReleaseBuild: kReleaseMode,
    )..adsRemoved = profile.data.adsRemoved;
    final purchases = PlayPurchaseService(catalog);
    final notifications = LocalNotificationService();

    // Learning content: built-in assets plus the static server. Check stays silent and offline-safe.
    final store = await openContentCache();
    if (config.content.signingOff) {
      debugPrint(
        'WARNING: content signing is off (content.signing_public_key is a placeholder). '
        'An unsigned content index is accepted until the owner adds a key.',
      );
    }
    final learning = LearningService(
      config: config.content,
      profile: profile,
      purchases: purchases,
      connectivity: PluginConnectivityProbe(),
      repository: ContentRepository(
        builtIn: BuiltInContentSource((path) async {
          try {
            final d = await rootBundle.load(path);
            return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
          } on Object {
            return null;
          }
        }, appId: config.appId),
        server: ServerContentSource(
          baseUrl: config.content.baseUrl,
          appId: config.appId,
          fetcher: HttpContentFetcher(),
          store: store,
          signing: config.content.signing,
        ),
        store: store,
        isOwned: profile.ownsPack,
      ),
    );

    final s = Services(
      config: config,
      catalog: catalog,
      identity: playGames ? PlayGamesIdentityService(local) : local,
      saves: saves,
      leaderboard: playGames
          ? PlayGamesLeaderboardService(LocalLeaderboardService(prefs))
          : LocalLeaderboardService(prefs),
      ads: ads,
      purchases: purchases,
      notifications: notifications,
      analytics: const NoopAnalyticsService(),
      remoteConfig: const NoopRemoteConfigService(),
      profile: profile,
      share: SystemShareService(
        gameName: config.displayName,
        link: config.shareLink,
      ),
      audio: AudioplayersAudioService(),
      links: const UrlExternalLinkService(),
      learning: learning,
    );
    s.wirePurchases();
    return s;
  }

  /// Applies purchase deliveries to the profile and the ad service.
  void wirePurchases() {
    purchases.updates.listen((u) async {
      await profile.deliverPurchase(u, catalog);
      ads.adsRemoved = profile.data.adsRemoved;
    });
  }

  /// Explicit "Sign in with Google Play Games" (settings). True when signed in afterwards.
  Future<bool> connectPlayGames() async {
    await identity.signIn();
    return _syncAfterSignIn();
  }

  /// Pulls the cloud save and pushes the best score once a Play Games player is known.
  Future<bool> _syncAfterSignIn() async {
    if (!identity.isSignedIn) return false;
    await profile.reload();
    await leaderboard.submitScore(
      config.playGames.leaderboardHighScore,
      profile.data.bestScore,
    );
    return true;
  }

  /// Initialises the slow, plugin-backed services after the first frame.
  Future<void> initPlugins() async {
    await Future.wait([
      ads.initialize(),
      purchases.initialize(),
      notifications.initialize(),
      remoteConfig.refresh(),
    ]);
    await identity.refresh();
    await _syncAfterSignIn();
    // Silent, at most once a day, failures ignored.
    if (config.content.enabled) await learning?.checkForUpdates();
  }
}

/// Makes [Services] available to the widget tree.
class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });
  final Services services;

  static Services of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'No ServicesScope above this context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServicesScope old) => services != old.services;
}
