import 'dart:math' as math;

import 'design_tokens.dart';

/// A shop colour theme: a seed colour plus light or dark. Pure Dart (no Flutter imports).
/// The palette is computed from the seed and checked for contrast by a test, so every theme
/// keeps text and button colours readable. Scene art is not affected.
class ColorThemeSpec {
  const ColorThemeSpec(this.id, this.seed, {this.dark = false});
  final String id;

  /// 0xFFRRGGBB.
  final int seed;
  final bool dark;
}

/// Themes with a palette. `default` (Classic) is absent: it keeps the app's own design colours.
const List<ColorThemeSpec> colorThemeSpecs = [
  ColorThemeSpec('sunset', 0xFFE8743B),
  ColorThemeSpec('forest', 0xFF2F8F4E),
  ColorThemeSpec('ocean', 0xFF1E88C8),
  // Extra themes (Mind hubs, `shop.extra_themes`).
  ColorThemeSpec('midnight', 0xFF5C6BC0, dark: true),
  ColorThemeSpec('lavender', 0xFF8E6CC8),
  ColorThemeSpec('sand', 0xFFC2A15B),
  ColorThemeSpec('slate', 0xFF607D8B),
];

ColorThemeSpec? colorThemeSpec(String id) {
  for (final s in colorThemeSpecs) {
    if (s.id == id) return s;
  }
  return null;
}

/// Colour tokens (by design token name) that a theme replaces. Others (alt, success, coin and
/// their on-colours) keep the app's values. Null for Classic or an unknown id.
Map<String, int>? colorThemeOverrides(String id) {
  final s = colorThemeSpec(id);
  return s == null ? null : themePalette(s);
}

Map<String, int> themePalette(ColorThemeSpec s) {
  final h = _hue(s.seed);
  final dark = s.dark;
  final bg = dark ? _hsl(h, .30, .10) : _hsl(h, .45, .95);
  final surface = dark ? _hsl(h, .28, .15) : _hsl(h, .30, .99);
  final surfaceAlt = dark ? _hsl(h, .26, .21) : _hsl(h, .40, .90);
  final text = dark ? _hsl(h, .30, .94) : _hsl(h, .35, .12);
  final mutedL = dark ? .80 : .30;
  final textMuted = _hsl(h, .18, mutedL);
  final primary = _button(s.seed, dark);
  final accent = _button(_hsl((h + 35) % 360, .65, .45), dark);
  return {
    'bg': bg,
    'surface': surface,
    'surface-alt': surfaceAlt,
    'text': text,
    'text-muted': textMuted,
    'primary': primary.$1,
    'on-primary': primary.$2,
    'accent': accent.$1,
    'on-accent': accent.$2,
    'border': dark ? _hsl(h, .22, .32) : _hsl(h, .25, .78),
  };
}

const double _minRatio = 4.5;
const int _white = 0xFFFFFFFF;
const int _ink = 0xFF111111;

/// A fill and its label colour with at least 4.5:1: the seed itself when it works, else
/// darkened (light themes) or lightened (dark themes) until it does.
(int, int) _button(int base, bool dark) {
  var c = base;
  for (var i = 0; i < 40; i++) {
    for (final on in [_white, _ink]) {
      if (contrastRatio(c, on) >= _minRatio) return (c, on);
    }
    c = _shift(c, dark ? 0.03 : -0.03);
  }
  return (dark ? _white : _ink, dark ? _ink : _white);
}

int _shift(int argb, double dl) {
  final (h, s, l) = _toHsl(argb);
  return _hsl(h, s, (l + dl).clamp(0.0, 1.0));
}

double _hue(int argb) => _toHsl(argb).$1;

(double, double, double) _toHsl(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255;
  final g = ((argb >> 8) & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  final l = (mx + mn) / 2;
  final d = mx - mn;
  if (d == 0) return (0, 0, l);
  final s = l > .5 ? d / (2 - mx - mn) : d / (mx + mn);
  double h;
  if (mx == r) {
    h = ((g - b) / d) % 6;
  } else if (mx == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return ((h * 60) % 360, s, l);
}

int _hsl(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  final (r, g, b) = switch ((h ~/ 60) % 6) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int ch(double v) => ((v + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | (ch(r) << 16) | (ch(g) << 8) | ch(b);
}
