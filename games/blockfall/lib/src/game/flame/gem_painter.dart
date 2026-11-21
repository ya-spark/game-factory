import 'dart:math';
import 'dart:ui';

/// Draws the Bomb piece. Only `dart:ui`, so the same code paints the Flame well and the
/// HUD icon. The gem blocks themselves are the **Gems** skin in `themes/block_theme.dart`.
abstract final class GemPainter {
  /// The single-cell Bomb piece: dark glossy sphere, hot ring, fuse spark.
  static void drawBomb(Canvas canvas, Rect cell, double pulse) {
    final s = cell.width;
    final c = cell.center;
    final k = 0.5 + 0.5 * sin(pulse * 2 * pi);
    canvas.drawCircle(
      c,
      s * 0.62,
      Paint()
        ..shader = Gradient.radial(c, s * 0.62, [
          Color.fromARGB((90 + 80 * k).round(), 255, 120, 40),
          const Color(0x00FF7828),
        ]),
    );
    final r = s * 0.36;
    canvas.drawCircle(
      c.translate(0, s * 0.04),
      r,
      Paint()
        ..shader = Gradient.radial(
          c.translate(-r * 0.4, -r * 0.3),
          r * 1.5,
          const [Color(0xFF5B6770), Color(0xFF1B232A), Color(0xFF0A0E12)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      c.translate(0, s * 0.04),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, s * 0.05)
        ..color = const Color(0xFFFF8A3D),
    );
    canvas.drawCircle(
      c.translate(-r * 0.4, -r * 0.35),
      s * 0.06,
      Paint()..color = const Color(0xCCFFFFFF),
    );
    final fuseStart = c.translate(r * 0.55, -r * 0.7);
    final fuseEnd = c.translate(r * 0.95, -r * 1.25);
    canvas.drawLine(
      fuseStart,
      fuseEnd,
      Paint()
        ..color = const Color(0xFFC9A66B)
        ..strokeWidth = max(1.5, s * 0.07)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      fuseEnd,
      s * (0.07 + 0.05 * k),
      Paint()..color = const Color(0xFFFFE066),
    );
  }
}
