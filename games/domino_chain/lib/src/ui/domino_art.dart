import 'dart:math';

import 'package:flutter/material.dart';

import '../rules/domino_chain_rules.dart';

/// Art of Domino chain, drawn in code (cartoon look, thick dark outline). Toys only: dominoes, a
/// flag, a lever. No people, no animals (studio rule, 2026-11-22). The ink colour is the same value
/// as Bridge builder's `bridgeInk`; a game never imports another game, so it is repeated here.
const Color dominoInk = Color(0xFF2B2A4C);

/// Cream face of a domino (dark ink on it has a contrast of more than 7:1).
const Color dominoCream = Color(0xFFFFF3D6);
const Color dominoGreen = Color(0xFF2E9E5B);
const Color dominoRed = Color(0xFFD64545);

/// The coloured top bands cycle through these.
const List<Color> dominoBands = [
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFF14B8A6),
  Color(0xFF8B5CF6),
];

Color dominoBand(int i) => dominoBands[i % dominoBands.length];

/// How a domino looks: standing, tipped (right), or the broken one (red).
enum DominoLook { rest, tipped, broken }

Paint _fill(Color c) => Paint()..color = c;
Paint _line(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Paints one domino into [r]: drop shadow, cream face with a thick outline, a coloured top band
/// and pips (decoration only).
void paintDomino(
  Canvas c,
  Rect r, {
  required Color band,
  DominoLook look = DominoLook.rest,
  bool shadow = true,
  double outline = 3,
}) {
  final rr = RRect.fromRectAndRadius(
    r,
    Radius.circular(min(r.width, r.height) * 0.16),
  );
  if (shadow) {
    c.drawRRect(
      rr.shift(const Offset(0, 4)),
      _fill(dominoInk.withValues(alpha: 0.35)),
    );
  }
  final face = switch (look) {
    DominoLook.rest => dominoCream,
    DominoLook.tipped => const Color(0xFFD9F5E3),
    DominoLook.broken => const Color(0xFFFFE0E0),
  };
  c.drawRRect(rr, _fill(face));
  // top band
  final bandH = r.height * 0.2;
  c.save();
  c.clipRRect(rr);
  c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, bandH), _fill(band));
  c.restore();
  // pips in the band (decoration)
  final pip = _fill(Colors.white.withValues(alpha: 0.9));
  final pr = max(1.6, bandH * 0.18);
  for (var i = 0; i < 3; i++) {
    c.drawCircle(
      Offset(r.left + r.width * (0.3 + 0.2 * i), r.top + bandH / 2),
      pr,
      pip,
    );
  }
  c.drawLine(
    Offset(r.left, r.top + bandH),
    Offset(r.right, r.top + bandH),
    _line(dominoInk, outline * 0.6),
  );
  c.drawRRect(
    rr,
    _line(switch (look) {
      DominoLook.broken => dominoRed,
      DominoLook.tipped => dominoGreen,
      DominoLook.rest => dominoInk,
    }, look == DominoLook.broken ? outline * 1.5 : outline),
  );
}

/// A domino face: the painter, with the label on top by the caller.
class DominoFacePainter extends CustomPainter {
  const DominoFacePainter({
    required this.band,
    this.look = DominoLook.rest,
    this.shadow = true,
  });
  final Color band;
  final DominoLook look;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    paintDomino(
      canvas,
      Rect.fromLTWH(2, 1, size.width - 4, size.height - 6),
      band: band,
      look: look,
      shadow: shadow,
    );
  }

  @override
  bool shouldRepaint(DominoFacePainter o) =>
      o.band != band || o.look != look || o.shadow != shadow;
}

/// The backdrop of a stage: playroom floor, toy shelf, window sill.
class DominoBackdropPainter extends CustomPainter {
  const DominoBackdropPainter(this.backdrop);
  final DominoBackdrop backdrop;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    switch (backdrop) {
      case DominoBackdrop.floor:
        canvas.drawRect(Offset.zero & size, _fill(const Color(0xFFBFE3F5)));
        // rug-coloured floor with plank lines
        final floorTop = h * 0.3;
        canvas.drawRect(
          Rect.fromLTRB(0, floorTop, w, h),
          _fill(const Color(0xFFE9B97A)),
        );
        final plank = _line(const Color(0xFFC48F4F), 2);
        for (var y = floorTop + 22; y < h; y += 26) {
          canvas.drawLine(Offset(0, y), Offset(w, y), plank);
        }
        canvas.drawLine(
          Offset(0, floorTop),
          Offset(w, floorTop),
          _line(dominoInk, 3),
        );
      case DominoBackdrop.shelf:
        canvas.drawRect(Offset.zero & size, _fill(const Color(0xFFFFE6C7)));
        final dot = _fill(const Color(0xFFFFD1A0));
        for (var y = 10.0; y < h; y += 24) {
          for (var x = (y ~/ 24).isEven ? 8.0 : 20.0; x < w; x += 24) {
            canvas.drawCircle(Offset(x, y), 2.5, dot);
          }
        }
        final top = h * 0.34;
        canvas.drawRect(
          Rect.fromLTRB(0, top, w, h),
          _fill(const Color(0xFFD99A57)),
        );
        canvas.drawRect(
          Rect.fromLTRB(0, top, w, top + 8),
          _fill(const Color(0xFFB87B3E)),
        );
        canvas.drawLine(Offset(0, top), Offset(w, top), _line(dominoInk, 3));
      case DominoBackdrop.sill:
        canvas.drawRect(Offset.zero & size, _fill(const Color(0xFF8ED3FF)));
        _cloud(canvas, Offset(w * 0.22, h * 0.14), min(w, h) * 0.06);
        _cloud(canvas, Offset(w * 0.7, h * 0.1), min(w, h) * 0.05);
        // window frame cross
        final frame = _line(Colors.white, 6);
        canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * 0.36), frame);
        final top = h * 0.36;
        canvas.drawRect(
          Rect.fromLTRB(0, top, w, h),
          _fill(const Color(0xFFF2EEE6)),
        );
        canvas.drawLine(Offset(0, top), Offset(w, top), _line(dominoInk, 3));
    }
  }

  void _cloud(Canvas c, Offset o, double r) {
    final p = Path()
      ..addOval(Rect.fromCircle(center: o, radius: r))
      ..addOval(
        Rect.fromCircle(center: o + Offset(r, r * 0.25), radius: r * 0.8),
      )
      ..addOval(
        Rect.fromCircle(center: o + Offset(-r, r * 0.3), radius: r * 0.7),
      );
    c.drawPath(p, _fill(Colors.white));
  }

  @override
  bool shouldRepaint(DominoBackdropPainter o) => o.backdrop != backdrop;
}

/// The toy flag: a striped pennant on a pole. [pop] from 0 to 1 scales it up from the base.
class ToyFlagPainter extends CustomPainter {
  const ToyFlagPainter({this.pop = 1});
  final double pop;

  @override
  void paint(Canvas canvas, Size size) {
    if (pop <= 0) return;
    canvas.save();
    canvas.translate(size.width * 0.3, size.height);
    canvas.scale(Curves.easeOutBack.transform(pop.clamp(0.0, 1.0)));
    canvas.translate(-size.width * 0.3, -size.height);
    final pole = size.width * 0.3;
    final top = size.height * 0.04;
    canvas.drawLine(
      Offset(pole, size.height),
      Offset(pole, top),
      _line(dominoInk, 3.5),
    );
    final f = Rect.fromLTWH(pole, top, size.width * 0.66, size.height * 0.46);
    final path = Path()
      ..moveTo(f.left, f.top)
      ..lineTo(f.right, f.top + f.height * 0.5)
      ..lineTo(f.left, f.bottom)
      ..close();
    canvas.drawPath(path, _fill(const Color(0xFFF59E0B)));
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(f.left, f.top + f.height * 0.33, f.width, f.height * 0.17),
      _fill(const Color(0xFFFFF3D6)),
    );
    canvas.restore();
    canvas.drawPath(path, _line(dominoInk, 3));
    canvas.drawCircle(Offset(pole, top), 4, _fill(dominoInk));
    canvas.restore();
  }

  @override
  bool shouldRepaint(ToyFlagPainter o) => o.pop != pop;
}

/// A spark burst at the break: [t] from 0 to 1.
class SparkPainter extends CustomPainter {
  const SparkPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2;
    final p = _line(const Color(0xFFFFC21A).withValues(alpha: 1 - t), 3);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final from = c + Offset(cos(a), sin(a)) * (r * (0.3 + 0.4 * t));
      final to = c + Offset(cos(a), sin(a)) * (r * (0.55 + 0.45 * t));
      canvas.drawLine(from, to, p);
    }
  }

  @override
  bool shouldRepaint(SparkPainter o) => o.t != t;
}

/// A dust puff along the floor at the break: [t] from 0 to 1.
class DustPainter extends CustomPainter {
  const DustPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final paint = _fill(
      const Color(0xFFFFFFFF).withValues(alpha: 0.8 * (1 - t)),
    );
    final base = Offset(size.width / 2, size.height * 0.9);
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(
        base +
            Offset(i * size.width * 0.22 * (0.5 + t), -t * size.height * 0.25),
        size.width * (0.08 + 0.1 * t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DustPainter o) => o.t != t;
}

/// The toy lever on the Go button: a green knob on a stick in a slot.
class GoLeverPainter extends CustomPainter {
  const GoLeverPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final slot = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.72, w * 0.8, h * 0.18),
      Radius.circular(h * 0.09),
    );
    canvas.drawRRect(slot, _fill(color.withValues(alpha: 0.35)));
    canvas.drawLine(
      Offset(w * 0.5, h * 0.8),
      Offset(w * 0.72, h * 0.28),
      _line(color, 3.5),
    );
    canvas.drawCircle(Offset(w * 0.72, h * 0.24), h * 0.17, _fill(color));
  }

  @override
  bool shouldRepaint(GoLeverPainter o) => o.color != color;
}

/// A row of dominoes with a flag, for the start and results screens. [fallen] dominoes lie tipped.
class DominoRowPainter extends CustomPainter {
  const DominoRowPainter({
    required this.backdrop,
    this.count = 5,
    this.fallen = 0,
    this.flag = false,
  });
  final DominoBackdrop backdrop;
  final int count;
  final int fallen;
  final bool flag;

  @override
  void paint(Canvas canvas, Size size) {
    DominoBackdropPainter(backdrop).paint(canvas, size);
    final w = size.width, h = size.height;
    final dh = h * 0.42;
    final dw = dh * 0.62;
    final gap = (w * 0.68 - dw * count) / max(1, count - 1);
    final base = h * 0.82;
    final x0 = w * 0.08;
    for (var i = 0; i < count; i++) {
      final left = x0 + i * (dw + gap);
      canvas.save();
      if (i < fallen) {
        canvas.translate(left + dw / 2, base);
        canvas.transform(
          (Matrix4.identity()
                ..setEntry(0, 1, -0.55)
                ..setEntry(1, 1, 0.62))
              .storage,
        );
        canvas.translate(-(left + dw / 2), -base);
      }
      paintDomino(
        canvas,
        Rect.fromLTWH(left, base - dh, dw, dh),
        band: dominoBand(i),
        look: i < fallen ? DominoLook.tipped : DominoLook.rest,
        outline: 2.5,
      );
      canvas.restore();
    }
    if (flag) {
      canvas.save();
      canvas.translate(w * 0.84, h * 0.12);
      const ToyFlagPainter().paint(canvas, Size(w * 0.14, h * 0.7));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DominoRowPainter o) =>
      o.backdrop != backdrop ||
      o.count != count ||
      o.fallen != fallen ||
      o.flag != flag;
}
