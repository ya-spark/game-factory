import 'package:flutter/widgets.dart';
import 'package:game_core/host/game_host.dart';

import '../core/config/app_config.dart';
import '../core/services.dart';
import '../core/speech/speech_service.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';

/// What the games listed in this app ask of it (speech, banners, settings), backed by this app's
/// services and theme. Provided above every game by `GameHostScope` in `app.dart`.
class AppGameHost extends GameHost {
  const AppGameHost();

  Services? _services(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServicesScope>()?.services;

  @override
  GameReadAloud? readAloud(BuildContext context) {
    final s = _services(context);
    return s == null ? null : _AppReadAloud(ReadAloud(speech: s.speech));
  }

  @override
  bool autoRead(BuildContext context) =>
      _services(context)?.config.speech.autoRead ?? false;

  @override
  bool reduceMotion(BuildContext context) =>
      ThemeTokens.maybeOf(context)?.reduceMotion ?? false;

  @override
  GamePalette? palette(BuildContext context) {
    final t = ThemeTokens.maybeOf(context);
    return t == null
        ? null
        : GamePalette(
            bg: t.bg,
            surface: t.surface,
            text: t.text,
            primary: t.primary,
            onPrimary: t.onPrimary,
            accent: t.accent,
            onAccent: t.onAccent,
            border: t.border,
            success: t.success,
            reduceMotion: t.reduceMotion,
          );
  }

  @override
  bool youngerLevel(BuildContext context) =>
      ThemeTokens.maybeOf(context)?.level == InterfaceLevel.younger;

  @override
  Widget banner(BuildContext context, GameBannerSlot slot) {
    final s = _services(context);
    if (s == null) return const SizedBox.shrink();
    return s.ads.buildBanner(
      slot == GameBannerSlot.preGame
          ? AdPlacement.preGame
          : AdPlacement.postGame,
    );
  }
}

class _AppReadAloud implements GameReadAloud {
  _AppReadAloud(this._reader);
  final ReadAloud _reader;

  @override
  Future<void> read(String text, {String? audioRef}) =>
      _reader.read(text, audioRef: audioRef);

  @override
  Future<void> stop() => _reader.stop();
}
