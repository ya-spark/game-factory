import 'package:flutter/material.dart';

import 'home_hero.dart';

/// Bright, kid-friendly palette used by the home and challenge screens.
abstract final class KidColors {
  static const skyTop = Color(0xFF7DD3FC);
  static const skyBottom = Color(0xFFFDE68A);
  static const sun = Color(0xFFFFB703);
  static const coral = Color(0xFFFF6B6B);
  static const grape = Color(0xFF8B5CF6);
  static const mint = Color(0xFF22C55E);
  static const ocean = Color(0xFF3B82F6);
  static const ink = Color(0xFF1E3A5F);
}

/// Full-screen sky gradient background.
class KidBackground extends StatelessWidget {
  const KidBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KidColors.skyTop, KidColors.skyBottom],
      ),
    ),
    child: child,
  );
}

/// Gently bobbing widget (code-drawn animation, no assets).
class Bobbing extends StatefulWidget {
  const Bobbing({super.key, required this.child, this.amplitude = 8});
  final Widget child;
  final double amplitude;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    builder: (context, child) => Transform.translate(
      offset: Offset(
        0,
        (Curves.easeInOut.transform(_c.value) - 0.5) * 2 * widget.amplitude,
      ),
      child: child,
    ),
    child: widget.child,
  );
}

/// The coin: gold disc, darker rim, inner ring, soft shine and "MC" in dark gold.
/// Drawn in code (no assets).
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'coins',
    child: ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CoinPainter(),
          child: Center(
            child: Text(
              'MC',
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8A5A00),
                height: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFC98A00));
    canvas.drawCircle(c, r * 0.9, Paint()..color = const Color(0xFFFFC933));
    canvas.drawCircle(
      c,
      r * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..color = const Color(0xFFE0A100),
    );
    // Soft shine, upper left.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.38, -r * 0.45),
        width: r * 0.6,
        height: r * 0.3,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.color,
  }) : assert(icon != null || leading != null);
  final IconData? icon;

  /// Used instead of [icon] when set (for example a [CoinIcon]).
  final Widget? leading;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color ?? KidColors.ocean, width: 3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading ?? Icon(icon, size: 24, color: color ?? KidColors.ocean),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: KidColors.ink,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Big, chunky, rounded gradient button with an icon and a press animation.
class MenuButton extends StatefulWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.primary = false,
    this.compact = false,
    this.color,
    this.emoji,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool primary;

  /// Half-width variant for the Home Daily reward / Challenges row: fills the width it is given (52 dp tall),
  /// with a smaller icon and label.
  final bool compact;
  final Color? color;
  final String? emoji;

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final base =
        widget.color ?? (widget.primary ? KidColors.mint : KidColors.ocean);
    final dark = HSLColor.fromColor(base).withLightness(0.32).toColor();
    final height = widget.primary ? 60.0 : 52.0;
    final button = AnimatedScale(
      scale: _down ? 0.95 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HSLColor.fromColor(base).withLightness(0.62).toColor(),
                base,
              ],
            ),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: dark, offset: const Offset(0, 5)),
              const BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 9),
                blurRadius: 8,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.compact) const SizedBox(width: 6),
                  if (widget.emoji != null)
                    Text(
                      widget.emoji!,
                      style: TextStyle(
                        fontSize: widget.primary
                            ? 30
                            : (widget.compact ? 20 : 24),
                      ),
                    )
                  else
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: widget.primary ? 30 : (widget.compact ? 22 : 24),
                    ),
                  SizedBox(width: widget.compact ? 6 : 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.primary
                              ? 24
                              : (widget.compact ? 15 : 20),
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Colors.black38, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.compact) const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: widget.compact ? null : 240,
      height: height,
      child: _BadgeDot(
        show: widget.badge,
        size: 16,
        backgroundColor: KidColors.coral,
        child: SizedBox.expand(child: button),
      ),
    );
  }
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

/// Home column height without the hero band and without the gaps: title (~58), stat chips (48),
/// 8 dp spacer, Play (60) and the Daily reward / Challenges row (52).
const double _homeFixedHeight = 58 + 48 + 8 + 60 + 52;

/// Height of the Remove Ads pill (`RemoveAdsPill`).
const double _removeAdsHeight = 40;

/// Hero band height and spacing between Home groups for [available] dp of height: 160 and 10 when
/// there is room, else spacing 8 and the hero shrinks down to 96.
(double, double) homeLayout(double available) {
  if (available >= _homeFixedHeight + 5 * 10 + HomeHero.maxHeight) {
    return (HomeHero.maxHeight, 10);
  }
  final hero = (available - _homeFixedHeight - 5 * 8).clamp(
    HomeHero.minHeight,
    HomeHero.maxHeight,
  );
  return (hero, 8);
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
    return SizedBox(width: 272, child: Column(spacing: 8, children: rows));
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
  Widget build(BuildContext context) => Semantics(
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    ),
  );
}

/// White rounded card that groups a row on the colorful menu screens.
class KidPanel extends StatelessWidget {
  const KidPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xF2FFFFFF),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
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
          listTileTheme: const ListTileThemeData(
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: KidColors.ink,
            ),
            subtitleTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: KidColors.ink,
            ),
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// Colorful full-page background with safe-area padding for the menu screens.
class KidPage extends StatelessWidget {
  const KidPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => KidBackground(
    child: SizedBox.expand(child: SafeArea(child: child)),
  );
}

/// "Remove ads" offer: a small pill that opens the shop. Shown on Home and on the game over
/// screen until the player owns Remove Ads.
class RemoveAdsPill extends StatelessWidget {
  const RemoveAdsPill({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Remove ads',
    child: Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: const SizedBox(
          height: _removeAdsHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 20, color: KidColors.coral),
                SizedBox(width: 8),
                Text(
                  'Remove ads',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: KidColors.ink,
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
