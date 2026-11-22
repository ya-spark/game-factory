import 'dart:math';

import 'package:flutter/material.dart';

import '../rules/bridge_rules.dart';

/// Art of Bridge builder, drawn in code (cartoon look, thick dark outline). The toy character is
/// a little wind-up robot: no people, no animals (studio rule, 2026-11-22).
const Color bridgeInk = Color(0xFF2B2A4C);
const Color _wood = Color(0xFFC98B4A);
const Color _woodDark = Color(0xFF8E5A2B);

/// How the robot looks: eyes and mouth.
enum RobotMood { normal, happy, wondering }

/// Fractions of the scene that [BridgeScenePainter] and the widgets laid over it share.
abstract final class BridgeGeometry {
  /// The deck line (top of the planks) as a fraction of the scene height.
  static const double deck = 0.62;

  /// Width of each bank as a fraction of the scene width.
  static const double bank = 0.12;

  static double robotSize(Size s) =>
      min(min(s.width * 0.12, s.height * 0.34), 64);
}

Paint _fill(Color c) => Paint()..color = c;
Paint _line(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _outlined(Canvas c, Path p, Color fill, double w) {
  c.drawPath(p, _fill(fill));
  c.drawPath(p, _line(bridgeInk, w));
}

void _cloud(Canvas c, Offset o, double r, {Color color = Colors.white}) {
  final p = Path()
    ..addOval(Rect.fromCircle(center: o, radius: r))
    ..addOval(
      Rect.fromCircle(center: o + Offset(r * 1.0, r * 0.25), radius: r * 0.8),
    )
    ..addOval(
      Rect.fromCircle(center: o + Offset(-r * 1.0, r * 0.3), radius: r * 0.7),
    )
    ..addRect(
      Rect.fromLTRB(
        o.dx - r * 1.4,
        o.dy + r * 0.3,
        o.dx + r * 1.5,
        o.dy + r * 1.0,
      ),
    );
  c.drawPath(p, _fill(color));
}

Path _star(Offset o, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final pt = o + Offset(cos(a) * rr, sin(a) * rr);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// A star with a thick outline (used at the flag).
void paintBridgeStar(Canvas c, Offset o, double r, {required bool lit}) {
  final p = _star(o, r);
  c.drawPath(p, _fill(lit ? const Color(0xFFFFD43D) : const Color(0x55FFFFFF)));
  c.drawPath(p, _line(bridgeInk, max(2, r * 0.18)));
}

/// The wind-up robot standing with its wheel bottom at [base].
void paintToyRobot(
  Canvas c,
  Offset base,
  double s, {
  RobotMood mood = RobotMood.normal,
  double wheelAngle = 0,
  double tilt = 0,
}) {
  c.save();
  c.translate(base.dx, base.dy);
  c.rotate(tilt);
  final lw = max(2.0, s * 0.055);
  // Wheel.
  final wheel = Offset(0, -s * 0.2);
  c.drawCircle(wheel, s * 0.2, _fill(const Color(0xFF4B4F7A)));
  c.drawCircle(wheel, s * 0.2, _line(bridgeInk, lw));
  c.save();
  c.translate(wheel.dx, wheel.dy);
  c.rotate(wheelAngle);
  for (var i = 0; i < 3; i++) {
    c.drawLine(
      Offset(-s * 0.15, 0),
      Offset(s * 0.15, 0),
      _line(const Color(0xFFB9BDF0), lw * 0.7),
    );
    c.rotate(pi / 3);
  }
  c.restore();
  c.drawCircle(wheel, s * 0.05, _fill(const Color(0xFFFFD43D)));
  // Wind-up key on the back.
  final key = Offset(-s * 0.42, -s * 0.6);
  c.drawLine(Offset(-s * 0.3, -s * 0.6), key, _line(bridgeInk, lw));
  for (final dy in [-s * 0.07, s * 0.07]) {
    final o = key + Offset(-s * 0.06, dy);
    c.drawCircle(o, s * 0.08, _fill(const Color(0xFFFFD43D)));
    c.drawCircle(o, s * 0.08, _line(bridgeInk, lw * 0.8));
  }
  // Body.
  final body = RRect.fromRectAndRadius(
    Rect.fromLTRB(-s * 0.36, -s * 0.88, s * 0.36, -s * 0.36),
    Radius.circular(s * 0.14),
  );
  c.drawRRect(body, _fill(const Color(0xFFFF9F2E)));
  c.drawRRect(body, _line(bridgeInk, lw));
  // Face screen.
  final screen = RRect.fromRectAndRadius(
    Rect.fromLTRB(-s * 0.28, -s * 0.82, s * 0.28, -s * 0.5),
    Radius.circular(s * 0.1),
  );
  c.drawRRect(screen, _fill(const Color(0xFFFFF3D6)));
  c.drawRRect(screen, _line(bridgeInk, lw * 0.7));
  final ey = -s * 0.69;
  for (final dx in [-s * 0.11, s * 0.11]) {
    if (mood == RobotMood.happy) {
      final a = Path()
        ..moveTo(dx - s * 0.06, ey + s * 0.03)
        ..quadraticBezierTo(dx, ey - s * 0.07, dx + s * 0.06, ey + s * 0.03);
      c.drawPath(a, _line(bridgeInk, lw));
    } else {
      c.drawCircle(Offset(dx, ey), s * 0.065, _fill(bridgeInk));
      c.drawCircle(
        Offset(dx + s * 0.02, ey - s * 0.02),
        s * 0.022,
        _fill(Colors.white),
      );
    }
  }
  final my = -s * 0.58;
  if (mood == RobotMood.wondering) {
    c.drawLine(
      Offset(-s * 0.06, my),
      Offset(s * 0.06, my),
      _line(bridgeInk, lw * 0.8),
    );
  } else {
    final m = Path()
      ..moveTo(-s * 0.08, my - s * 0.02)
      ..quadraticBezierTo(0, my + s * 0.07, s * 0.08, my - s * 0.02);
    c.drawPath(m, _line(bridgeInk, lw * 0.8));
  }
  // Antenna.
  c.drawLine(Offset(0, -s * 0.88), Offset(0, -s * 1.02), _line(bridgeInk, lw));
  c.drawCircle(Offset(0, -s * 1.04), s * 0.065, _fill(const Color(0xFFFF4D6D)));
  c.drawCircle(Offset(0, -s * 1.04), s * 0.065, _line(bridgeInk, lw * 0.8));
  // Little arms.
  for (final d in [-1.0, 1.0]) {
    c.drawLine(
      Offset(d * s * 0.36, -s * 0.6),
      Offset(d * s * 0.48, -s * 0.5),
      _line(bridgeInk, lw * 1.4),
    );
  }
  c.restore();
}

/// The scene of one gap: backdrop, the two banks, the bridge ends, the deck laid so far, the
/// robot and (at the end of a stage) the flag and stars.
class BridgeScenePainter extends CustomPainter {
  BridgeScenePainter({
    required this.scenery,
    this.laid = 0,
    this.robotX = 0.06,
    this.mood = RobotMood.normal,
    this.flag = false,
    this.stars = 0,
    this.time = 0,
    this.tilt = 0,
  });

  final Scenery scenery;

  /// 0 to 1: how much of the deck across the gap is laid.
  final double laid;

  /// Robot centre as a fraction of the width.
  final double robotX;
  final RobotMood mood;
  final bool flag;
  final int stars;

  /// Seconds, for the flag and the water.
  final double time;
  final double tilt;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final deckY = h * BridgeGeometry.deck;
    final bank = w * BridgeGeometry.bank;
    switch (scenery) {
      case Scenery.river:
        _river(c, size, deckY, bank);
      case Scenery.canyon:
        _canyon(c, size, deckY, bank);
      case Scenery.sky:
        _sky(c, size, deckY, bank);
    }
    _deck(c, size, deckY, bank);
    if (flag) _flag(c, size, deckY, bank);
    final s = BridgeGeometry.robotSize(size);
    final x = robotX * w;
    paintToyRobot(
      c,
      Offset(x, deckY),
      s,
      mood: mood,
      wheelAngle: x / (s * 0.2),
      tilt: tilt,
    );
  }

  void _bg(Canvas c, Size size, List<Color> colors) {
    final r = Offset.zero & size;
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(r),
    );
  }

  void _bankBlock(
    Canvas c,
    Rect r,
    Color top,
    Color soil, {
    double cap = 0.07,
    double rad = 10,
  }) {
    final p = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          r,
          topLeft: Radius.circular(rad),
          topRight: Radius.circular(rad),
        ),
      );
    c.drawPath(p, _fill(soil));
    final capR = Rect.fromLTWH(r.left, r.top, r.width, r.height * cap + 6);
    c.drawRRect(
      RRect.fromRectAndCorners(
        capR,
        topLeft: Radius.circular(rad),
        topRight: Radius.circular(rad),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      _fill(top),
    );
    c.drawPath(p, _line(bridgeInk, 3));
  }

  void _river(Canvas c, Size size, double deckY, double bank) {
    final w = size.width, h = size.height;
    _bg(c, size, const [Color(0xFF8FD8FF), Color(0xFFDFF6FF)]);
    c.drawCircle(
      Offset(w * 0.78, h * 0.2),
      h * 0.09,
      _fill(const Color(0xFFFFE066)),
    );
    _cloud(c, Offset(w * 0.3, h * 0.2), h * 0.06);
    _cloud(c, Offset(w * 0.6, h * 0.1), h * 0.045);
    final hills = Path()
      ..moveTo(0, deckY)
      ..quadraticBezierTo(w * 0.2, h * 0.28, w * 0.4, deckY)
      ..quadraticBezierTo(w * 0.65, h * 0.3, w, deckY)
      ..close();
    c.drawPath(hills, _fill(const Color(0xFF86D98A)));
    final water = Rect.fromLTRB(0, deckY + h * 0.1, w, h);
    c.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF47B4F7), Color(0xFF1C7CCF)],
        ).createShader(water),
    );
    for (var i = 0; i < 4; i++) {
      final y = deckY + h * (0.18 + i * 0.05);
      final p = Path()..moveTo(bank + 6, y);
      for (var x = bank + 6; x < w - bank - 28; x += 28) {
        final ph = sin(time * 2 + i + x / 30) * 2;
        p.quadraticBezierTo(x + 7, y - 5 + ph, x + 14, y);
        p.quadraticBezierTo(x + 21, y + 5 - ph, x + 28, y);
      }
      c.drawPath(p, _line(const Color(0x99FFFFFF), 2));
    }
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, deckY + h * 0.31),
        width: w * 0.07,
        height: h * 0.05,
      ),
      _fill(const Color(0xFF5CC85F)),
    );
    _bankBlock(
      c,
      Rect.fromLTRB(-6, deckY - 2, bank, h + 4),
      const Color(0xFF5CC85F),
      const Color(0xFF9A6A3A),
    );
    _bankBlock(
      c,
      Rect.fromLTRB(w - bank, deckY - 2, w + 6, h + 4),
      const Color(0xFF5CC85F),
      const Color(0xFF9A6A3A),
    );
  }

  void _canyon(Canvas c, Size size, double deckY, double bank) {
    final w = size.width, h = size.height;
    _bg(c, size, const [Color(0xFFFFC86B), Color(0xFFFFEBC2)]);
    c.drawCircle(
      Offset(w * 0.5, h * 0.22),
      h * 0.11,
      _fill(const Color(0xFFFF8A3D)),
    );
    for (final (x, mw, mh, col) in [
      (0.18, 0.2, 0.3, const Color(0xFFE29A6B)),
      (0.5, 0.26, 0.22, const Color(0xFFD98B5F)),
      (0.82, 0.2, 0.34, const Color(0xFFE29A6B)),
    ]) {
      final r = Rect.fromLTWH(
        w * (x - mw / 2),
        deckY - h * mh,
        w * mw,
        h * mh + h,
      );
      c.drawRRect(
        RRect.fromRectAndCorners(
          r,
          topLeft: Radius.circular(h * 0.04),
          topRight: Radius.circular(h * 0.04),
        ),
        _fill(col),
      );
    }
    final depth = Rect.fromLTRB(0, deckY + h * 0.05, w, h);
    c.drawRect(
      depth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9A4A28), Color(0xFF3E1A14)],
        ).createShader(depth),
    );
    for (var i = 0; i < 3; i++) {
      final y = deckY + h * (0.16 + i * 0.1);
      c.drawLine(
        Offset(bank, y),
        Offset(w - bank, y),
        _line(const Color(0x33FFFFFF), 2),
      );
    }
    for (final left in [true, false]) {
      final r = left
          ? Rect.fromLTRB(-6, deckY - 2, bank, h + 4)
          : Rect.fromLTRB(w - bank, deckY - 2, w + 6, h + 4);
      _bankBlock(
        c,
        r,
        const Color(0xFFE08A52),
        const Color(0xFFC4673A),
        cap: 0.05,
        rad: 6,
      );
      for (var i = 1; i < 4; i++) {
        final y = deckY + h * 0.1 * i;
        c.drawLine(
          Offset(r.left, y),
          Offset(r.right, y),
          _line(const Color(0xFFB3552C), 3),
        );
      }
    }
  }

  void _sky(Canvas c, Size size, double deckY, double bank) {
    final w = size.width, h = size.height;
    _bg(c, size, const [
      Color(0xFF3B4BA8),
      Color(0xFF8A6FD1),
      Color(0xFFFFB3C7),
    ]);
    final rnd = Random(7);
    for (var i = 0; i < 18; i++) {
      c.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.5),
        1.2 + rnd.nextDouble() * 1.6,
        _fill(
          Colors.white.withValues(alpha: 0.5 + 0.5 * sin(time * 3 + i).abs()),
        ),
      );
    }
    const cols = [
      Color(0xFFFF6B6B),
      Color(0xFFFFB02E),
      Color(0xFFFFE066),
      Color(0xFF5CC85F),
      Color(0xFF47B4F7),
    ];
    for (var i = 0; i < cols.length; i++) {
      final r = w * 0.32 - i * w * 0.018;
      c.drawArc(
        Rect.fromCircle(center: Offset(w / 2, deckY + h * 0.2), radius: r),
        pi,
        pi,
        false,
        _line(cols[i].withValues(alpha: 0.85), w * 0.018),
      );
    }
    _cloud(
      c,
      Offset(w * 0.3, deckY + h * 0.24),
      h * 0.06,
      color: const Color(0xFFEFF1FF),
    );
    _cloud(
      c,
      Offset(w * 0.68, deckY + h * 0.3),
      h * 0.05,
      color: const Color(0xFFEFF1FF),
    );
    for (final left in [true, false]) {
      final cx = left ? bank * 0.4 : w - bank * 0.4;
      final r = h * 0.1;
      final p = Path()
        ..addOval(
          Rect.fromCircle(center: Offset(cx, deckY + r * 0.9), radius: r),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(cx + (left ? 1 : -1) * r * 0.9, deckY + r * 1.3),
            radius: r * 0.8,
          ),
        )
        ..addRect(
          Rect.fromLTRB(
            left ? -6 : w - bank - 2,
            deckY,
            left ? bank + 2 : w + 6,
            h + 4,
          ),
        );
      _outlined(c, p, Colors.white, 3);
    }
  }

  void _deck(Canvas c, Size size, double deckY, double bank) {
    final w = size.width, h = size.height;
    final th = h * 0.05;
    void planks(double x0, double x1) {
      if (x1 <= x0) return;
      final r = Rect.fromLTRB(x0, deckY - th * 0.2, x1, deckY + th * 0.8);
      c.drawRect(r, _fill(_wood));
      c.save();
      c.clipRect(r);
      for (var x = x0; x < x1; x += th * 1.6) {
        c.drawLine(Offset(x, r.top), Offset(x, r.bottom), _line(_woodDark, 2));
      }
      c.restore();
      c.drawRect(r, _line(bridgeInk, 2.5));
    }

    planks(0, bank);
    planks(w - bank, w);
    final gapL = bank, gapR = w - bank;
    planks(gapL, gapL + (gapR - gapL) * laid.clamp(0, 1));
    for (final x in [gapL - 2, gapR + 2]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 4, deckY - h * 0.1, x + 4, deckY + th * 0.8),
        const Radius.circular(3),
      );
      c.drawRRect(r, _fill(_woodDark));
      c.drawRRect(r, _line(bridgeInk, 2));
    }
  }

  void _flag(Canvas c, Size size, double deckY, double bank) {
    final w = size.width, h = size.height;
    final x = w - bank * 0.45;
    final top = deckY - h * 0.5;
    c.drawLine(Offset(x, deckY), Offset(x, top), _line(bridgeInk, 4));
    c.drawCircle(Offset(x, top), 5, _fill(const Color(0xFFFFD43D)));
    c.drawCircle(Offset(x, top), 5, _line(bridgeInk, 2));
    final wave = sin(time * 4) * 3;
    final f = Path()
      ..moveTo(x, top + 6)
      ..quadraticBezierTo(x - w * 0.04, top + 10 + wave, x - w * 0.08, top + 8)
      ..lineTo(x - w * 0.07, top + 22)
      ..quadraticBezierTo(x - w * 0.04, top + 26 - wave, x, top + 24)
      ..close();
    _outlined(c, f, const Color(0xFFFF4D6D), 2.5);
    for (var i = 0; i < 3; i++) {
      paintBridgeStar(
        c,
        Offset(
          x - w * 0.2 + i * w * 0.07,
          top - h * 0.02 - (i == 1 ? h * 0.05 : 0),
        ),
        h * 0.055,
        lit: i < stars,
      );
    }
  }

  @override
  bool shouldRepaint(BridgeScenePainter o) =>
      o.scenery != scenery ||
      o.laid != laid ||
      o.robotX != robotX ||
      o.mood != mood ||
      o.flag != flag ||
      o.stars != stars ||
      o.time != time ||
      o.tilt != tilt;
}
