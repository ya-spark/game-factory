import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// What widgets read: colours by the token names, radii, spacing, sizes and motion.
/// Installed on every [ThemeData] built by [buildDesignTheme]; read with [ThemeTokens.of].
@immutable
class ThemeTokens extends ThemeExtension<ThemeTokens> {
  const ThemeTokens({
    required this.mode,
    required this.level,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.alt,
    required this.border,
    required this.success,
    required this.coin,
    required this.onCoin,
    required this.buttonRadius,
    required this.cardRadius,
    required this.spacing,
    required this.sizes,
    required this.minTouch,
    required this.fastMs,
    required this.normalMs,
    required this.slowMs,
    required this.reduceMotion,
    required this.fontFamily,
    required this.variableFont,
    required this.styles,
  });

  final DesignMode mode;
  final InterfaceLevel? level;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color alt;
  final Color border;
  final Color success;
  final Color coin;
  final Color onCoin;
  final double buttonRadius;
  final double cardRadius;
  final Map<String, double> spacing;
  final Map<String, double> sizes;

  /// Minimum touch target: the shared token, or the level's value when larger.
  final double minTouch;
  final int fastMs;
  final int normalMs;
  final int slowMs;
  final bool reduceMotion;
  final String fontFamily;
  final bool variableFont;

  /// Type scale styles by token name (`display`, `title`, `body`, ...), level scale applied.
  final Map<String, TextStyle> styles;

  double sp(String name) => spacing[name] ?? 8;
  double size(String name) => sizes[name] ?? 0;

  /// Transition length for [normal]: capped at the fast duration when reduce motion is on.
  Duration duration({bool slow = false, bool fast = false}) {
    final ms = fast ? fastMs : (slow ? slowMs : normalMs);
    return Duration(
      milliseconds: reduceMotion ? (ms < fastMs ? ms : fastMs) : ms,
    );
  }

  static ThemeTokens of(BuildContext context) {
    final t = Theme.of(context).extension<ThemeTokens>();
    assert(
      t != null,
      'ThemeTokens missing: build the theme with buildDesignTheme',
    );
    return t!;
  }

  /// Null when the app uses the plain (non-design) theme.
  static ThemeTokens? maybeOf(BuildContext context) =>
      Theme.of(context).extension<ThemeTokens>();

  @override
  ThemeTokens copyWith({bool? reduceMotion}) => ThemeTokens(
    mode: mode,
    level: level,
    bg: bg,
    surface: surface,
    surfaceAlt: surfaceAlt,
    text: text,
    textMuted: textMuted,
    primary: primary,
    onPrimary: onPrimary,
    accent: accent,
    onAccent: onAccent,
    alt: alt,
    border: border,
    success: success,
    coin: coin,
    onCoin: onCoin,
    buttonRadius: buttonRadius,
    cardRadius: cardRadius,
    spacing: spacing,
    sizes: sizes,
    minTouch: minTouch,
    fastMs: fastMs,
    normalMs: normalMs,
    slowMs: slowMs,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    fontFamily: fontFamily,
    variableFont: variableFont,
    styles: styles,
  );

  @override
  ThemeTokens lerp(ThemeExtension<ThemeTokens>? other, double t) =>
      t < 0.5 || other is! ThemeTokens ? this : other;
}

/// Text style for a type-scale token. Nunito is one variable file, so the weight is set
/// through `FontVariation('wght', w)` as well as `fontWeight`; Plus Jakarta Sans has one
/// file per weight (400, 700, 800), picked by `fontWeight`.
TextStyle designTextStyle({
  required String family,
  required bool variable,
  required TypeStyleToken token,
  required Color color,
}) => TextStyle(
  fontFamily: family,
  fontSize: token.size,
  fontWeight: FontWeight.values[(token.weight ~/ 100) - 1],
  fontVariations: variable
      ? [FontVariation('wght', token.weight.toDouble())]
      : null,
  color: color,
);

/// One [ThemeData] for [mode] of [app]. [level] (Scout and Ranger only, from the child's year
/// via [InterfaceLevel.forYear]) scales text and raises the minimum touch size.
/// A mode the app lacks falls back to its only mode (Mind apps: `default`).
ThemeData buildDesignTheme({
  required AppTokens app,
  required SharedTokens shared,
  required DesignMode mode,
  InterfaceLevel? level,
  bool reduceMotion = false,
}) {
  final m = app.modes[app.resolveMode(mode)]!;
  final lv = level == null ? null : app.levels[level];
  Color c(String n) => Color(m.color(n));
  final brightness = ThemeData.estimateBrightnessForColor(c('bg'));

  final type = {
    for (final e in shared.type.entries)
      e.key: designTextStyle(
        family: app.fontFamily,
        variable: app.variableFont,
        token: e.value,
        color: c('text'),
      ),
  };
  // Level text scale applies to sizes here, so the phone's own setting still multiplies on top.
  TextStyle ts(String n, {Color? color}) {
    final s = type[n]!;
    return s.copyWith(
      fontSize: s.fontSize! * (lv?.textScale ?? 1.0),
      color: color,
    );
  }

  final minTouch = lv == null
      ? shared.size['min_touch']!
      : (lv.minTouch > shared.size['min_touch']!
            ? lv.minTouch
            : shared.size['min_touch']!);

  final tokens = ThemeTokens(
    mode: app.resolveMode(mode),
    level: level,
    bg: c('bg'),
    surface: c('surface'),
    surfaceAlt: c('surface-alt'),
    text: c('text'),
    textMuted: c('text-muted'),
    primary: c('primary'),
    onPrimary: c('on-primary'),
    accent: c('accent'),
    onAccent: c('on-accent'),
    alt: c('alt'),
    border: c('border'),
    success: c('success'),
    coin: c('coin'),
    onCoin: c('on-coin'),
    buttonRadius: m.buttonRadius,
    cardRadius: m.cardRadius,
    spacing: shared.spacing,
    sizes: shared.size,
    minTouch: minTouch,
    fastMs: shared.fastMs,
    normalMs: shared.normalMs,
    slowMs: shared.slowMs,
    reduceMotion: reduceMotion,
    fontFamily: app.fontFamily,
    variableFont: app.variableFont,
    styles: {for (final k in type.keys) k: ts(k)},
  );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c('primary'),
    onPrimary: c('on-primary'),
    secondary: c('accent'),
    onSecondary: c('on-accent'),
    tertiary: c('alt'),
    error: c('alt'),
    onError: c('bg'),
    surface: c('surface'),
    onSurface: c('text'),
    onSurfaceVariant: c('text-muted'),
    surfaceContainerHighest: c('surface-alt'),
    outline: c('border'),
    outlineVariant: c('border'),
  );

  final noTransition = reduceMotion
      ? const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _InstantTransitions(),
            TargetPlatform.iOS: _InstantTransitions(),
          },
        )
      : null;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c('bg'),
    fontFamily: app.fontFamily,
    pageTransitionsTheme: noTransition,
    textTheme: TextTheme(
      displayLarge: ts('display'),
      headlineMedium: ts('title'),
      titleLarge: ts('title'),
      titleMedium: ts('heading'),
      titleSmall: ts('subheading'),
      bodyLarge: ts('body'),
      bodyMedium: ts('body'),
      bodySmall: ts('caption', color: c('text-muted')),
      labelLarge: ts('label'),
      labelMedium: ts('caption'),
      labelSmall: ts('micro'),
    ),
    cardTheme: CardThemeData(
      color: c('surface'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.cardRadius),
        side: BorderSide(color: c('border')),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c('surface'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.cardRadius),
      ),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [tokens],
  );
}

class _InstantTransitions extends PageTransitionsBuilder {
  const _InstantTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
