import 'dart:math';
import 'dart:ui';

import '../rules/well.dart';

/// Draws the symbol of a Boom block or golden block on top of a theme skin (same look in
/// every theme). Prism cells keep their own glow (`drawPrismGlow`).
void drawSpecialOverlay(Canvas canvas, CellKind kind, Rect rect) {
  switch (kind) {
    case CellKind.normal:
    case CellKind.prism:
      return;
    case CellKind.boom:
      _boom(canvas, rect);
    case CellKind.gold:
      _gold(canvas, rect);
  }
}

Path starPath(Offset c, double outer, double inner, int points) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = -pi / 2 + i * pi / points;
    final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

void _boom(Canvas canvas, Rect rect) {
  final c = rect.center;
  final burst = starPath(c, rect.width * 0.4, rect.width * 0.22, 8);
  canvas.drawPath(burst, Paint()..color = const Color(0xFFFFD23F));
  canvas.drawPath(
    burst,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.05
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE8590C),
  );
  canvas.drawCircle(
    c,
    rect.width * 0.11,
    Paint()..color = const Color(0xFFFF8A3D),
  );
}

void _gold(Canvas canvas, Rect rect) {
  final rr = RRect.fromRectAndRadius(
    rect.deflate(rect.width * 0.06),
    Radius.circular(rect.width * 0.2),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [Color(0xCCFFE680), Color(0xCCFFB300), Color(0xCCFFE680)],
        const [0, 0.55, 1],
      ),
  );
  final star = starPath(rect.center, rect.width * 0.3, rect.width * 0.13, 5);
  canvas.drawPath(star, Paint()..color = const Color(0xFFFFF8D6));
  canvas.drawPath(
    star,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.04
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFB87900),
  );
}

/// A short cartoon star burst at [center], [t] runs 0 (start) to 1 (gone). No flashing:
/// it only grows and fades.
void drawBlast(Canvas canvas, Offset center, double cell, double t) {
  final alpha = (1 - t).clamp(0.0, 1.0);
  final burst = starPath(
    center,
    cell * (0.35 + 0.45 * t),
    cell * (0.18 + 0.2 * t),
    8,
  );
  canvas.drawPath(
    burst,
    Paint()..color = Color.fromRGBO(255, 210, 63, 0.85 * alpha),
  );
  canvas.drawPath(
    burst,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.05
      ..color = Color.fromRGBO(232, 89, 12, alpha),
  );
}
