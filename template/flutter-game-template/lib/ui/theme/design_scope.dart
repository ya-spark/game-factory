import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_loader.dart';
import 'design_tokens.dart';

/// The two accessibility options a player can switch on (Settings, 2B wires the storage).
@immutable
class DesignPrefs {
  const DesignPrefs({this.largeText = false, this.reduceMotion = false});

  /// Large-text option: multiplies the phone's own text size by [largeTextFactor].
  final bool largeText;

  /// No shaking, no flashing, transitions at most the token's fast duration, no parallax.
  final bool reduceMotion;

  static const largeTextFactor = 1.3;

  DesignPrefs copyWith({bool? largeText, bool? reduceMotion}) => DesignPrefs(
    largeText: largeText ?? this.largeText,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

/// Applies the design theme for [mode] (and [level] for Scout and Ranger) and the text
/// options to [child]. Text always follows the phone's size setting; the large-text option
/// multiplies it.
class DesignScope extends StatelessWidget {
  const DesignScope({
    super.key,
    required this.design,
    required this.mode,
    this.level,
    this.prefs = const DesignPrefs(),
    this.colorOverrides,
    required this.child,
  });
  final DesignBundle design;
  final DesignMode mode;
  final InterfaceLevel? level;
  final DesignPrefs prefs;

  /// The equipped shop colour theme's palette, or null for the app's own colours.
  final Map<String, int>? colorOverrides;
  final Widget child;

  /// The design files of the enclosing [DesignScope], or null when the app has the plain look.
  static DesignBundle? bundleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BundleScope>()?.design;

  @override
  Widget build(BuildContext context) {
    final theme = buildDesignTheme(
      app: design.app,
      shared: design.shared,
      mode: mode,
      level: level,
      colorOverrides: colorOverrides,
      reduceMotion:
          prefs.reduceMotion || MediaQuery.disableAnimationsOf(context),
    );
    final mq = MediaQuery.of(context);
    final scaler = prefs.largeText
        ? _Multiplied(mq.textScaler, DesignPrefs.largeTextFactor)
        : mq.textScaler;
    return _BundleScope(
      design: design,
      child: Theme(
        data: theme,
        child: MediaQuery(
          data: mq.copyWith(textScaler: scaler),
          child: child,
        ),
      ),
    );
  }
}

/// The phone's [TextScaler] times a factor.
class _Multiplied extends TextScaler {
  const _Multiplied(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => base.scale(1.0) * factor;

  @override
  bool operator ==(Object other) =>
      other is _Multiplied && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

class _BundleScope extends InheritedWidget {
  const _BundleScope({required this.design, required super.child});
  final DesignBundle design;

  @override
  bool updateShouldNotify(_BundleScope old) => design != old.design;
}
