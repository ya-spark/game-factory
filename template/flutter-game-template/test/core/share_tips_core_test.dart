import 'dart:io';
import 'dart:math';

import 'package:flutter_game_template/core/audio/audio_service.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/core/share/share_service.dart';
import 'package:flutter_game_template/core/tips/tip_service.dart';
import 'package:flutter_game_template/game/tips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tips', () {
    test('every tip is non-empty, at most 80 characters and unique', () {
      expect(gameTips.length, greaterThanOrEqualTo(15));
      for (final t in gameTips) {
        expect(t.trim(), isNotEmpty);
        expect(t.length, lessThanOrEqualTo(80), reason: t);
      }
      expect(gameTips.toSet().length, gameTips.length);
    });

    test('the same tip never appears twice in a row', () {
      for (var seed = 0; seed < 20; seed++) {
        final svc = TipService(random: Random(seed));
        String? last;
        for (var i = 0; i < gameTips.length * 6; i++) {
          final t = svc.next();
          expect(t, isNot(last), reason: 'seed $seed, draw $i');
          last = t;
        }
      }
    });

    test('a bag deals every tip once before repeating', () {
      final svc = TipService(random: Random(3));
      final bag = {for (var i = 0; i < gameTips.length; i++) svc.next()};
      expect(bag.length, gameTips.length);
    });

    test('tip of the day is stable per day and changes by day', () {
      final svc = TipService();
      expect(svc.tipOfTheDay(100), svc.tipOfTheDay(100));
      expect(svc.tipOfTheDay(100), isNot(svc.tipOfTheDay(101)));
    });
  });

  group('share texts', () {
    test('without a link no link is added and Share app is a no-op', () async {
      final f = FakeShareService(gameName: 'Test Game');
      await f.shareScore(score: 42);
      await f.shareAchievement(title: 'Sky High');
      await f.shareApp(bestScore: 42);
      expect(f.hasLink, isFalse);
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Test Game: 42. Can you beat it?',
        'I unlocked "Sky High" in Test Game! Can you beat it?',
      ]);
    });

    test('with a link it follows the message on a new line', () async {
      final f = FakeShareService(link: 'https://example.com/x');
      await f.shareScore(score: 7);
      await f.shareAchievement(title: 'Sky High');
      await f.shareApp(bestScore: 9);
      await f.shareApp();
      const link = '\nhttps://example.com/x';
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Test Game: 7. Can you beat it?$link',
        'I unlocked "Sky High" in Test Game! Can you beat it?$link',
        'This is my high score in Test Game: 9. Can you beat it?$link',
        'Try Test Game!$link',
      ]);
    });
  });

  group('share link config', () {
    AppConfig load(String shareYaml) {
      final base = File('app.config.yaml').readAsStringSync();
      final cut = base.indexOf('\nshare:');
      final end = base.indexOf('\n# Retention');
      return AppConfig.fromYamlString(
        '${base.substring(0, cut)}\n$shareYaml\n${base.substring(end)}',
      );
    }

    test('the shipped default is internal_test with no URL (no link)', () {
      final c = AppConfig.fromYamlString(
        File('app.config.yaml').readAsStringSync(),
      );
      expect(c.share.linkMode, ShareLinkMode.internalTest);
      expect(c.shareLink, isNull);
    });

    test('store uses the Play Store page of the package', () {
      final c = load('share:\n  link_mode: store');
      expect(
        c.shareLink,
        'https://play.google.com/store/apps/details?id=${c.packageName}',
      );
    });

    test('off, and internal_test with an empty URL, give no link', () {
      expect(load('share:\n  link_mode: off').shareLink, isNull);
      expect(
        load('share:\n  link_mode: internal_test\n  internal_test_url: ""')
            .shareLink,
        isNull,
      );
      expect(load('share:\n  link_mode: internal_test').shareLink, isNull);
    });

    test('internal_test with a URL uses it; a missing mode defaults to it', () {
      final c = load('share:\n  internal_test_url: "https://x.y/z"');
      expect(c.share.linkMode, ShareLinkMode.internalTest);
      expect(c.shareLink, 'https://x.y/z');
    });
  });

  group('sound, hand and tip settings in the save', () {
    test('defaults', () {
      const d = SaveData();
      expect(d.masterVolume, 1.0);
      expect(d.ambience, defaultAmbienceId);
      expect(d.voiceOn, isTrue);
      expect(d.leftHanded, isFalse);
      expect(d.tipsOff, isFalse);
      expect(d.tipHomeDay, -1);
    });

    test('round trip through JSON; volume is clamped', () {
      final d = const SaveData().copyWith(
        masterVolume: 0.4,
        ambience: 'night',
        voiceOn: false,
        leftHanded: true,
        tipsOff: true,
        tipHomeDay: 12,
      );
      final back = SaveData.fromJson(d.toJson());
      expect(back.masterVolume, 0.4);
      expect(back.ambience, 'night');
      expect(back.voiceOn, isFalse);
      expect(back.leftHanded, isTrue);
      expect(back.tipsOff, isTrue);
      expect(back.tipHomeDay, 12);
      expect(SaveData.fromJson({'masterVolume': 7}).masterVolume, 1.0);
    });

    test('every ambience track has a file in assets/ambience', () {
      for (final t in ambienceTracks) {
        if (t.$3 == null) continue;
        expect(File('assets/ambience/${t.$3}').existsSync(), isTrue);
      }
      expect(ambienceTracks.any((t) => t.$1 == defaultAmbienceId), isTrue);
    });
  });
}
