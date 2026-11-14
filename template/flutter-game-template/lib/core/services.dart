import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'ads/ad_service.dart';
import 'analytics/analytics_service.dart';
import 'speech/speech_service.dart';
import 'speech/tts_speech_service.dart';
import 'audio/audio_service.dart';
import 'audio/audioplayers_audio_service.dart';
import '../engine/engine.dart';
import 'config/app_config.dart';
import 'content/learning_service.dart';
import 'config/products.dart';
import 'identity/identity_service.dart';
import 'leaderboard/leaderboard_service.dart';
import 'links/external_link_service.dart';
import 'links/url_external_link_service.dart';
import 'notifications/notification_service.dart';
import 'platform/platform_services.dart';
import 'profile/profile_store.dart';
import 'purchase/parent_gate_guard.dart';
import 'purchase/purchase_service.dart';
import 'remote_config/remote_config_service.dart';
import 'save/prefs_namespace.dart';
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
    this.speech = const NoopSpeechService(),
    this.learning,
    TipService? tips,
    ParentGateGuard? parentGate,
    this.webShell = isWebBuild,
  }) : links = links ?? FakeExternalLinkService(),
       tips = tips ?? TipService(),
       parentGate = parentGate ?? ParentGateGuard();

  /// True while the game screen is on the navigator (set by `GameScreen`). The home tip of the day
  /// never opens while it is true, whatever the route stack looks like.
  bool inRun = false;

  /// Parent gate rules and lock state, shared so the lock survives closing the dialog.
  final ParentGateGuard parentGate;

  /// True in the web build. The UI then hides every real-money item (coin packs, Remove Ads, Full
  /// Unlock, extra packs, Restore) and shows the browser-only save note. Tests set it directly.
  final bool webShell;

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

  /// Reads questions aloud (Quick quiz speaker button, `speech.auto_read`).
  final SpeechService speech;
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
    final prefs = await openPreferences(prefix: preferencesPrefix(config));
    final saves = SyncingSaveService(
      LocalSaveService(prefs),
      createCloudSave(config),
    );
    final profile = ProfileStore(
      saves: saves,
      retention: config.retention,
      // Craft apps (learning games with stars): the daily reward and challenges are capped too.
      cappedRewards: config.content.enabled && config.rewards.starsEnabled
          ? config.rewards
          : null,
    );
    await profile.init();

    // Vendor-backed on Android, honest stubs in the web build (see platform/platform_services.dart).
    final ads = createAdService(
      config,
      release: kReleaseMode,
      adsRemoved: profile.data.adsRemoved,
    );
    final purchases = createPurchaseService(catalog);
    final notifications = createNotificationService();

    // Learning content: built-in assets plus the static server. Check stays silent and offline-safe.
    final store = await createContentStore();
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
      connectivity: createConnectivityProbe(),
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
          baseUrl: _contentBaseUrl(config),
          appId: config.appId,
          fetcher: createContentFetcher(),
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
      identity: createIdentity(config, prefs),
      saves: saves,
      leaderboard: createLeaderboard(config, prefs),
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
      speech: TtsSpeechService(locale: config.speech.locale),
      links: const UrlExternalLinkService(),
      learning: learning,
    );
    s.wirePurchases();
    return s;
  }

  /// The content server base URL. `--dart-define=CONTENT_BASE_URL=https://.../v1/` overrides the
  /// one in app.config.yaml at build time (it must stay https, with a path).
  static const String _contentBaseUrlOverride = String.fromEnvironment(
    'CONTENT_BASE_URL',
  );
  static String _contentBaseUrl(AppConfig config) =>
      _contentBaseUrlOverride.isEmpty
      ? config.content.baseUrl
      : _contentBaseUrlOverride;

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
