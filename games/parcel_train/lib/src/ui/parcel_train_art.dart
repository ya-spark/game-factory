import 'dart:math';

import 'package:flutter/material.dart';

import '../rules/parcel_train_rules.dart';

/// Code art of Parcel train: a toy train on a printed play mat. Toys only (no living beings): the engine has a
/// round lamp and a chimney, no face and no driver. Thick dark outline, flat bright colours, a drop shadow.
const Color trainInk = Color(0xFF2B2A4C);
const Color trainGold = Color(0xFFFFC83D);
const List<Color> trainParcelColors = [
  Color(0xFFE5484D), // red, ribbon: cross
  Color(0xFF3B82F6), // blue, ribbon: X
  Color(0xFF2FB36B), // green, ribbon: ring
  Color(0xFF8B5CF6), // purple, ribbon: bar
  Color(0xFFC9A36B), // empty wagon
];

/// Mat colours: green rug, wooden floor, kitchen tile, felt table, map cloth, and Free ride (green rug again).
class TrainMat {
  const TrainMat(this.base, this.mark, this.kind);
  final Color base;
  final Color mark;
  final int kind;
  static const List<TrainMat> all = [
    TrainMat(Color(0xFF6FC26A), Color(0xFF8BD685), 0),
    TrainMat(Color(0xFFD9A566), Color(0xFFB98544), 1),
    TrainMat(Color(0xFFF0E4CC), Color(0xFFD9C7A3), 2),
    TrainMat(Color(0xFF5E92D8), Color(0xFF7BA9E6), 3),
    TrainMat(Color(0xFFF2DFAE), Color(0xFFD8BF86), 4),
    TrainMat(Color(0xFF6FC26A), Color(0xFF8BD685), 0),
  ];
  static TrainMat of(int courseNumberOrZero) =>
      all[courseNumberOrZero == 0 ? 5 : courseNumberOrZero - 1];
}

/// The play-mat backdrop that fills the whole box.
class MatPainter extends CustomPainter {
  MatPainter(this.mat);
  final TrainMat mat;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = mat.base);
    final p = Paint()..color = mat.mark;
    const s = 48.0;
    switch (mat.kind) {
      case 0: // rug: dots
        for (var y = 0.0; y < size.height + s; y += s) {
          for (var x = 0.0; x < size.width + s; x += s) {
            canvas.drawCircle(
              Offset(x + ((y / s).round().isEven ? 0 : s / 2), y),
              4,
              p,
            );
          }
        }
      case 1: // planks
        p.strokeWidth = 2;
        for (var y = 0.0; y < size.height + s; y += s) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        for (var y = 0.0, r = 0; y < size.height + s; y += s, r++) {
          for (var x = (r.isEven ? 0.0 : s * 2); x < size.width; x += s * 4) {
            canvas.drawLine(Offset(x, y), Offset(x, y + s), p);
          }
        }
      case 2: // tiles
        for (var y = 0.0, r = 0; y < size.height + s; y += s, r++) {
          for (var x = 0.0, c = 0; x < size.width + s; x += s, c++) {
            if ((r + c).isEven) canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
          }
        }
      case 3: // felt: soft diagonal lines
        p
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (var d = -size.height; d < size.width; d += 28) {
          canvas.drawLine(
            Offset(d, 0),
            Offset(d + size.height, size.height),
            p,
          );
        }
      default: // map cloth: grid
        p
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        for (var x = 0.0; x < size.width; x += s) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = 0.0; y < size.height; y += s) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
    }
  }

  @override
  bool shouldRepaint(covariant MatPainter old) => old.mat != mat;
}

enum TrainFxKind { smoke, steam, confetti, spark }

class TrainFx {
  TrainFx(
    this.kind,
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.life,
    this.color, [
    this.size = 0.2,
  ]) : maxLife = life;
  final TrainFxKind kind;
  double x, y, vx, vy, life;
  final double maxLife;
  final Color color;
  final double size;
  double get t => 1 - life / maxLife;
}

/// Everything the field painter needs for one frame.
class TrainScene {
  TrainScene({
    required this.game,
    required this.prev,
    required this.progress,
    required this.rails,
    required this.fx,
    required this.time,
    this.shake = Offset.zero,
    this.tumble = 0,
    this.fly,
    this.coupleT = 1,
    this.arrive = 0,
    this.reduce = false,
  });
  final TrainGame game;

  /// The body before the last move (head first).
  final List<TrainCell> prev;

  /// 0 to 1 between the last move and the next.
  final double progress;

  /// Cell to the set of directions its rail connects (bits: up 1, down 2, left 4, right 8).
  final Map<TrainCell, int> rails;
  final List<TrainFx> fx;
  final double time;
  final Offset shake;

  /// 0 to 1: the derail tumble.
  final double tumble;

  /// A parcel flying onto the new wagon: from, to (cell units), progress 0 to 1.
  final (Offset, Offset, double)? fly;

  /// 0 to 1 spring of the newest wagon.
  final double coupleT;

  /// 0 to 1: how far the wagons have unloaded on arrival (seconds-based).
  final double arrive;

  /// Reduced motion: no shake, drift, tumble, confetti or waving flag.
  final bool reduce;
}

int railBit(TrainDir d) => switch (d) {
  TrainDir.up => 1,
  TrainDir.down => 2,
  TrainDir.left => 4,
  TrainDir.right => 8,
};

/// Paints the mat field: cloth, rails, walls, parcels, the train and the effects, from the logic state.
class TrainFieldPainter extends CustomPainter {
  TrainFieldPainter(this.scene, this.mat);
  final TrainScene scene;
  final TrainMat mat;

  TrainGame get g => scene.game;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / g.cols;
    canvas.save();
    canvas.translate(scene.shake.dx, scene.shake.dy);
    _cloth(canvas, size, cs);
    _rails(canvas, cs);
    _walls(canvas, cs);
    _items(canvas, cs);
    _train(canvas, cs);
    _fx(canvas, cs);
    canvas.restore();
  }

  void _cloth(Canvas canvas, Size size, double cs) {
    canvas.drawRect(Offset.zero & size, Paint()..color = mat.base);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.16);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.05);
    for (var y = 0; y < g.rows; y++) {
      for (var x = 0; x < g.cols; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cs, y * cs, cs, cs),
          (x + y).isEven ? light : dark,
        );
      }
    }
  }

  Rect _cell(double cs, int x, int y) => Rect.fromLTWH(x * cs, y * cs, cs, cs);

  // ---- rails ----

  void _rails(Canvas canvas, double cs) {
    final sleeper = Paint()..color = const Color(0xFF8A5A2B);
    final steel = Paint()
      ..color = const Color(0xFF6B7280)
      ..strokeWidth = max(2, cs * 0.07)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final e in scene.rails.entries) {
      final c = e.key;
      final m = e.value;
      final o = Offset((c.x + 0.5) * cs, (c.y + 0.5) * cs);
      final dirs = [
        for (final d in TrainDir.values)
          if (m & railBit(d) != 0) d,
      ];
      final curve = dirs.length == 2 && dirs[0] != dirs[1].opposite;
      for (final d in dirs) {
        final end = o + Offset(d.dx * cs / 2, d.dy * cs / 2);
        final n = Offset(-d.dy.toDouble(), d.dx.toDouble());
        for (final f in [0.3, 0.75]) {
          final at = Offset.lerp(o, end, f)!;
          canvas.drawLine(
            at - n * cs * 0.3,
            at + n * cs * 0.3,
            sleeper..strokeWidth = max(3, cs * 0.12),
          );
        }
      }
      if (curve) {
        final a = o + Offset(dirs[0].dx * cs / 2, dirs[0].dy * cs / 2);
        final b = o + Offset(dirs[1].dx * cs / 2, dirs[1].dy * cs / 2);
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(o.dx, o.dy, b.dx, b.dy);
        canvas.drawPath(path, steel);
      } else {
        for (final d in dirs) {
          final n = Offset(-d.dy.toDouble(), d.dx.toDouble());
          final end = o + Offset(d.dx * cs / 2, d.dy * cs / 2);
          for (final k in [-0.13, 0.13]) {
            canvas.drawLine(o + n * cs * k, end + n * cs * k, steel);
          }
        }
      }
    }
  }

  // ---- walls ----

  void _walls(Canvas canvas, double cs) {
    final c = g.course;
    if (c == null) return;
    final pairIndex = <TrainCell, int>{};
    var next = 0;
    for (final k
        in c.tunnelPairs.keys.toList()
          ..sort((a, b) => a.y != b.y ? a.y - b.y : a.x - b.x)) {
      if (pairIndex.containsKey(k)) continue;
      pairIndex[k] = next;
      pairIndex[c.tunnelPairs[k]!] = next;
      next++;
    }
    for (var y = 0; y < c.rows; y++) {
      for (var x = 0; x < c.cols; x++) {
        final r = _cell(cs, x, y);
        switch (c.tile(x, y)) {
          case TrainTile.block:
            _block(canvas, r, (x * 3 + y) % 3);
          case TrainTile.fence:
            _fence(canvas, r);
          case TrainTile.pond:
            _pond(canvas, r, c, x, y);
          case TrainTile.tunnel:
            _tunnel(canvas, r, pairIndex[TrainCell(x, y)] ?? 0, c, x, y);
          case TrainTile.gate:
            _gate(canvas, r);
          case TrainTile.free:
            break;
        }
      }
    }
  }

  void _shadow(Canvas canvas, Rect r, double radius) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r.shift(Offset(r.width * 0.05, r.height * 0.07)),
        Radius.circular(radius),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
  }

  Paint _outline(double cs) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.5, cs * 0.06)
    ..color = trainInk;

  void _block(Canvas canvas, Rect cell, int colorIdx) {
    final cs = cell.width;
    final r = cell.deflate(cs * 0.06);
    _shadow(canvas, r, cs * 0.14);
    const cols = [Color(0xFFE5484D), Color(0xFFFFC83D), Color(0xFF3B82F6)];
    final rr = RRect.fromRectAndRadius(r, Radius.circular(cs * 0.14));
    canvas.drawRRect(rr, Paint()..color = cols[colorIdx]);
    canvas.drawRRect(rr, _outline(cs));
    final stud = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (final dx in [0.3, 0.7]) {
      for (final dy in [0.3, 0.7]) {
        canvas.drawCircle(
          Offset(cell.left + cs * dx, cell.top + cs * dy),
          cs * 0.1,
          stud,
        );
      }
    }
  }

  void _fence(Canvas canvas, Rect cell) {
    final cs = cell.width;
    final wood = Paint()..color = const Color(0xFFFFF3D6);
    final line = _outline(cs);
    final rail = Paint()
      ..color = const Color(0xFFB98544)
      ..strokeWidth = cs * 0.1;
    final y0 = cell.top + cs * 0.3, y1 = cell.top + cs * 0.7;
    canvas.drawLine(Offset(cell.left, y0), Offset(cell.right, y0), rail);
    canvas.drawLine(Offset(cell.left, y1), Offset(cell.right, y1), rail);
    for (final fx in [0.2, 0.5, 0.8]) {
      final p = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cell.left + cs * fx, cell.center.dy),
          width: cs * 0.2,
          height: cs * 0.82,
        ),
        Radius.circular(cs * 0.07),
      );
      canvas.drawRRect(
        p.shift(Offset(cs * 0.03, cs * 0.04)),
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
      canvas.drawRRect(p, wood);
      canvas.drawRRect(p, line);
    }
  }

  void _pond(Canvas canvas, Rect cell, TrainCourse c, int x, int y) {
    final cs = cell.width;
    canvas.drawRect(cell, Paint()..color = const Color(0xFF4AA3E8));
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, cs * 0.05);
    final p = Path()
      ..moveTo(cell.left + cs * 0.15, cell.center.dy)
      ..quadraticBezierTo(
        cell.left + cs * 0.32,
        cell.center.dy - cs * 0.12,
        cell.center.dx,
        cell.center.dy,
      )
      ..quadraticBezierTo(
        cell.left + cs * 0.68,
        cell.center.dy + cs * 0.12,
        cell.right - cs * 0.15,
        cell.center.dy,
      );
    if ((x + y).isEven) canvas.drawPath(p, wave);
    bool pond(int dx, int dy) {
      final nx = x + dx, ny = y + dy;
      return c.inside(nx, ny) && c.tile(nx, ny) == TrainTile.pond;
    }

    final edge = Paint()
      ..color = trainInk
      ..strokeWidth = max(2, cs * 0.07);
    if (!pond(0, -1)) canvas.drawLine(cell.topLeft, cell.topRight, edge);
    if (!pond(0, 1)) canvas.drawLine(cell.bottomLeft, cell.bottomRight, edge);
    if (!pond(-1, 0)) canvas.drawLine(cell.topLeft, cell.bottomLeft, edge);
    if (!pond(1, 0)) canvas.drawLine(cell.topRight, cell.bottomRight, edge);
  }

  void _tunnel(
    Canvas canvas,
    Rect cell,
    int pair,
    TrainCourse c,
    int x,
    int y,
  ) {
    final cs = cell.width;
    final r = cell.deflate(cs * 0.04);
    _shadow(canvas, r, cs * 0.3);
    const hill = [Color(0xFF8D6E63), Color(0xFF7E8F6A)];
    final body = RRect.fromRectAndRadius(r, Radius.circular(cs * 0.3));
    canvas.drawRRect(body, Paint()..color = hill[pair % 2]);
    canvas.drawRRect(body, _outline(cs));
    final arch = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(r.center.dx, r.center.dy),
          width: cs * 0.5,
          height: cs * 0.5,
        ),
        pi,
        pi,
      )
      ..lineTo(r.center.dx + cs * 0.25, r.center.dy + cs * 0.25)
      ..lineTo(r.center.dx - cs * 0.25, r.center.dy + cs * 0.25)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFF1B1A33));
    // the pair is told by dots (colour is never the only cue): one dot or two
    final dot = Paint()..color = trainGold;
    for (var i = 0; i <= pair; i++) {
      canvas.drawCircle(
        Offset(r.center.dx + (i - pair / 2) * cs * 0.18, r.top + cs * 0.14),
        cs * 0.055,
        dot,
      );
    }
  }

  void _gate(Canvas canvas, Rect cell) {
    final cs = cell.width;
    final open = g.gateOpen;
    final r = cell.deflate(cs * 0.04);
    _shadow(canvas, r, cs * 0.12);
    final pulse = open && !_reduce ? 0.5 + 0.5 * sin(scene.time * 7) : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(cs * 0.12)),
      Paint()
        ..color = Color.lerp(
          const Color(0xFFF7E3B5),
          const Color(0xFFFFF3A8),
          pulse,
        )!,
    );
    final roof = Path()
      ..moveTo(r.left, r.top + cs * 0.42)
      ..lineTo(r.center.dx, r.top)
      ..lineTo(r.right, r.top + cs * 0.42)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFE5484D));
    canvas.drawPath(roof, _outline(cs));
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(cs * 0.12)),
      _outline(cs),
    );
    if (open) {
      // a flag on a pole
      final pole = Paint()
        ..color = trainInk
        ..strokeWidth = max(2, cs * 0.06);
      canvas.drawLine(
        Offset(r.center.dx, r.top + cs * 0.1),
        Offset(r.center.dx, r.top + cs * 0.66),
        pole,
      );
      final wave = _reduce ? 0.0 : sin(scene.time * 8) * cs * 0.04;
      final flag = Path()
        ..moveTo(r.center.dx, r.top + cs * 0.1)
        ..lineTo(r.center.dx + cs * 0.3, r.top + cs * 0.2 + wave)
        ..lineTo(r.center.dx, r.top + cs * 0.32)
        ..close();
      canvas.drawPath(flag, Paint()..color = const Color(0xFF2FB36B));
    } else {
      // a striped barrier across the door
      final bar = Rect.fromLTWH(
        r.left,
        r.center.dy + cs * 0.02,
        r.width,
        cs * 0.2,
      );
      canvas.save();
      canvas.clipRect(bar);
      final w = cs * 0.2;
      for (var i = 0; i < 6; i++) {
        canvas.drawRect(
          Rect.fromLTWH(bar.left + i * w, bar.top, w, bar.height),
          Paint()..color = i.isEven ? const Color(0xFFE5484D) : Colors.white,
        );
      }
      canvas.restore();
      canvas.drawRect(bar, _outline(cs));
    }
  }

  bool get _reduce => scene.reduce;

  // ---- parcels ----

  void _items(Canvas canvas, double cs) {
    final gold = g.golden;
    if (gold != null) {
      _box(
        canvas,
        Offset((gold.x + 0.5) * cs, (gold.y + 0.5) * cs),
        cs,
        5,
        scene.time,
      );
    }
    final p = g.parcel;
    if (p != null) {
      final bob = sin(scene.time * 4) * cs * 0.02;
      _box(
        canvas,
        Offset((p.x + 0.5) * cs, (p.y + 0.5) * cs + bob),
        cs,
        g.parcelColor,
        scene.time,
      );
    }
    final f = scene.fly;
    if (f != null) {
      final pos = Offset.lerp(f.$1, f.$2, f.$3)! * cs;
      final lift = sin(f.$3 * pi) * cs * 0.5;
      _box(
        canvas,
        Offset((pos.dx + cs * 0.5), pos.dy + cs * 0.5 - lift),
        cs,
        g.colors.last,
        0,
        scale: 1 - f.$3 * 0.2,
      );
    }
  }

  /// A parcel box seen from above; [colorIdx] 0 to 3, 5 is the golden parcel. The ribbon shape differs per colour.
  static void paintBox(
    Canvas canvas,
    Offset c,
    double cs,
    int colorIdx,
    double time, {
    double scale = 1,
  }) {
    final golden = colorIdx == 5;
    final size = cs * 0.62 * scale;
    final rect = Rect.fromCenter(center: c, width: size, height: size);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.08));
    canvas.drawRRect(
      rr.shift(Offset(cs * 0.04, cs * 0.05)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = golden ? trainGold : trainParcelColors[colorIdx.clamp(0, 4)],
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cs * 0.06)
        ..color = trainInk,
    );
    final rib = Paint()
      ..color = golden ? Colors.white : const Color(0xFFFFF3D6)
      ..strokeWidth = max(2, cs * 0.09)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final h = size / 2 * 0.8;
    switch (golden ? 9 : colorIdx) {
      case 0:
        canvas.drawLine(c - Offset(h, 0), c + Offset(h, 0), rib);
        canvas.drawLine(c - Offset(0, h), c + Offset(0, h), rib);
      case 1:
        canvas.drawLine(c - Offset(h, h), c + Offset(h, h), rib);
        canvas.drawLine(c - Offset(h, -h), c + Offset(h, -h), rib);
      case 2:
        canvas.drawCircle(c, h * 0.62, rib);
      case 3:
        canvas.drawLine(c - Offset(h, 0), c + Offset(h, 0), rib);
        canvas.drawCircle(c, h * 0.25, Paint()..color = rib.color);
      default:
        // a star on the golden parcel
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -pi / 2 + i * pi / 5;
          final rad = i.isEven ? h * 0.9 : h * 0.4;
          final pt = c + Offset(cos(a) * rad, sin(a) * rad);
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        canvas.drawPath(star, Paint()..color = const Color(0xFFE08A00));
        final tw = 0.5 + 0.5 * sin(time * 6);
        canvas.drawCircle(
          c + Offset(h * 0.9, -h * 0.9),
          cs * 0.05 * (0.6 + tw),
          Paint()..color = Colors.white,
        );
    }
  }

  void _box(
    Canvas canvas,
    Offset c,
    double cs,
    int idx,
    double time, {
    double scale = 1,
  }) => paintBox(canvas, c, cs, idx, time, scale: scale);

  // ---- train ----

  Offset _vis(int i) {
    final cur = g.body[i];
    final pv = scene.prev;
    final from = i < pv.length ? pv[i] : (pv.isEmpty ? cur : pv.last);
    final jump = (cur.x - from.x).abs() + (cur.y - from.y).abs() != 1;
    final p = scene.progress.clamp(0.0, 1.0);
    if (jump) return Offset(cur.x + 0.5, cur.y + 0.5);
    return Offset(
      from.x + (cur.x - from.x) * p + 0.5,
      from.y + (cur.y - from.y) * p + 0.5,
    );
  }

  void _train(Canvas canvas, double cs) {
    final n = g.body.length;
    final pos = [for (var i = 0; i < n; i++) _vis(i)];
    final ang = List<double>.filled(n, 0);
    double headAngle() => atan2(g.dir.dy.toDouble(), g.dir.dx.toDouble());
    ang[0] = headAngle();
    for (var i = 1; i < n; i++) {
      final d = pos[i - 1] - pos[i];
      ang[i] = d.distance < 1.4 && d.distance > 0.01
          ? atan2(d.dy, d.dx)
          : ang[i - 1];
    }
    final hideFrom = scene.arrive > 0
        ? n - (scene.arrive * (n - 1)).floor()
        : n;
    final t = scene.tumble;
    // couplers
    final coupler = Paint()
      ..color = trainInk
      ..strokeWidth = max(2, cs * 0.07);
    for (var i = 1; i < n; i++) {
      final d = pos[i - 1] - pos[i];
      if (d.distance < 1.4 && i < hideFrom) {
        canvas.drawLine(pos[i] * cs, pos[i - 1] * cs, coupler);
      }
    }
    for (var i = n - 1; i >= 1; i--) {
      if (i >= hideFrom) continue;
      var scale = 1.0;
      if (i == n - 1 && scene.coupleT < 1) {
        // a spring: overshoot then settle
        final k = scene.coupleT;
        scale = 1 + sin(k * pi * 2.5) * (1 - k) * 0.28;
      }
      var at = pos[i] * cs;
      var a = ang[i];
      if (t > 0) {
        final sway = sin(t * pi * 4 + i) * (1 - t) * cs * 0.35;
        at += Offset(sway, -sway * 0.5);
        a += sin(t * 9 + i) * 0.5 * (1 - t);
      }
      _wagon(canvas, at, a, cs, g.colors[i], scale: scale);
    }
    var at = pos[0] * cs;
    var a = ang[0];
    if (t > 0) a += sin(t * 7) * 0.4 * (1 - t) + t * 0.3;
    _engine(canvas, at, a, cs);
  }

  void _engine(Canvas canvas, Offset c, double a, double cs) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(a);
    final w = cs * 0.64;
    final l = cs * 0.92;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: l, height: w),
      Radius.circular(cs * 0.16),
    );
    canvas.drawRRect(
      body.shift(Offset(cs * 0.04, cs * 0.06)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    // wheels
    final wheel = Paint()..color = trainInk;
    for (final sx in [-0.28, 0.26]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(l * sx, sy * w * 0.52),
              width: cs * 0.26,
              height: cs * 0.12,
            ),
            Radius.circular(cs * 0.04),
          ),
          wheel,
        );
      }
    }
    canvas.drawRRect(body, Paint()..color = const Color(0xFFE5484D));
    // cab at the back (roof) and a yellow band
    final cab = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -l / 2 + cs * 0.04,
        -w / 2 + cs * 0.06,
        cs * 0.3,
        w - cs * 0.12,
      ),
      Radius.circular(cs * 0.08),
    );
    canvas.drawRRect(cab, Paint()..color = const Color(0xFFB92D32));
    canvas.drawRect(
      Rect.fromLTWH(l * 0.05, -w / 2 + cs * 0.04, cs * 0.1, w - cs * 0.08),
      Paint()..color = trainGold,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cs * 0.06)
        ..color = trainInk,
    );
    // chimney (seen from above) and the round lamp at the front
    canvas.drawCircle(
      Offset(l * 0.18, 0),
      cs * 0.13,
      Paint()..color = trainGold,
    );
    canvas.drawCircle(
      Offset(l * 0.18, 0),
      cs * 0.13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cs * 0.05)
        ..color = trainInk,
    );
    canvas.drawCircle(Offset(l * 0.18, 0), cs * 0.05, wheel);
    canvas.drawCircle(
      Offset(l / 2 - cs * 0.08, 0),
      cs * 0.09,
      Paint()..color = const Color(0xFFFFF3A8),
    );
    canvas.drawCircle(
      Offset(l / 2 - cs * 0.08, 0),
      cs * 0.09,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cs * 0.04)
        ..color = trainInk,
    );
    canvas.restore();
  }

  void _wagon(
    Canvas canvas,
    Offset c,
    double a,
    double cs,
    int colorIdx, {
    double scale = 1,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(a);
    canvas.scale(scale);
    final w = cs * 0.62;
    final l = cs * 0.8;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: l, height: w),
      Radius.circular(cs * 0.12),
    );
    canvas.drawRRect(
      body.shift(Offset(cs * 0.04, cs * 0.06)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    final wheel = Paint()..color = trainInk;
    for (final sx in [-0.26, 0.26]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(l * sx, sy * w * 0.52),
              width: cs * 0.22,
              height: cs * 0.1,
            ),
            Radius.circular(cs * 0.04),
          ),
          wheel,
        );
      }
    }
    canvas.drawRRect(body, Paint()..color = const Color(0xFF8E8AA8));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cs * 0.06)
        ..color = trainInk,
    );
    if (colorIdx <= 3) {
      paintBox(canvas, Offset.zero, cs * 0.92, colorIdx, 0);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: l * 0.62,
            height: w * 0.6,
          ),
          Radius.circular(cs * 0.06),
        ),
        Paint()..color = trainParcelColors[4],
      );
    }
    canvas.restore();
  }

  // ---- effects ----

  void _fx(Canvas canvas, double cs) {
    for (final f in scene.fx) {
      final a = (1 - f.t).clamp(0.0, 1.0);
      final c = Offset(f.x * cs, f.y * cs);
      switch (f.kind) {
        case TrainFxKind.smoke:
          canvas.drawCircle(
            c,
            cs * (f.size + f.t * 0.2),
            Paint()..color = Colors.white.withValues(alpha: 0.7 * a),
          );
        case TrainFxKind.steam:
          canvas.drawCircle(
            c,
            cs * (f.size + f.t * 0.3),
            Paint()..color = Colors.white.withValues(alpha: 0.8 * a),
          );
        case TrainFxKind.confetti:
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(f.t * 12 + f.x);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: cs * f.size,
              height: cs * f.size * 0.5,
            ),
            Paint()..color = f.color,
          );
          canvas.restore();
        case TrainFxKind.spark:
          final p = Paint()
            ..color = f.color.withValues(alpha: a)
            ..strokeWidth = max(2, cs * 0.06)
            ..strokeCap = StrokeCap.round;
          final r = cs * f.size * (0.6 + f.t);
          canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), p);
          canvas.drawLine(c - Offset(0, r), c + Offset(0, r), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrainFieldPainter old) => true;
}

/// A little engine on a rail loop for the menu.
class MenuTrainPainter extends CustomPainter {
  MenuTrainPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = min(size.height * 0.5, size.width / 8);
    final cx = size.width / 2, cy = size.height / 2;
    final rx = size.width * 0.38, ry = size.height * 0.28;
    final rail = Paint()
      ..color = const Color(0xFF6B7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(3, cs * 0.08);
    final sleeper = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..strokeWidth = max(3, cs * 0.12);
    for (var i = 0; i < 36; i++) {
      final a = i / 36 * 2 * pi;
      final p = Offset(cx + cos(a) * rx, cy + sin(a) * ry);
      final n = Offset(cos(a) / rx, sin(a) / ry);
      final nn = n / n.distance;
      canvas.drawLine(p - nn * cs * 0.3, p + nn * cs * 0.3, sleeper);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 2 + cs * 0.22,
        height: ry * 2 + cs * 0.22,
      ),
      rail,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 2 - cs * 0.22,
        height: ry * 2 - cs * 0.22,
      ),
      rail,
    );
    final scene = _MenuTrain(cs);
    for (var i = 4; i >= 0; i--) {
      final a = t * 1.1 - i * 0.3;
      final p = Offset(cx + cos(a) * rx, cy + sin(a) * ry);
      final ang = atan2(cos(a) * ry, -sin(a) * rx);
      scene.draw(canvas, p, ang, i);
    }
  }

  @override
  bool shouldRepaint(covariant MenuTrainPainter old) => old.t != t;
}

class _MenuTrain {
  _MenuTrain(this.cs);
  final double cs;
  void draw(Canvas canvas, Offset p, double ang, int i) {
    // Reuse the field painter's art through a one-cell scene is overkill: draw boxes on small wagons.
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(ang);
    final w = cs * 0.62, l = cs * (i == 0 ? 0.92 : 0.8);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: l, height: w),
      Radius.circular(cs * 0.14),
    );
    canvas.drawRRect(
      body.shift(Offset(cs * 0.04, cs * 0.06)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = i == 0 ? const Color(0xFFE5484D) : const Color(0xFF8E8AA8),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cs * 0.06)
        ..color = trainInk,
    );
    if (i == 0) {
      canvas.drawCircle(
        Offset(l * 0.18, 0),
        cs * 0.13,
        Paint()..color = trainGold,
      );
      canvas.drawCircle(
        Offset(l / 2 - cs * 0.08, 0),
        cs * 0.09,
        Paint()..color = const Color(0xFFFFF3A8),
      );
    } else {
      canvas.restore();
      TrainFieldPainter.paintBox(canvas, p, cs * 0.92, (i - 1) % 4, 0);
      return;
    }
    canvas.restore();
  }
}

/// A bumper icon for the HUD: a round rubber bumper with its number.
class BumperIconPainter extends CustomPainter {
  BumperIconPainter(this.on, this.color);
  final bool on;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = on ? const Color(0xFFFFC83D) : color.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = on ? trainInk : color.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      c,
      r * 0.45,
      Paint()
        ..color = on ? const Color(0xFFE5484D) : color.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant BumperIconPainter old) =>
      old.on != on || old.color != color;
}

/// A parcel icon (colour index 0 to 5) for the HUD and results.
class ParcelIconPainter extends CustomPainter {
  ParcelIconPainter(this.idx, {this.grey = false});
  final int idx;
  final bool grey;
  @override
  void paint(Canvas canvas, Size size) {
    if (grey) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * 0.8,
          height: size.height * 0.8,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, Paint()..color = Colors.grey.withValues(alpha: 0.4));
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.grey,
      );
      return;
    }
    TrainFieldPainter.paintBox(
      canvas,
      size.center(Offset.zero),
      size.shortestSide / 0.62 * 0.8,
      idx,
      0,
    );
  }

  @override
  bool shouldRepaint(covariant ParcelIconPainter old) =>
      old.idx != idx || old.grey != grey;
}
