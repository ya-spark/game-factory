import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/save/prefs_namespace.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  test('the web prefix is derived from the app id', () {
    expect(webStoragePrefix('craft_lowteen'), 'craft_lowteen.');
    expect(webStoragePrefix('mind_1'), isNot(webStoragePrefix('mind_9')));
  });

  test('two app ids on one storage do not see each other\'s keys', () async {
    // One fake "origin": a single store both games write into, as one browser origin would.
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    addTearDown(SharedPreferences.resetStatic);

    Future<SharedPreferences> open(String appId) async {
      SharedPreferences.resetStatic();
      return openPreferences(prefix: webStoragePrefix(appId));
    }

    final a = await open('game_a');
    await LocalSaveService(a).save(const SaveData(coins: 7));
    await a.setInt('lb.best', 99);

    final b = await open('game_b');
    expect(b.getKeys(), isEmpty);
    expect((await LocalSaveService(b).load()).coins, 0);
    await LocalSaveService(b).save(const SaveData(coins: 3));

    final a2 = await open('game_a');
    expect((await LocalSaveService(a2).load()).coins, 7);
    expect(a2.getInt('lb.best'), 99);
    final b2 = await open('game_b');
    expect((await LocalSaveService(b2).load()).coins, 3);
    expect(b2.getInt('lb.best'), isNull);
  });

  test('web: config fields default to hidden link, noindex', () {
    final c = AppConfig.fromYamlString(
      'app: {id: x, display_name: X, package_name: p}\n'
      'admob: {debug: {app_id: a, banner: b, interstitial: i, rewarded: r}, '
      'release: {app_id: a, banner: b, interstitial: i, rewarded: r}}\n',
    );
    expect(c.web.indexable, isFalse);
    expect(c.web.hasPlayStoreLink, isFalse);
    expect(c.web.description, '');
  });
}
