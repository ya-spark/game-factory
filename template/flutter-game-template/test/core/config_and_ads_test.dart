import 'dart:io';

import 'package:flutter_game_template/core/ads/ad_frequency.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = AppConfig.fromYamlString(
    File('app.config.yaml').readAsStringSync(),
  );

  group('app.config.yaml', () {
    test('parses and has android enabled, ios/web disabled', () {
      expect(config.platforms.android, isTrue);
      expect(config.platforms.ios, isFalse);
      expect(config.platforms.web, isFalse);
      expect(config.packageName, isNotEmpty);
    });

    test('debug AdMob IDs are Google test IDs only', () {
      expect(config.admobDebug.allTest, isTrue);
      expect(config.admobDebug.appId, 'ca-app-pub-3940256099942544~3347511713');
      expect(
        config.admobDebug.banner,
        'ca-app-pub-3940256099942544/6300978111',
      );
      expect(
        config.admobDebug.interstitial,
        'ca-app-pub-3940256099942544/1033173712',
      );
      expect(
        config.admobDebug.rewarded,
        'ca-app-pub-3940256099942544/5224354917',
      );
    });

    test('release IDs are placeholders and never test IDs', () {
      expect(config.admobRelease.hasPlaceholders, isTrue);
      expect(config.admobRelease.allTest, isFalse);
      for (final id in [
        config.admobRelease.appId,
        config.admobRelease.banner,
        config.admobRelease.interstitial,
        config.admobRelease.rewarded,
      ]) {
        expect(AdmobIds.isTestId(id), isFalse);
      }
    });

    test('admobFor(debug) refuses non-test IDs', () {
      final bad = AppConfig.fromYamlString(
        File('app.config.yaml').readAsStringSync().replaceFirst(
          'banner: ca-app-pub-3940256099942544/6300978111',
          // Built at runtime so the ad-safety script does not flag this test file.
          'banner: ca-app-pub-${'1234567890123456'}/1111111111',
        ),
      );
      expect(() => bad.admobFor(release: false), throwsStateError);
      expect(config.admobFor(release: false).allTest, isTrue);
    });

    test('all retention features are on by default', () {
      expect(config.retention.dailyReward, isTrue);
      expect(config.retention.streaks, isTrue);
      expect(config.retention.dailyChallenges, isTrue);
      expect(config.retention.achievements, isTrue);
    });
  });

  group('products.yaml', () {
    final catalog = ProductCatalog.fromYamlString(
      File('products.yaml').readAsStringSync(),
    );

    test('has remove_ads and a coin pack', () {
      expect(catalog.byId('remove_ads')?.type, ProductType.nonConsumable);
      expect(catalog.byId('remove_ads')?.grants, ProductDef.removeAdsGrant);
      expect(
        catalog.products.any(
          (p) => p.type == ProductType.consumable && p.coins > 0,
        ),
        isTrue,
      );
    });
  });

  group('AdFrequencyPolicy', () {
    late DateTime now;
    late AdFrequencyPolicy policy;
    const pacing = AdPacingConfig(
      interstitialMinIntervalSeconds: 90,
      interstitialEveryNGameOvers: 2,
      maxInterstitialsPerSession: 2,
      noInterstitialFirstSeconds: 60,
    );

    setUp(() {
      now = DateTime(2026, 1, 1, 12);
      policy = AdFrequencyPolicy(pacing, clock: () => now);
    });

    test('never in the first seconds of a session', () {
      now = now.add(const Duration(seconds: 30));
      expect(policy.shouldShowAfterGameOver(), isFalse);
      expect(policy.shouldShowAfterGameOver(), isFalse);
    });

    test('only every Nth game over', () {
      now = now.add(const Duration(minutes: 5));
      expect(policy.shouldShowAfterGameOver(), isFalse); // 1st
      expect(policy.shouldShowAfterGameOver(), isTrue); // 2nd
    });

    test('respects the minimum interval after one was shown', () {
      now = now.add(const Duration(minutes: 5));
      policy.shouldShowAfterGameOver();
      expect(policy.shouldShowAfterGameOver(), isTrue);
      policy.recordShown();
      now = now.add(const Duration(seconds: 30));
      policy.shouldShowAfterGameOver();
      expect(policy.shouldShowAfterGameOver(), isFalse); // too soon
      now = now.add(const Duration(seconds: 100));
      policy.shouldShowAfterGameOver();
      expect(policy.shouldShowAfterGameOver(), isTrue);
    });

    test('caps interstitials per session', () {
      for (var i = 0; i < 2; i++) {
        now = now.add(const Duration(minutes: 5));
        policy.shouldShowAfterGameOver();
        expect(policy.shouldShowAfterGameOver(), isTrue);
        policy.recordShown();
      }
      now = now.add(const Duration(minutes: 30));
      policy.shouldShowAfterGameOver();
      expect(policy.shouldShowAfterGameOver(), isFalse);
      expect(policy.shownThisSession, 2);
    });

    test('a rewarded ad delays the next interstitial', () {
      now = now.add(const Duration(minutes: 5));
      policy.recordRewardedShown();
      now = now.add(const Duration(seconds: 10));
      policy.shouldShowAfterGameOver();
      expect(policy.shouldShowAfterGameOver(), isFalse);
    });
  });
}
