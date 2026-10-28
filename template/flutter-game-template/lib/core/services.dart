import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/admob_ad_service.dart';
import 'ads/ad_service.dart';
import 'analytics/analytics_service.dart';
import 'config/app_config.dart';
import 'config/products.dart';
import 'identity/identity_service.dart';
import 'leaderboard/leaderboard_service.dart';
import 'notifications/local_notification_service.dart';
import 'notifications/notification_service.dart';
import 'profile/profile_store.dart';
import 'purchase/play_purchase_service.dart';
import 'purchase/purchase_service.dart';
import 'remote_config/remote_config_service.dart';
import 'save/play_games_save_stub.dart';
import 'save/save_service.dart';

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
  });

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

  /// Production wiring (Android v1).
  static Future<Services> create({
    required AppConfig config,
    required ProductCatalog catalog,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final local = LocalIdentityService(prefs);
    final saves = SyncingSaveService(
      LocalSaveService(prefs),
      PlayGamesCloudSaveStub(),
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

    final s = Services(
      config: config,
      catalog: catalog,
      identity: PlayGamesIdentityStub(local),
      saves: saves,
      leaderboard: PlayGamesLeaderboardStub(LocalLeaderboardService(prefs)),
      ads: ads,
      purchases: purchases,
      notifications: notifications,
      analytics: const NoopAnalyticsService(),
      remoteConfig: const NoopRemoteConfigService(),
      profile: profile,
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

  /// Initialises the slow, plugin-backed services after the first frame.
  Future<void> initPlugins() async {
    await Future.wait([
      ads.initialize(),
      purchases.initialize(),
      notifications.initialize(),
      remoteConfig.refresh(),
    ]);
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
