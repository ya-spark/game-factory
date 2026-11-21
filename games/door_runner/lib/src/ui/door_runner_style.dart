import 'package:flutter/material.dart';

/// The look of Door runner: a glowing scene like Wingy (gradient sky, stars, glow on every
/// control), with chunky gradient buttons like Block Puzzle. Colours are fixed for the game
/// scene (as in Wingy), not taken from the app theme.
abstract final class DrColors {
  static const lilac = Color(0xFFB896FF);
  static const cyan = Color(0xFF7CF5FF);
  static const gold = Color(0xFFFFE066);
  static const pink = Color(0xFFFF6B8A);
  static const ink = Color(0xFF1B1446);
  static const mint = Color(0xFF3DDC97);

  /// Sky gradients (top, middle, bottom) per world: dusk, aurora, ember (Wingy's palettes).
  static const worlds = <List<Color>>[
    [Color(0xFF1B1446), Color(0xFF2B4FB0), Color(0xFF2FA8C9)],
    [Color(0xFF0B2B3B), Color(0xFF1C6A6E), Color(0xFF3FBF9A)],
    [Color(0xFF2A0E12), Color(0xFF8A2B26), Color(0xFFF08A3C)],
  ];
  static List<Color> world(int i) => worlds[i % worlds.length];
}

List<BoxShadow> drGlow(Color c, {double alpha = 0.45, double blur = 20}) => [
  BoxShadow(
    color: c.withValues(alpha: alpha),
    blurRadius: blur,
  ),
];

const drTextShadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];

/// A round glowing icon button (exit, pause).
class DrRoundButton extends StatelessWidget {
  const DrRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x29FFFFFF),
              border: Border.all(
                color: DrColors.lilac.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: drGlow(DrColors.lilac, alpha: 0.35, blur: 12),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

/// A chunky gradient button (Block Puzzle style).
class DrButton extends StatelessWidget {
  const DrButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.colors = const [Color(0xFF5AB8FF), Color(0xFF3F7BFF)],
    this.height = 56,
  });
  final VoidCallback onPressed;
  final Widget child;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}
