import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/engine.dart';
import '../ads/ad_service.dart';
import '../config/app_config.dart';
import '../config/products.dart';
import '../content/connectivity_probe.dart';
import '../content/content_io_web.dart';
import '../identity/identity_service.dart';
import '../leaderboard/leaderboard_service.dart';
import '../notifications/notification_service.dart';
import '../purchase/purchase_service.dart';
import '../save/save_service.dart';

/// Web build (a test copy on the Hostinger VPS). No vendor SDK is imported here: ads, billing,
/// Play Games and notifications do not exist in a browser, so they are stubs that do nothing and
/// say so. Progress is kept in the browser's local storage (SharedPreferences).
CloudSaveBackend createCloudSave(AppConfig config) => const NoCloudSave();

IdentityService createIdentity(AppConfig config, SharedPreferences prefs) =>
    LocalIdentityService(prefs);

LeaderboardService createLeaderboard(
  AppConfig config,
  SharedPreferences prefs,
) => LocalLeaderboardService(prefs);

AdService createAdService(
  AppConfig config, {
  required bool release,
  required bool adsRemoved,
}) => NoAdService();

PurchaseService createPurchaseService(ProductCatalog catalog) =>
    UnavailablePurchaseService();

NotificationService createNotificationService() =>
    const NoopNotificationService();

Future<ContentStore> createContentStore() => openContentCache();

ContentFetcher createContentFetcher() => HttpContentFetcher();

/// A browser cannot tell Wi-Fi from mobile data, so no mobile-data warning is shown.
ConnectivityProbe createConnectivityProbe() => FakeConnectivityProbe();
