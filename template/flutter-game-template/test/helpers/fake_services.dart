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
  bool? familyMode, // null: as in app.config.yaml
  bool shopExtras =
      false, // shop.extra_themes and shop.sound_packs on (the Mind hubs)
  bool webShell =
      false, // the web build: no real-money items, browser-only save note
  String webPlayStoreUrl = '', // web.play_store_url
  NotificationService? notifications,
  bool goalsParentArea = false, // goals_reminders.parent_area (the Craft apps)
  bool settingsReminderRow = true, // goals_reminders.settings_row
  bool examPractice = false, // exam_practice.enabled (Champion)
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
  if (familyMode != null) {
    yaml = yaml.replaceFirst(
      RegExp(r'family_mode:\n  enabled: (true|false)'),
      'family_mode:\n  enabled: $familyMode',
    );
  }
  if (shopExtras) {
    yaml = yaml
        .replaceFirst('extra_themes: false', 'extra_themes: true')
        .replaceFirst('sound_packs: false', 'sound_packs: true');
  }
  {
    yaml = yaml.replaceFirst(
      RegExp(
        r'goals_reminders:\n  parent_area: (true|false)\n  settings_row: (true|false)',
      ),
      'goals_reminders:\n  parent_area: $goalsParentArea\n  settings_row: $settingsReminderRow',
    );
  }
  yaml = yaml.replaceFirst(
    RegExp(r'exam_practice:\n  enabled: (true|false)'),
    'exam_practice:\n  enabled: $examPractice',
  );
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
    notifications: notifications ?? const NoopNotificationService(),
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

/// Records what is scheduled; [permission] is what `requestPermission` answers.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permission = true});
  bool permission;
  int permissionAsks = 0;
  final Map<int, DateTime> scheduled = {};
  final Map<int, String> bodies = {};
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return permission;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    scheduled[id] = when;
    bodies[id] = body;
  }

  @override
  Future<void> cancelById(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    bodies.remove(id);
  }

  @override
  Future<void> cancelAll() async => scheduled.clear();
}
