import 'dart:math';

import 'package:flutter/material.dart';

import '../rules/dash_rules.dart';

/// Wind-up dash art, drawn in code (toys only, no living beings): thick dark outline, flat bright colours.
/// Spec: `docs/SPEC.md` section "Art".
const Color dashInk = Color(0xFF2B2A4C);
const Color dashGold = Color(0xFFFFC83D);
const Color dashRed = Color(0xFFE5484D);
const Color dashGreen = Color(0xFF1E7A48);
const List<Color> dashBrickColors = [
  Color(0xFFE5484D),
  Color(0xFF3B82F6),
  Color(0xFF2FB36B),
  Color(0xFF8B5CF6),
];

/// The five backdrops, one per course. Free run and the menu use the first.
class DashBackdrop {
  const DashBackdrop({
    required this.skyTop,
    required this.skyBottom,
    required this.wall,
    required this.far,
    required this.mid,
    required this.floorTop,
    required this.floorSeam,
    required this.floorUnder,
    required this.kind,
    required this.label,
  });

  final Color skyTop, skyBottom, wall, far, mid;
  final Color floorTop, floorSeam, floorUnder;
  final int kind;
  final String label;

  static const List<DashBackdrop> all = [
    DashBackdrop(
      skyTop: Color(0xFFFFF1B8),
      skyBottom: Color(0xFFFFD98A),
      wall: Color(0xFFFFE9A8),
      far: Color(0xFFF2B96B),
      mid: Color(0xFF8FC8F5),
      floorTop: Color(0xFFD99A57),
      floorSeam: Color(0xFF9A6330),
      floorUnder: Color(0xFFB57A3E),
      kind: 0,
      label: 'playroom floor',
    ),
    DashBackdrop(
      skyTop: Color(0xFFE9F6F2),
      skyBottom: Color(0xFFBFE3DC),
      wall: Color(0xFFCDEBE4),
      far: Color(0xFF9FD0C6),
      mid: Color(0xFFF2A65A),
      floorTop: Color(0xFFF5F1E6),
      floorSeam: Color(0xFFB9B2A0),
      floorUnder: Color(0xFFD9D2BE),
      kind: 1,
      label: 'kitchen counter',
    ),
    DashBackdrop(
      skyTop: Color(0xFFB9D7FF),
      skyBottom: Color(0xFF8FB8F0),
      wall: Color(0xFF9CC0F2),
      far: Color(0xFF6E97D6),
      mid: Color(0xFFE08A5A),
      floorTop: Color(0xFFC98F52),
      floorSeam: Color(0xFF7A5128),
      floorUnder: Color(0xFFA06F3A),
      kind: 2,
      label: 'toy shelf',
    ),
    DashBackdrop(
      skyTop: Color(0xFF1C2250),
      skyBottom: Color(0xFF3B3F86),
      wall: Color(0xFF2A2F6A),
      far: Color(0xFF3F4592),
      mid: Color(0xFFFFC83D),
      floorTop: Color(0xFF8A6A4A),
      floorSeam: Color(0xFF4F3A24),
      floorUnder: Color(0xFF65492F),
      kind: 3,
      label: 'night desk',
    ),
    DashBackdrop(
      skyTop: Color(0xFFFFB07A),
      skyBottom: Color(0xFFFFE0A8),
      wall: Color(0xFFFFCB92),
      far: Color(0xFFE88B6E),
      mid: Color(0xFFB3567B),
      floorTop: Color(0xFFC25A4B),
      floorSeam: Color(0xFF7E2E2A),
      floorUnder: Color(0xFFA24539),
      kind: 4,
      label: 'rooftop of the toy city',
    ),
  ];

  static DashBackdrop of(int course) => all[(course - 1).clamp(0, 4)];
}

enum DashFxKind { dust, spark, confetti, part, speedLine, starFly, ring }

/// A short effect in world units (x along the track, y above the ground).
class DashFx {
  DashFx(
    this.kind,
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.life,
    this.color, {
    this.size = 1,
    this.part = 0,
    this.rot = 0,
    this.vr = 0,
  }) : maxLife = life;

  final DashFxKind kind;
  double x, y, vx, vy, life, rot, vr;
  final double maxLife;
  final Color color;
  final double size;

  /// For [DashFxKind.part]: 0 wheel, 1 key, 2 bolt, 3 bumper.
  final int part;
}

/// Where the world sits in the box: units to dp, the ground line and the camera.
class DashView {
  DashView(this.size, this.cameraX, this.scale, this.groundY);

  factory DashView.of(Size size, double carX) {
    final perUnit = size.height / 36;
    final unitsW = (size.width / perUnit).clamp(40.0, 90.0);
    final scale = min(size.width / unitsW, perUnit);
    final strip = 36 * scale;
    final top = max(0.0, (size.height - strip) / 2);
    // 26 units of sky above the ground line, 10 units of floor below it.
    final groundY = top + 26 * scale;
    final visible = size.width / scale;
    return DashView(size, carX - visible * 0.2, scale, groundY);
  }

  final Size size;
  final double cameraX;
  final double scale;
  final double groundY;

  double sx(double x) => (x - cameraX) * scale;
  double sy(double y) => groundY - y * scale;
  double get visibleUnits => size.width / scale;
}

/// Everything the painter needs for one frame.
class DashScene {
  const DashScene({
    required this.game,
    required this.time,
    required this.backdrop,
    required this.fx,
    this.shake = Offset.zero,
    this.squash = 0,
    this.tumble = 0,
    this.carHidden = false,
    this.reduce = false,
    this.coast = 0,
    this.hintX,
    this.windUp = -1,
    this.glowPulse = 0,
  });

  final DashGame game;
  final double time;
  final DashBackdrop backdrop;
  final List<DashFx> fx;
  final Offset shake;

  /// -1 (squashed) to 1 (stretched).
  final double squash;

  /// 0 to 1 while the car tumbles after a crash.
  final double tumble;
  final bool carHidden;
  final bool reduce;

  /// Extra units the car rolls on after the flag.
  final double coast;
  final double? hintX;

  /// 0 to 1 during the ready beat (the key winds), -1 otherwise.
  final double windUp;
  final double glowPulse;

  double get carX => game.x + coast;
}

/// Paints the whole play view: backdrop (three parallax layers), floor, hazards, flags, stars, car and effects.
class DashWorldPainter extends CustomPainter {
  DashWorldPainter(this.scene);
  final DashScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final g = scene.game;
    final view = DashView.of(size, scene.carX);
    final b = scene.backdrop;
    canvas.save();
    if (scene.shake != Offset.zero) {
      canvas.translate(scene.shake.dx, scene.shake.dy);
    }
    _sky(canvas, size, view, b);
    _layers(canvas, size, view, b);
    _floor(canvas, size, view, b);
    _flags(canvas, view);
    _hint(canvas, view);
    _stars(canvas, view);
    _hazards(canvas, view, b);
    if (!scene.carHidden) {
      final dip = g.gapProgress * 1.2;
      paintCar(
        canvas,
        Offset(view.sx(scene.carX), view.sy(max(0, g.y) - dip)),
        view.scale,
        time: scene.time,
        speed: dashSpeed(g.x, start: g.course?.startSpeed ?? 32),
        airborne: g.y > 0.05,
        squash: scene.squash,
        glow: g.meter.full,
        pulse: scene.glowPulse,
        tilt: scene.tumble > 0 ? scene.tumble * 2 * pi : (g.y > 0 ? -0.05 : 0),
        windUp: scene.windUp,
      );
    }
    _fx(canvas, view);
    canvas.restore();
  }

  void _sky(Canvas canvas, Size size, DashView v, DashBackdrop b) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [b.skyTop, b.skyBottom],
        ).createShader(Offset.zero & size),
    );
    // the wall: a band behind the strip
    canvas.drawRect(
      Rect.fromLTRB(0, v.groundY - 24 * v.scale, size.width, v.groundY),
      Paint()..color = b.wall.withValues(alpha: 0.55),
    );
  }

  /// Draws [draw] for every tile of period [period] (dp) that is on screen, scrolled at [factor] of the speed.
  void _tiles(
    Canvas canvas,
    Size size,
    DashView v,
    double factor,
    double period,
    void Function(Canvas, double left, int index) draw,
  ) {
    final off = v.cameraX * v.scale * factor;
    final first = (off / period).floor() - 1;
    final last = ((off + size.width) / period).ceil() + 1;
    for (var i = first; i <= last; i++) {
      draw(canvas, i * period - off, i);
    }
  }

  void _layers(Canvas canvas, Size size, DashView v, DashBackdrop b) {
    final u = v.scale;
    final gy = v.groundY;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, u * 0.16)
      ..color = dashInk.withValues(alpha: 0.55);
    // far layer (0.2 of the speed): big soft shapes
    _tiles(canvas, size, v, scene.reduce ? 0.0 : 0.2, 22 * u, (c, left, i) {
      final h = 6 + (i * 7 % 5) * 1.6;
      switch (b.kind) {
        case 0: // shelf with toy blocks
          final r = Rect.fromLTWH(
            left + 2 * u,
            gy - (h + 8) * u,
            16 * u,
            h * u,
          );
          c.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(u)),
            Paint()..color = b.far,
          );
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u)), ink);
        case 1: // cabinets
          final r = Rect.fromLTWH(left + 1 * u, gy - 22 * u, 18 * u, 12 * u);
          c.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(u)),
            Paint()..color = b.far,
          );
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u)), ink);
          c.drawCircle(
            r.center.translate(6 * u, 0),
            u * 0.7,
            Paint()..color = dashInk.withValues(alpha: 0.5),
          );
          c.drawCircle(
            r.center.translate(-6 * u, 0),
            u * 0.7,
            Paint()..color = dashInk.withValues(alpha: 0.5),
          );
        case 2: // window panes
          final r = Rect.fromLTWH(left + 3 * u, gy - 24 * u, 14 * u, 13 * u);
          c.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(u)),
            Paint()..color = b.far,
          );
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u)), ink);
          c.drawLine(r.centerLeft, r.centerRight, ink);
          c.drawLine(r.topCenter, r.bottomCenter, ink);
        case 3: // moon and stars
          if (i % 2 == 0) {
            c.drawCircle(
              Offset(left + 10 * u, gy - 20 * u),
              3.2 * u,
              Paint()..color = const Color(0xFFFFF3C4),
            );
            c.drawCircle(
              Offset(left + 11.4 * u, gy - 20.8 * u),
              2.8 * u,
              Paint()..color = b.skyBottom,
            );
          } else {
            for (var k = 0; k < 4; k++) {
              c.drawCircle(
                Offset(left + (3 + k * 4.5) * u, gy - (16 + (k * 5 % 7)) * u),
                0.45 * u,
                Paint()..color = Colors.white.withValues(alpha: 0.8),
              );
            }
          }
        default: // toy city skyline
          final bw = 7.0 + (i % 3);
          final bh = 10.0 + (i * 5 % 4) * 2.5;
          for (var k = 0; k < 2; k++) {
            final x = left + (k * 10 + 1) * u;
            final r = Rect.fromLTWH(
              x,
              gy - (bh - k * 3 + 4) * u,
              bw * u,
              (bh - k * 3 + 4) * u,
            );
            c.drawRect(r, Paint()..color = b.far);
            c.drawRect(r, ink);
            for (var wy = 0; wy < 3; wy++) {
              c.drawRect(
                Rect.fromLTWH(
                  x + 1.4 * u,
                  r.top + (1.5 + wy * 3) * u,
                  1.6 * u,
                  1.6 * u,
                ),
                Paint()..color = const Color(0xFFFFE9A8),
              );
            }
          }
      }
    });
    // mid layer (0.5): smaller props
    _tiles(canvas, size, v, scene.reduce ? 0.0 : 0.5, 16 * u, (c, left, i) {
      final p = Paint()..color = b.mid;
      switch (b.kind) {
        case 0: // a ball and a toy chest
          if (i % 2 == 0) {
            c.drawCircle(Offset(left + 6 * u, gy - 3 * u), 3 * u, p);
            c.drawCircle(Offset(left + 6 * u, gy - 3 * u), 3 * u, ink);
          } else {
            final r = Rect.fromLTWH(left + 3 * u, gy - 6 * u, 9 * u, 6 * u);
            c.drawRRect(
              RRect.fromRectAndRadius(r, Radius.circular(u)),
              Paint()..color = dashBrickColors[i.abs() % 4],
            );
            c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u)), ink);
          }
        case 1: // jars
          final r = Rect.fromLTWH(left + 4 * u, gy - 7 * u, 4.5 * u, 7 * u);
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u)), p);
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u)), ink);
          c.drawRect(
            Rect.fromLTWH(r.left, r.top - 1.2 * u, r.width, 1.2 * u),
            Paint()..color = dashInk.withValues(alpha: 0.6),
          );
        case 2: // book spines
          for (var k = 0; k < 3; k++) {
            final h = 6 + (k + i) % 3 * 1.5;
            final r = Rect.fromLTWH(
              left + (3 + k * 2.3) * u,
              gy - h * u,
              2 * u,
              h * u,
            );
            c.drawRect(r, Paint()..color = dashBrickColors[(i + k).abs() % 4]);
            c.drawRect(r, ink);
          }
        case 3: // desk lamp
          if (i % 2 == 0) {
            c.drawLine(
              Offset(left + 5 * u, gy),
              Offset(left + 5 * u, gy - 9 * u),
              Paint()
                ..color = dashInk
                ..strokeWidth = u * 0.6,
            );
            c.drawPath(
              Path()
                ..moveTo(left + 2 * u, gy - 9 * u)
                ..lineTo(left + 8 * u, gy - 9 * u)
                ..lineTo(left + 6.5 * u, gy - 12 * u)
                ..lineTo(left + 3.5 * u, gy - 12 * u)
                ..close(),
              p,
            );
          } else {
            final r = Rect.fromLTWH(left + 4 * u, gy - 5 * u, 8 * u, 5 * u);
            c.drawRRect(
              RRect.fromRectAndRadius(r, Radius.circular(u * 0.6)),
              Paint()..color = dashBrickColors[1],
            );
            c.drawRRect(
              RRect.fromRectAndRadius(r, Radius.circular(u * 0.6)),
              ink,
            );
          }
        default: // chimneys and antenna
          final r = Rect.fromLTWH(left + 5 * u, gy - 8 * u, 4 * u, 8 * u);
          c.drawRect(r, p);
          c.drawRect(r, ink);
          c.drawRect(
            Rect.fromLTWH(left + 4.3 * u, gy - 9 * u, 5.4 * u, 1.2 * u),
            Paint()..color = dashInk.withValues(alpha: 0.6),
          );
      }
    });
  }

  void _floor(Canvas canvas, Size size, DashView v, DashBackdrop b) {
    final gy = v.groundY;
    final u = v.scale;
    final under = Rect.fromLTRB(0, gy, size.width, size.height);
    canvas.drawRect(under, Paint()..color = b.floorUnder);
    canvas.drawRect(
      Rect.fromLTRB(0, gy, size.width, gy + 4 * u),
      Paint()..color = b.floorTop,
    );
    // seams of the boards scroll at the full speed
    final seam = Paint()
      ..color = b.floorSeam
      ..strokeWidth = max(1.5, u * 0.18);
    _tiles(canvas, size, v, 1.0, 12 * u, (c, left, i) {
      c.drawLine(Offset(left, gy), Offset(left, gy + 4 * u), seam);
      c.drawLine(
        Offset(left + 6 * u, gy + 4 * u),
        Offset(left + 6 * u, size.height),
        seam,
      );
    });
    canvas.drawLine(
      Offset(0, gy + 4 * u),
      Offset(size.width, gy + 4 * u),
      seam,
    );
    // the gaps: dark slots through the floor
    for (final h in scene.game.track.hazards) {
      if (h.kind != HazardKind.gap) continue;
      if (h.end < v.cameraX - 2 || h.x > v.cameraX + v.visibleUnits + 2) {
        continue;
      }
      final r = Rect.fromLTRB(v.sx(h.x), gy, v.sx(h.end), size.height);
      canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2F44), Color(0xFF14111F)],
          ).createShader(r),
      );
      canvas.drawRect(
        Rect.fromLTRB(r.left - u * 0.3, gy, r.left, gy + 4 * u),
        Paint()..color = dashInk,
      );
      canvas.drawRect(
        Rect.fromLTRB(r.right, gy, r.right + u * 0.3, gy + 4 * u),
        Paint()..color = dashInk,
      );
    }
    canvas.drawLine(
      Offset(0, gy),
      Offset(size.width, gy),
      Paint()
        ..color = dashInk
        ..strokeWidth = max(2, u * 0.25),
    );
    // re-cut the line over gaps
    for (final h in scene.game.track.hazards) {
      if (h.kind != HazardKind.gap) continue;
      if (h.end < v.cameraX - 2 || h.x > v.cameraX + v.visibleUnits + 2) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTRB(v.sx(h.x), gy - max(2, u * 0.25), v.sx(h.end), gy + 1),
        Paint()..color = const Color(0xFF3A2F44),
      );
    }
  }

  void _hazards(Canvas canvas, DashView v, DashBackdrop b) {
    final u = v.scale;
    var n = 0;
    for (final h in scene.game.track.hazards) {
      n++;
      if (h.kind != HazardKind.block) continue;
      if (h.end < v.cameraX - 2 || h.x > v.cameraX + v.visibleUnits + 2) {
        continue;
      }
      final body = Rect.fromLTRB(
        v.sx(h.x),
        v.sy(h.height),
        v.sx(h.end),
        v.sy(0),
      );
      // shadow
      canvas.drawOval(
        Rect.fromLTWH(
          body.left - u * 0.5,
          body.bottom - u * 0.4,
          body.width + u,
          u * 0.9,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      final color = dashBrickColors[n % dashBrickColors.length];
      final rr = RRect.fromRectAndRadius(body, Radius.circular(u * 0.5));
      canvas.drawRRect(rr, Paint()..color = color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            body.left + u * 0.4,
            body.top + u * 0.4,
            body.width - u * 0.8,
            u * 0.9,
          ),
          Radius.circular(u * 0.4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2, u * 0.28)
          ..color = dashInk,
      );
      // studs on top
      final studs = max(1, (h.width / 2).floor());
      final sw = body.width / studs;
      for (var k = 0; k < studs; k++) {
        final cx = body.left + sw * (k + 0.5);
        final stud = Rect.fromCenter(
          center: Offset(cx, body.top - u * 0.35),
          width: min(sw * 0.7, u * 1.6),
          height: u * 0.8,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(stud, Radius.circular(u * 0.3)),
          Paint()..color = color,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(stud, Radius.circular(u * 0.3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, u * 0.2)
            ..color = dashInk,
        );
      }
    }
  }

  void _flags(Canvas canvas, DashView v) {
    final u = v.scale;
    final g = scene.game;
    final c = g.course;
    if (c == null) return;
    for (var k = 0; k < c.flags.length; k++) {
      final f = c.flags[k];
      if (f < v.cameraX - 4 || f > v.cameraX + v.visibleUnits + 4) continue;
      final reached = g.checkpoint > k;
      final x = v.sx(f);
      final top = v.sy(11);
      canvas.drawLine(
        Offset(x, v.sy(0)),
        Offset(x, top),
        Paint()
          ..color = dashInk
          ..strokeWidth = max(2, u * 0.3),
      );
      final wave = scene.reduce ? 0.0 : sin(scene.time * 5 + k) * u * 0.25;
      final flag = Path()
        ..moveTo(x, top)
        ..lineTo(x + 4.2 * u, top + 1.4 * u + wave)
        ..lineTo(x, top + 3 * u)
        ..close();
      canvas.drawPath(
        flag,
        Paint()..color = reached ? const Color(0xFF2FB36B) : dashGold,
      );
      canvas.drawPath(
        flag,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, u * 0.22)
          ..strokeJoin = StrokeJoin.round
          ..color = dashInk,
      );
    }
    // the finish: two posts and a checkered banner
    final len = c.length;
    if (len > v.cameraX - 6 && len < v.cameraX + v.visibleUnits + 6) {
      final x = v.sx(len);
      final p = Paint()
        ..color = dashInk
        ..strokeWidth = max(2.5, u * 0.4);
      canvas.drawLine(
        Offset(x - 5 * u, v.sy(0)),
        Offset(x - 5 * u, v.sy(13)),
        p,
      );
      canvas.drawLine(
        Offset(x + 5 * u, v.sy(0)),
        Offset(x + 5 * u, v.sy(13)),
        p,
      );
      final banner = Rect.fromLTRB(x - 5 * u, v.sy(13), x + 5 * u, v.sy(10.5));
      final cols = 10, rows = 2;
      for (var cx = 0; cx < cols; cx++) {
        for (var cy = 0; cy < rows; cy++) {
          canvas.drawRect(
            Rect.fromLTWH(
              banner.left + cx * banner.width / cols,
              banner.top + cy * banner.height / rows,
              banner.width / cols,
              banner.height / rows,
            ),
            Paint()..color = (cx + cy).isEven ? dashInk : Colors.white,
          );
        }
      }
      canvas.drawRect(
        banner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2, u * 0.25)
          ..color = dashInk,
      );
    }
  }

  void _hint(Canvas canvas, DashView v) {
    final hx = scene.hintX;
    if (hx == null) return;
    final u = v.scale;
    final x = v.sx(hx);
    final p = Paint()
      ..color = dashInk.withValues(alpha: 0.75)
      ..strokeWidth = max(2, u * 0.25)
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 7; k++) {
      final y = v.sy(1 + k * 1.6);
      canvas.drawLine(Offset(x, y), Offset(x, y - u * 0.7), p);
    }
    final path = Path()
      ..moveTo(x - u * 1.4, v.sy(13))
      ..lineTo(x + u * 1.4, v.sy(13))
      ..lineTo(x, v.sy(11.4))
      ..close();
    canvas.drawPath(path, Paint()..color = dashGold);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, u * 0.2)
        ..strokeJoin = StrokeJoin.round
        ..color = dashInk,
    );
  }

  void _stars(Canvas canvas, DashView v) {
    final u = v.scale;
    final g = scene.game;
    final stars = g.track.stars;
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      if (s.x < v.cameraX - 3) continue;
      if (s.x > v.cameraX + v.visibleUnits + 3) break;
      if (g.taken.contains(i)) continue;
      final bob = scene.reduce ? 0.0 : sin(scene.time * 3 + s.x) * 0.25;
      final spin = scene.reduce
          ? 1.0
          : (0.55 + 0.45 * cos(scene.time * 2.4 + s.x * 0.7).abs());
      paintStar(
        canvas,
        Offset(v.sx(s.x), v.sy(s.y + bob)),
        u * 1.7,
        spin: spin,
      );
    }
  }

  void _fx(Canvas canvas, DashView v) {
    final u = v.scale;
    for (final f in scene.fx) {
      final t = (f.life / f.maxLife).clamp(0.0, 1.0);
      final pos = Offset(v.sx(f.x), v.sy(f.y));
      switch (f.kind) {
        case DashFxKind.dust:
          canvas.drawCircle(
            pos,
            u * f.size * (1.4 - t * 0.6),
            Paint()..color = Colors.white.withValues(alpha: 0.7 * t),
          );
        case DashFxKind.spark:
          final p = Paint()
            ..color = f.color.withValues(alpha: t)
            ..strokeWidth = max(2, u * 0.3)
            ..strokeCap = StrokeCap.round;
          for (var k = 0; k < 8; k++) {
            final a = k * pi / 4;
            final r1 = u * (0.8 + (1 - t) * 2.4) * f.size;
            canvas.drawLine(
              pos + Offset(cos(a), sin(a)) * r1,
              pos + Offset(cos(a), sin(a)) * (r1 + u * 0.8),
              p,
            );
          }
        case DashFxKind.ring:
          canvas.drawCircle(
            pos,
            u * (1 + (1 - t) * 3) * f.size,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(2, u * 0.3)
              ..color = f.color.withValues(alpha: t),
          );
        case DashFxKind.confetti:
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(f.rot);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * 0.9,
              height: u * 0.5,
            ),
            Paint()..color = f.color.withValues(alpha: min(1, t * 2)),
          );
          canvas.restore();
        case DashFxKind.speedLine:
          canvas.drawLine(
            pos,
            pos + Offset(-u * 4.5 * f.size, 0),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.55 * t)
              ..strokeWidth = max(1.5, u * 0.18)
              ..strokeCap = StrokeCap.round,
          );
        case DashFxKind.starFly:
          paintStar(canvas, pos, u * 1.4 * (0.6 + 0.4 * t), spin: 1);
        case DashFxKind.part:
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(f.rot);
          _part(canvas, f.part, u);
          canvas.restore();
      }
    }
  }

  void _part(Canvas canvas, int part, double u) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, u * 0.22)
      ..color = dashInk;
    switch (part) {
      case 0: // wheel
        canvas.drawCircle(Offset.zero, u * 0.8, Paint()..color = dashInk);
        canvas.drawCircle(Offset.zero, u * 0.3, Paint()..color = dashGold);
      case 1: // key
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-u * 0.6, 0),
            width: u * 1.2,
            height: u * 1.6,
          ),
          Paint()..color = dashGold,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(u * 0.6, 0),
            width: u * 1.2,
            height: u * 1.6,
          ),
          Paint()..color = dashGold,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-u * 0.6, 0),
            width: u * 1.2,
            height: u * 1.6,
          ),
          ink,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(u * 0.6, 0),
            width: u * 1.2,
            height: u * 1.6,
          ),
          ink,
        );
      case 2: // bolt
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * 1.4,
              height: u * 0.7,
            ),
            Radius.circular(u * 0.2),
          ),
          Paint()..color = const Color(0xFF8E8AA8),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * 1.4,
              height: u * 0.7,
            ),
            Radius.circular(u * 0.2),
          ),
          ink,
        );
      default: // bumper
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * 1.6,
              height: u * 0.9,
            ),
            Radius.circular(u * 0.4),
          ),
          Paint()..color = const Color(0xFFB8B5CC),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * 1.6,
              height: u * 0.9,
            ),
            Radius.circular(u * 0.4),
          ),
          ink,
        );
    }
  }

  @override
  bool shouldRepaint(covariant DashWorldPainter old) => true;
}

/// A paper star with a dark outline. [size] is the outer diameter in dp; [spin] (0 to 1) squeezes it sideways.
void paintStar(Canvas canvas, Offset c, double size, {double spin = 1}) {
  final path = Path();
  const pts = 5;
  for (var i = 0; i < pts * 2; i++) {
    final r = (i.isEven ? size : size * 0.45) / 2;
    final a = -pi / 2 + i * pi / pts;
    final p = Offset(c.dx + cos(a) * r * spin, c.dy + sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = dashGold);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, size * 0.09)
      ..strokeJoin = StrokeJoin.round
      ..color = dashInk,
  );
}

/// The toy wind-up car with the tin key on its back. [c] is the middle of its underside (where the wheels touch
/// the floor); [u] dp per unit. No driver: a body, a roof with two windows, the key, two wheels, two headlights and
/// a spring bumper that glows when the meter is full.
void paintCar(
  Canvas canvas,
  Offset c,
  double u, {
  required double time,
  required double speed,
  bool airborne = false,
  double squash = 0,
  bool glow = false,
  double pulse = 0,
  double tilt = 0,
  double windUp = -1,
}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  if (tilt != 0) {
    canvas.translate(0, -u * 1.2);
    canvas.rotate(tilt);
    canvas.translate(0, u * 1.2);
  }
  // squash and stretch around the wheels' contact line
  canvas.scale(1 - squash * 0.18, 1 + squash * 0.22);
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(2, u * 0.26)
    ..strokeJoin = StrokeJoin.round
    ..color = dashInk;
  // shadow stays on the floor (drawn by the caller for a jump); a small one under the wheels
  if (!airborne) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 0), width: u * 5, height: u * 0.7),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }
  // body
  final body = RRect.fromRectAndRadius(
    Rect.fromLTRB(-2.3 * u, -2.4 * u, 2.3 * u, -0.6 * u),
    Radius.circular(u * 0.8),
  );
  canvas.drawRRect(body, Paint()..color = dashRed);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(-2.0 * u, -2.2 * u, 2.0 * u, -1.5 * u),
      Radius.circular(u * 0.4),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.25),
  );
  canvas.drawRRect(body, ink);
  // roof with two windows
  final roof = Path()
    ..moveTo(-1.5 * u, -2.4 * u)
    ..quadraticBezierTo(-1.2 * u, -3.7 * u, 0, -3.7 * u)
    ..quadraticBezierTo(1.2 * u, -3.7 * u, 1.5 * u, -2.4 * u)
    ..close();
  canvas.drawPath(roof, Paint()..color = const Color(0xFFF7A8AB));
  canvas.drawPath(roof, ink);
  canvas.drawRect(
    Rect.fromLTWH(-1.15 * u, -3.35 * u, 1 * u, 0.85 * u),
    Paint()..color = const Color(0xFFFFF3D6),
  );
  canvas.drawRect(
    Rect.fromLTWH(0.15 * u, -3.35 * u, 1 * u, 0.85 * u),
    Paint()..color = const Color(0xFFFFF3D6),
  );
  // the key on the back: a stem and two lobes that turn (faster with speed; winds up in the ready beat)
  final angle = windUp >= 0 ? windUp * 3 * pi : time * speed * 0.18;
  final spin = cos(angle);
  canvas.drawLine(
    Offset(-2.2 * u, -1.5 * u),
    Offset(-2.9 * u, -2.6 * u),
    Paint()
      ..color = dashInk
      ..strokeWidth = max(2.5, u * 0.4)
      ..strokeCap = StrokeCap.round,
  );
  final lobeW = u * 0.9 * (0.25 + 0.75 * spin.abs());
  for (final s in const [-1.0, 1.0]) {
    final lobe = Rect.fromCenter(
      center: Offset(-2.9 * u + s * lobeW * 0.55, -3.2 * u),
      width: lobeW,
      height: u * 1.6,
    );
    canvas.drawOval(lobe, Paint()..color = dashGold);
    canvas.drawOval(lobe, ink);
  }
  // headlights and spring bumper at the front
  canvas.drawCircle(
    Offset(2.1 * u, -1.7 * u),
    u * 0.55,
    Paint()..color = const Color(0xFFFFF3A8),
  );
  canvas.drawCircle(Offset(2.1 * u, -1.7 * u), u * 0.55, ink);
  final bump = Rect.fromLTRB(2.2 * u, -1.1 * u, 3.1 * u, -0.45 * u);
  if (glow) {
    final r = u * (1.9 + pulse * 0.5);
    canvas.drawCircle(
      bump.center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            dashGold.withValues(alpha: 0.85),
            dashGold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: bump.center, radius: r)),
    );
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(bump, Radius.circular(u * 0.3)),
    Paint()..color = glow ? dashGold : const Color(0xFFB8B5CC),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(bump, Radius.circular(u * 0.3)),
    ink,
  );
  // wheels with turning spokes
  for (final wx in const [-1.4, 1.4]) {
    final w = Offset(wx * u, -0.75 * u);
    canvas.drawCircle(w, u * 0.85, Paint()..color = dashInk);
    canvas.drawCircle(w, u * 0.38, Paint()..color = dashGold);
    final a = windUp >= 0 ? 0.0 : time * speed * 0.55;
    final sp = Paint()
      ..color = dashInk
      ..strokeWidth = max(1.5, u * 0.16);
    canvas.drawLine(
      w + Offset(cos(a), sin(a)) * u * 0.38,
      w - Offset(cos(a), sin(a)) * u * 0.38,
      sp,
    );
    canvas.drawLine(
      w + Offset(-sin(a), cos(a)) * u * 0.38,
      w - Offset(-sin(a), cos(a)) * u * 0.38,
      sp,
    );
  }
  canvas.restore();
}

/// The menu picture: the car with its key turning, on a short floor.
class DashMenuPainter extends CustomPainter {
  DashMenuPainter(this.time);
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final u = min(size.height / 5.5, size.width / 14);
    final gy = size.height * 0.88;
    final seam = Paint()
      ..color = DashBackdrop.all[0].floorSeam
      ..strokeWidth = max(2, u * 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(size.width * 0.12, gy, size.width * 0.88, gy + u * 0.9),
        Radius.circular(u * 0.3),
      ),
      Paint()..color = DashBackdrop.all[0].floorTop,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(size.width * 0.12, gy, size.width * 0.88, gy + u * 0.9),
        Radius.circular(u * 0.3),
      ),
      seam..style = PaintingStyle.stroke,
    );
    final bob = sin(time * 6) * u * 0.06;
    paintCar(
      canvas,
      Offset(size.width / 2, gy + bob),
      u,
      time: time,
      speed: 14,
      glow: false,
    );
    paintStar(
      canvas,
      Offset(size.width / 2 + u * 5.2, gy - u * 3.2 + sin(time * 3) * u * 0.2),
      u * 1.8,
      spin: 0.6 + 0.4 * cos(time * 2).abs(),
    );
    paintStar(
      canvas,
      Offset(
        size.width / 2 - u * 5.5,
        gy - u * 4.6 + sin(time * 3 + 1) * u * 0.2,
      ),
      u * 1.3,
      spin: 0.6 + 0.4 * cos(time * 2 + 1).abs(),
    );
  }

  @override
  bool shouldRepaint(covariant DashMenuPainter old) => old.time != time;
}

/// The menu and results backdrop: the course's sky and wall with soft shapes.
class DashSkyPainter extends CustomPainter {
  DashSkyPainter(this.b, this.time);
  final DashBackdrop b;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [b.skyTop, b.skyBottom],
        ).createShader(Offset.zero & size),
    );
    final floor = Rect.fromLTRB(0, size.height * 0.78, size.width, size.height);
    canvas.drawRect(floor, Paint()..color = b.floorUnder);
    canvas.drawRect(
      Rect.fromLTRB(0, floor.top, size.width, floor.top + 18),
      Paint()..color = b.floorTop,
    );
    canvas.drawLine(
      Offset(0, floor.top),
      Offset(size.width, floor.top),
      Paint()
        ..color = dashInk
        ..strokeWidth = 3,
    );
    final seam = Paint()
      ..color = b.floorSeam
      ..strokeWidth = 2;
    for (var x = 20.0; x < size.width; x += 90) {
      canvas.drawLine(
        Offset(x, floor.top + 18),
        Offset(x - 12, size.height),
        seam,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashSkyPainter old) => old.b != b;
}

/// The spring meter icon: a coil with [bulbs] of 5 lit.
class SpringIconPainter extends CustomPainter {
  SpringIconPainter(this.bulbs, this.full, {this.pulse = 0});
  final int bulbs;
  final bool full;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 5;
    for (var i = 0; i < 5; i++) {
      final lit = i < bulbs || full;
      final c = Offset(w * (i + 0.5), size.height / 2);
      final r = min(w, size.height) * (0.36 + (full ? pulse * 0.08 : 0));
      canvas.drawCircle(
        c,
        r,
        Paint()..color = lit ? dashGold : Colors.white.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = dashInk,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpringIconPainter old) => true;
}

/// A small gold star for the HUD counter.
class StarIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintStar(canvas, size.center(Offset.zero), size.shortestSide * 1.05);
  }

  @override
  bool shouldRepaint(covariant StarIconPainter old) => false;
}
