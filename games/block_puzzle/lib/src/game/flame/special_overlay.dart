import 'dart:math';
import 'dart:ui';

import '../rules/piece.dart';

/// Draws the special-cell symbol on top of a theme skin. Same look in every theme:
/// gem = bright faceted gem, boom = friendly star-burst, gold = gold sheen with a star.
void drawSpecialOverlay(Canvas canvas, CellKind kind, Rect rect) {
  switch (kind) {
    case CellKind.normal:
      return;
    case CellKind.gem:
      _gem(canvas, rect);
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

void _gem(Canvas canvas, Rect rect) {
  final c = rect.center;
  final w = rect.width * 0.34, h = rect.height * 0.34;
  final top = Offset(c.dx, c.dy - h);
  final left = Offset(c.dx - w, c.dy - h * 0.25);
  final right = Offset(c.dx + w, c.dy - h * 0.25);
  final bottom = Offset(c.dx, c.dy + h);
  final body = Path()
    ..moveTo(top.dx, top.dy)
    ..lineTo(right.dx, right.dy)
    ..lineTo(bottom.dx, bottom.dy)
    ..lineTo(left.dx, left.dy)
    ..close();
  canvas.drawPath(body, Paint()..color = const Color(0xFFBFF4FF));
  canvas.drawPath(
    Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(c.dx - w * 0.35, c.dy - h * 0.25)
      ..lineTo(c.dx + w * 0.35, c.dy - h * 0.25)
      ..close(),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.drawPath(
    Path()
      ..moveTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(c.dx, c.dy - h * 0.25)
      ..close(),
    Paint()..color = const Color(0xFF55B8E6),
  );
  canvas.drawPath(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.045
      ..color = const Color(0xFF1B6C8F),
  );
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
