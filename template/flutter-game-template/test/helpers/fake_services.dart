import 'dart:io';

import 'package:flutter_game_template/core/ads/ad_service.dart';
import 'package:flutter_game_template/core/analytics/analytics_service.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_game_template/core/identity/identity_service.dart';
import 'package:flutter_game_template/core/leaderboard/leaderboard_service.dart';
import 'package:flutter_game_template/core/notifications/notification_service.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/core/remote_config/remote_config_service.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Services wired with fakes (no plugins, no network). Reads the real config files.
Future<Services> buildFakeServices({
  FakeAdService? ads,
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final config = AppConfig.fromYamlString(
    File('app.config.yaml').readAsStringSync(),
  );
  final catalog = ProductCatalog.fromYamlString(
    File('products.yaml').readAsStringSync(),
  );
  final profile = ProfileStore(
    saves: MemorySaveService(),
    retention: config.retention,
    clock: clock,
  );
  await profile.init();
  final services = Services(
    config: config,
    catalog: catalog,
    identity: PlayGamesIdentityStub(LocalIdentityService(prefs)),
    saves: MemorySaveService(),
    leaderboard: PlayGamesLeaderboardStub(LocalLeaderboardService(prefs)),
    ads: ads ?? FakeAdService(),
    purchases: FakePurchaseService(catalog),
    notifications: const NoopNotificationService(),
    analytics: const NoopAnalyticsService(),
    remoteConfig: const NoopRemoteConfigService(),
    profile: profile,
  );
  services.wirePurchases();
  return services;
}
