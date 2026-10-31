import 'package:flutter/material.dart';

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
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
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
        Icon(icon, size: 22, color: color ?? KidColors.grape),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: KidColors.ink,
          ),
        ),
      ],
    ),
  );
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
    this.colors,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool primary;

  /// Gradient colors; defaults to a sunny orange for primary and a blue for the rest.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final grad =
        colors ??
        (primary
            ? const [Color(0xFFFFB02E), Color(0xFFFF6B3D)]
            : const [Color(0xFF5AB8FF), Color(0xFF3F7BFF)]);
    final height = primary ? 76.0 : 64.0;
    return SizedBox(
      width: 290,
      height: height,
      child: Badge(
        isLabelVisible: badge,
        smallSize: 16,
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
                  Icon(icon, color: Colors.white, size: primary ? 36 : 30),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: primary ? 28 : 22,
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
