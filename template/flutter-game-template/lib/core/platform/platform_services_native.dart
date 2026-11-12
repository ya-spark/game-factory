import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/engine.dart';
import '../ads/ad_service.dart';
import '../ads/admob_ad_service.dart';
import '../config/app_config.dart';
import '../config/products.dart';
import '../content/connectivity_probe.dart';
import '../content/content_io.dart';
import '../identity/identity_service.dart';
import '../identity/play_games_identity_service.dart';
import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/play_games_leaderboard_service.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_service.dart';
import '../purchase/play_purchase_service.dart';
import '../purchase/purchase_service.dart';
import '../save/play_games_save.dart';
import '../save/save_service.dart';

/// Android: the real vendor-backed services (Play Games, AdMob, Play Billing, local notifications).
CloudSaveBackend createCloudSave(AppConfig config) =>
    config.playGames.enabled ? PlayGamesCloudSave() : const NoCloudSave();

IdentityService createIdentity(AppConfig config, SharedPreferences prefs) {
  final local = LocalIdentityService(prefs);
  return config.playGames.enabled ? PlayGamesIdentityService(local) : local;
}

LeaderboardService createLeaderboard(
  AppConfig config,
  SharedPreferences prefs,
) {
  final local = LocalLeaderboardService(prefs);
  return config.playGames.enabled ? PlayGamesLeaderboardService(local) : local;
}

AdService createAdService(
  AppConfig config, {
  required bool release,
  required bool adsRemoved,
}) => AdMobAdService(
  ids: config.admobFor(release: release),
  pacing: config.adPacing,
  isReleaseBuild: release,
)..adsRemoved = adsRemoved;

PurchaseService createPurchaseService(ProductCatalog catalog) =>
    PlayPurchaseService(catalog);

NotificationService createNotificationService() => LocalNotificationService();

Future<ContentStore> createContentStore() => openContentCache();

ContentFetcher createContentFetcher() => HttpContentFetcher();

ConnectivityProbe createConnectivityProbe() => PluginConnectivityProbe();
