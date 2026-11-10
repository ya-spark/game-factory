import 'package:flutter/material.dart';

import 'kit/ds_buttons.dart';
import 'theme/app_theme.dart';

/// Friendly palette shared by the kid-oriented menu screens.
abstract final class KidColors {
  static const skyTop = Color(0xFF7AD7F0);
  static const skyBottom = Color(0xFFFFF1B8);
  static const sun = Color(0xFFFFC93C);
  static const coral = Color(0xFFFF6B6B);
  static const mint = Color(0xFF3DDC97);
  static const grape = Color(0xFF8E6CFF);
  static const ocean = Color(0xFF3FA7FF);
  static const ink = Color(0xFF2D2A4A);

  /// Page colour: the design theme's `bg` when the app has one, else the sky gradient.
  static BoxDecoration backgroundOf(BuildContext context) {
    final t = ThemeTokens.maybeOf(context);
    // A flat gradient, not `color`: list tiles on top paint their ink on the nearest Material,
    // and a coloured DecoratedBox in between would hide it (a debug assertion).
    return t == null
        ? background
        : BoxDecoration(gradient: LinearGradient(colors: [t.bg, t.bg]));
  }

  /// Text colour on the menu screens: the design theme's `text`, else [ink].
  static Color inkOf(BuildContext context) =>
      ThemeTokens.maybeOf(context)?.text ?? ink;

  /// Text and icons on the app bar: the design theme's `text`, else white.
  static Color onBarOf(BuildContext context) =>
      ThemeTokens.maybeOf(context)?.text ?? Colors.white;

  /// Card and tile fill: the design theme's `surface`, else [legacy] (white by default).
  static Color cardOf(BuildContext context, [Color legacy = Colors.white]) =>
      ThemeTokens.maybeOf(context)?.surface ?? legacy;

  /// App bar colour: the design theme's `surface`, else the screen's own [legacy] colour.
  static Color barOf(BuildContext context, Color legacy) =>
      ThemeTokens.maybeOf(context)?.surface ?? legacy;

  static const background = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [skyTop, skyBottom],
    ),
  );
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.color,
  }) : assert(icon != null || leading != null);

  /// Material icon; ignored when [leading] is given.
  final IconData? icon;

  /// A widget in place of the icon, e.g. [CoinIcon].
  final Widget? leading;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.maybeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: t?.surface ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: t == null ? null : Border.all(color: t.border),
        boxShadow: t != null
            ? null
            : const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading ??
              Icon(
                icon,
                size: 22,
                color: color ?? t?.primary ?? KidColors.grape,
              ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KidColors.inkOf(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chunky, rounded, gradient menu button with an emoji/icon. 64px tall for easy tapping.
class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.primary = false,
    this.compact = false,
    this.colors,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool primary;

  /// Half-width variant for the Home Daily reward / Challenges row: fills the width it is given (52 dp tall),
  /// with a smaller icon and label.
  final bool compact;

  /// Gradient colors; defaults to a sunny orange for primary and a blue for the rest.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.maybeOf(context);
    if (t != null) {
      // Design theme: the shared button (token colours, radius, 48 dp minimum, screen-reader label).
      return SizedBox(
        width: compact ? null : 240,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DsButton(
              id: 'menu.$label',
              label: label,
              kind: primary ? DsButtonKind.primary : DsButtonKind.secondary,
              expand: true,
              onPressed: onPressed,
            ),
            if (badge)
              Positioned(
                top: -2,
                right: 6,
                child: IgnorePointer(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: t.alt,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final grad =
        colors ??
        (primary
            ? const [Color(0xFFFFB02E), Color(0xFFFF6B3D)]
            : const [Color(0xFF5AB8FF), Color(0xFF3F7BFF)]);
    final height = primary ? 60.0 : 52.0;
    return SizedBox(
      width: compact ? null : 240,
      height: height,
      child: _BadgeDot(
        show: badge,
        size: 16,
        backgroundColor: KidColors.coral,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: grad,
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: grad.last.withValues(alpha: 0.55),
                blurRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(height / 2),
              onTap: onPressed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: primary ? 30 : (compact ? 22 : 24),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: primary ? 24 : (compact ? 16 : 20),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          shadows: const [
                            Shadow(
                              color: Color(0x55000000),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-shot bouncy "pop in" (code-drawn, finite so pumpAndSettle in tests still returns).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 700) + delay,
    curve: Interval(
      delay.inMilliseconds / (700 + delay.inMilliseconds),
      1,
      curve: Curves.elasticOut,
    ),
    builder: (context, t, child) =>
        Transform.scale(scale: t.clamp(0.0, 1.5), child: child),
    child: child,
  );
}

/// Small notification dot on a button's corner. Unlike [Badge] it never takes part
/// in hit testing, so the button underneath stays tappable.
class _BadgeDot extends StatelessWidget {
  const _BadgeDot({
    required this.show,
    required this.size,
    required this.backgroundColor,
    required this.child,
  });
  final bool show;
  final double size;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(child: child),
      if (show)
        Positioned(
          top: -2,
          right: 6,
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
    ],
  );
}

/// The Home secondary buttons in rows of two, 8 dp apart, as wide as the Play button (240 dp).
/// A lone last button spans the row, so hidden buttons leave no gap.
class HomeGrid extends StatelessWidget {
  const HomeGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          spacing: 8,
          children: [
            for (final c in children.skip(i).take(2)) Expanded(child: c),
          ],
        ),
      );
    }
    return SizedBox(width: 240, child: Column(spacing: 8, children: rows));
  }
}

/// Small round Home icon (Shop, Settings, More games): 44 dp gradient circle with a 2 dp white
/// border and a white 24 dp icon, 48 dp tap target. The key sits on the 48 dp target.
class HomeIconButton extends StatelessWidget {
  const HomeIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.maybeOf(context);
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t?.surface,
                gradient: t != null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                border: Border.all(color: t?.border ?? Colors.white, width: 2),
                boxShadow: t != null
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 4,
                          offset: Offset(0, 3),
                        ),
                      ],
              ),
              child: Icon(icon, color: t?.text ?? Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded card that groups a row on the colorful menu screens.
class KidPanel extends StatelessWidget {
  const KidPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.maybeOf(context);
    final ink = KidColors.inkOf(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: t?.surface ?? const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(t?.cardRadius ?? 22),
        border: t == null ? null : Border.all(color: t.border),
        boxShadow: t != null
            ? null
            : const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(
            listTileTheme: ListTileThemeData(
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
              subtitleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Colorful full-page background with safe-area padding for the menu screens.
class KidPage extends StatelessWidget {
  const KidPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: KidColors.backgroundOf(context),
    child: SizedBox.expand(child: SafeArea(child: child)),
  );
}

/// The game's coin: a gold disc with a darker rim, an inner ring, a soft shine and the letters
/// "MC", drawn in code (no asset files). Games may change the letters in `_CoinPainter`.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'coins',
    excludeSemantics: true,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    ),
  );
}

class _CoinPainter extends CustomPainter {
  static const _rim = Color(0xFFB8860B);
  static const _gold = Color(0xFFFFC72C);
  static const _dark = Color(0xFF8A5A00);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = _rim);
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFE680), _gold],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = _rim,
    );
    // Soft shine, top left.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.8),
      3.4,
      1.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.12
        ..color = const Color(0x99FFFFFF),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'MC',
        style: TextStyle(
          color: _dark,
          fontSize: r * 0.85,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}
