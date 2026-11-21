import 'package:flutter/material.dart';

import '../host/game_host.dart';

/// Colours for plain game UI: the container's palette when it gives one, else the Material scheme.
class MiniGamePalette {
  MiniGamePalette(BuildContext context)
    : _p = GameHostScope.of(context).palette(context),
      _c = Theme.of(context).colorScheme;
  final GamePalette? _p;
  final ColorScheme _c;

  Color get bg => _p?.bg ?? _c.surface;
  Color get surface => _p?.surface ?? _c.surfaceContainerHighest;
  Color get text => _p?.text ?? _c.onSurface;
  Color get primary => _p?.primary ?? _c.primary;
  Color get onPrimary => _p?.onPrimary ?? _c.onPrimary;
  Color get accent => _p?.accent ?? _c.secondary;
  Color get onAccent => _p?.onAccent ?? _c.onSecondary;
  Color get border => _p?.border ?? _c.outline;
  Color get success => _p?.success ?? _c.tertiary;
  bool get reduceMotion => _p?.reduceMotion ?? false;
}
