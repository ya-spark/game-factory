import 'dart:io';

import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

// The game's own config with the profile switches put back to the adult baseline, so these tests
// hold for every generated game (craft and mind set other values).
String _base() {
  var s = File('app.config.yaml').readAsStringSync();
  s = s.replaceFirst(
    RegExp('^audience: \\w+', multiLine: true),
    'audience: adult',
  );
  s = s.replaceFirst(
    RegExp('  rewarded_enabled: \\S+'),
    '  rewarded_enabled: true',
  );
  s = s.replaceFirst(
    RegExp('  child_directed: \\S+'),
    '  child_directed: false',
  );
  s = s.replaceFirst(
    RegExp('  max_ad_content_rating: \\S+'),
    '  max_ad_content_rating: PG',
  );
  return s.replaceFirst(
    RegExp('play_games:\\n  enabled: \\w+'),
    'play_games:\n  enabled: false',
  );
}

String _yaml({
  String audience = 'adult',
  String ads = '',
  String playGames = 'true',
}) {
  var s = _base();
  s = s.replaceFirst('audience: adult', 'audience: $audience');
  if (ads.isNotEmpty) {
    final key = ads.trim().split(':').first;
    s = s.replaceFirst(RegExp('  $key: \\S+'), ads);
  }
  s = s.replaceFirst(
    'play_games:\n  enabled: false',
    'play_games:\n  enabled: $playGames',
  );
  return s;
}

void main() {
  test('the adult baseline has no interstitials and a rewarded Continue', () {
    final c = AppConfig.fromYamlString(_base());
    expect(c.audience, Audience.adult);
    expect(c.adPacing.interstitialsEnabled, isFalse);
    expect(c.adPacing.rewardedEnabled, isTrue);
  });

  test('interstitials stay off even if the config asks for them', () {
    final c = AppConfig.fromYamlString(
      _yaml(ads: '  interstitials_enabled: true'),
    );
    expect(c.adPacing.interstitialsEnabled, isFalse);
  });

  for (final a in ['child', 'teen']) {
    test('$a profile: child-directed ads, no rewarded, parent gate', () {
      final c = AppConfig.fromYamlString(
        _yaml(audience: a, ads: '  rewarded_enabled: true'),
      );
      expect(c.adPacing.childDirected, isTrue);
      expect(c.adPacing.rewardedEnabled, isFalse);
      expect(c.policy.rewardedAllowed, isFalse);
      expect(c.policy.parentGateOnPurchases, isTrue);
      expect(c.policy.parentGateOnCoinSpends, isTrue);
    });
  }

  test('child profile has no Play Games sign-in, teen allows it', () {
    expect(
      AppConfig.fromYamlString(_yaml(audience: 'child')).playGames.enabled,
      isFalse,
    );
    expect(
      AppConfig.fromYamlString(_yaml(audience: 'teen')).playGames.enabled,
      isTrue,
    );
    expect(
      AppConfig.fromYamlString(_yaml(audience: 'adult')).playGames.enabled,
      isTrue,
    );
  });

  test('adult profile: rewarded Continue, no parent gate', () {
    final c = AppConfig.fromYamlString(_yaml());
    expect(c.policy.rewardedAllowed, isTrue);
    expect(c.policy.parentGateOnPurchases, isFalse);
    expect(c.policy.childDirectedAds, isFalse);
  });

  test('there is no in-play ad placement', () {
    expect(AdPlacement.values.map((p) => p.configName), [
      'menu',
      'pre_game',
      'post_game',
    ]);
  });

  test('speech.auto_read defaults to off', () {
    final c = AppConfig.fromYamlString(
      File('app.config.yaml').readAsStringSync(),
    );
    expect(c.speech.autoRead, isFalse);
    expect(c.speech.locale, 'en-AU');
  });
}
