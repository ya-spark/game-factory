import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_tokens.dart';

/// The template keeps all five apps under `design/`; a generated game has only its own,
/// copied to `assets/design/` (fonts in `assets/fonts/`).
final designRoot = Directory('design').existsSync()
    ? 'design'
    : 'assets/design';
final fontRoot = Directory('design/fonts').existsSync()
    ? 'design/fonts'
    : 'assets/fonts';

final apps = [
  for (final d in Directory(designRoot).listSync())
    if (File('${d.path}/tokens.json').existsSync())
      d.uri.pathSegments[d.uri.pathSegments.length - 2],
]..sort();

SharedTokens loadShared() =>
    SharedTokens.fromJson(File('$designRoot/tokens.json').readAsStringSync());
AppTokens loadApp(String id) =>
    AppTokens.fromJson(File('$designRoot/$id/tokens.json').readAsStringSync());

void main() {
  final shared = loadShared();

  group('contrast', () {
    test('known ratios', () {
      expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 0.01));
      expect(contrastRatio(0xFFFFFFFF, 0xFFFFFFFF), closeTo(1, 0.001));
    });

    for (final id in apps) {
      final app = loadApp(id);
      for (final e in app.modes.entries) {
        test('$id ${e.key.key}: every token pair is at least 4.5 to 1', () {
          for (final (fg, bg) in contrastPairs) {
            final r = contrastRatio(e.value.color(fg), e.value.color(bg));
            expect(
              r,
              greaterThanOrEqualTo(shared.minContrast),
              reason: '$id/${e.key.key}: $fg on $bg is ${r.toStringAsFixed(2)}',
            );
          }
        });
      }
    }
  });

  group('themes build', () {
    for (final id in apps) {
      final app = loadApp(id);
      for (final mode in app.modes.keys) {
        final levels = app.levels.isEmpty
            ? <InterfaceLevel?>[null]
            : <InterfaceLevel?>[...app.levels.keys];
        for (final level in levels) {
          test('$id ${mode.key} ${level?.name ?? "no level"}', () {
            final t = buildDesignTheme(
              app: app,
              shared: shared,
              mode: mode,
              level: level,
            );
            final tokens = t.extension<ThemeTokens>()!;
            expect(tokens.fontFamily, app.fontFamily);
            expect(t.textTheme.bodyMedium!.fontFamily, app.fontFamily);
            expect(
              tokens.minTouch,
              greaterThanOrEqualTo(shared.size['min_touch']!),
            );
            if (level != null) {
              expect(tokens.minTouch, app.levels[level]!.minTouch);
              expect(
                t.textTheme.bodyMedium!.fontSize,
                closeTo(14 * app.levels[level]!.textScale, 0.001),
              );
            }
            expect(
              tokens.primary.toARGB32(),
              app.modes[mode]!.color('primary'),
            );
          });
        }
      }
    }

    test('a missing mode falls back to the only mode (Mind)', () {
      final app = loadApp('mind_1');
      final t = buildDesignTheme(
        app: app,
        shared: shared,
        mode: DesignMode.study,
      );
      expect(t.extension<ThemeTokens>()!.mode, DesignMode.defaultMode);
    });

    test('reduce motion caps transitions at the fast duration', () {
      final app = loadApp('craft_lowteen');
      final t = buildDesignTheme(
        app: app,
        shared: shared,
        mode: DesignMode.game,
        reduceMotion: true,
      ).extension<ThemeTokens>()!;
      expect(
        t.duration(slow: true).inMilliseconds,
        lessThanOrEqualTo(shared.fastMs),
      );
      expect(t.duration().inMilliseconds, lessThanOrEqualTo(shared.fastMs));
    });

    test('year maps to level', () {
      expect(InterfaceLevel.forYear(0), InterfaceLevel.younger);
      expect(InterfaceLevel.forYear(2), InterfaceLevel.younger);
      expect(InterfaceLevel.forYear(3), InterfaceLevel.older);
    });
  });

  group('fonts', () {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final bytes = File('$fontRoot/$f').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }

    double width(String family, int weight, bool variable) {
      final p = TextPainter(
        text: TextSpan(
          text: 'Mastered the quick brown fox',
          style: designTextStyle(
            family: family,
            variable: variable,
            token: TypeStyleToken(20, weight),
            color: const Color(0xFF000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return p.width;
    }

    final hasNunito = File('$fontRoot/Nunito-Variable.ttf').existsSync();
    final hasJakarta = File('$fontRoot/PlusJakartaSans-Bold.ttf').existsSync();

    test(
      'Nunito renders 400, 700 and 800 as distinct weights',
      skip: !hasNunito,
      () async {
        await load('Nunito', ['Nunito-Variable.ttf']);
        final w4 = width('Nunito', 400, true);
        final w7 = width('Nunito', 700, true);
        final w8 = width('Nunito', 800, true);
        expect(w7, greaterThan(w4));
        expect(w8, greaterThan(w7));
      },
    );

    test(
      'Plus Jakarta Sans loads 400, 700 and 800',
      skip: !hasJakarta,
      () async {
        await load('Plus Jakarta Sans', [
          'PlusJakartaSans-Regular.ttf',
          'PlusJakartaSans-Bold.ttf',
          'PlusJakartaSans-ExtraBold.ttf',
        ]);
        // Three files registered under one family: the weights are told apart by the
        // pubspec entries in a real build; here we check they all load and measure.
        expect(width('Plus Jakarta Sans', 400, false), greaterThan(0));
        expect(width('Plus Jakarta Sans', 800, false), greaterThan(0));
      },
    );
  });

  test('no person-like icon or image in the design files', () {
    const banned = [
      'person',
      'user',
      'face',
      'human',
      'profile',
      'avatar',
      'people',
    ];
    for (final f in Directory(designRoot).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.svg')) continue;
      final name = f.uri.pathSegments.last.toLowerCase();
      for (final b in banned) {
        expect(
          name.contains(b),
          isFalse,
          reason: '${f.path} looks person-like',
        );
      }
    }
  });
}
