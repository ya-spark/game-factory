import 'dart:io';

import 'package:flutter_game_template/core/ads/ad_service.dart';
import 'package:flutter_game_template/core/analytics/analytics_service.dart';
import 'package:flutter_game_template/core/audio/audio_service.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_game_template/core/identity/identity_service.dart';
import 'package:flutter_game_template/core/links/external_link_service.dart';
import 'package:flutter_game_template/core/leaderboard/leaderboard_service.dart';
import 'package:flutter_game_template/core/notifications/notification_service.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/purchase/parent_gate_guard.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/core/remote_config/remote_config_service.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/core/share/share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Services wired with fakes (no plugins, no network). Reads the real config files.
Future<Services> buildFakeServices({
  FakeAdService? ads,
  DateTime Function()? clock,
  FakeShareService? share,
  FakeAudioService? audio,
  bool tips = false,
  bool contentEnabled =
      false, // true: a learning game (child profiles, the app shell)
  ParentGateGuard? parentGate,
  SaveService? profileSaves,
  bool familyMode = false,
  bool webShell =
      false, // the web build: no real-money items, browser-only save note
  String webPlayStoreUrl = '', // web.play_store_url
  String?
  audience, // child | teen | adult: overrides `audience:` of app.config.yaml
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  var yaml = File('app.config.yaml').readAsStringSync();
  if (audience != null) {
    yaml = yaml.replaceFirst('audience: adult', 'audience: $audience');
  }
  if (contentEnabled) {
    yaml = yaml.replaceFirst(
      RegExp(r'content:\n  enabled: false'),
      'content:\n  enabled: true',
    );
  }
  if (familyMode) {
    yaml = yaml.replaceFirst(
      RegExp(r'family_mode:\n  enabled: false'),
      'family_mode:\n  enabled: true',
    );
  }
  if (webPlayStoreUrl.isNotEmpty) {
    yaml = yaml.replaceFirst(
      'play_store_url: ""',
      'play_store_url: "$webPlayStoreUrl"',
    );
  }
  final config = AppConfig.fromYamlString(yaml);
  final catalog = ProductCatalog.fromYamlString(
    File('products.yaml').readAsStringSync(),
  );
  final profile = ProfileStore(
    saves: profileSaves ?? MemorySaveService(),
    retention: config.retention,
    cappedRewards: config.content.enabled && config.rewards.starsEnabled
        ? config.rewards
        : null,
    clock: clock,
  );
  await profile.init();
  // Tips are off by default in tests so the dialog never covers the buttons other tests tap.
  if (!tips) await profile.setTipsEnabled(false);
  final services = Services(
    config: config,
    catalog: catalog,
    identity: LocalIdentityService(prefs),
    saves: MemorySaveService(),
    leaderboard: LocalLeaderboardService(prefs),
    ads: ads ?? FakeAdService(),
    purchases: FakePurchaseService(catalog),
    notifications: const NoopNotificationService(),
    analytics: const NoopAnalyticsService(),
    remoteConfig: const NoopRemoteConfigService(),
    profile: profile,
    share: share ?? FakeShareService(),
    audio: audio ?? FakeAudioService(),
    parentGate: parentGate,
    links: FakeExternalLinkService(),
    webShell: webShell,
  );
  services.wirePurchases();
  return services;
}
