import 'dart:math';
import 'dart:ui';

import '../../core/skins/flyer_skins.dart';
import '../rules/spire.dart';
import '../rules/wingy_run.dart';
import '../rules/world.dart';

/// Floating "+1/+2" text that rises and fades.
class FloatingText {
  FloatingText(this.text, this.x, this.y, this.color);
  final String text;
  final double x;
  double y;
  final Color color;
  double age = 0;
  static const double life = 0.8;
}

/// Six-piece shard burst for a shattered spire pair (scale-fade tween, no particles).
class ShardBurst {
  ShardBurst(this.x, this.y);
  final double x;
  final double y;
  double age = 0;
  static const double life = 0.45;
}

/// Draws the whole scene with Canvas (no image assets). Uses only `dart:ui`, takes the run as
/// input and holds only cosmetic state.
class WingyPainter {
  WingyPainter() {
    final r = Random(7);
    for (var i = 0; i < 46; i++) {
      stars.add((r.nextDouble() * 360, r.nextDouble() * 380, r.nextDouble()));
    }
  }

  final List<(double, double, double)> stars = [];
  final List<FloatingText> texts = [];
  final List<ShardBurst> bursts = [];

  bool reduceMotion = false;

  /// Cosmetic flyer look; the hitbox and physics never read it.
  FlyerSkin skin = FlyerSkins.moth;
  double time = 0;
  double scrollX = 0;
  double sinceFlap = 1;
  double shake = 0;

  static const _palettes = <Palette, List<Color>>{
    Palette.dusk: [Color(0xFF1B1446), Color(0xFF2B4FB0), Color(0xFF2FA8C9)],
    Palette.aurora: [Color(0xFF0B2B3B), Color(0xFF1C6A6E), Color(0xFF3FBF9A)],
    Palette.midnight: [Color(0xFF05071A), Color(0xFF111A4A), Color(0xFF2B1B63)],
    Palette.sunrise: [Color(0xFF3B1740), Color(0xFFB5517A), Color(0xFFF2A65A)],
    Palette.emerald: [Color(0xFF06261F), Color(0xFF0F6B4F), Color(0xFF52D6A0)],
    Palette.ember: [Color(0xFF2A0E12), Color(0xFF8A2B26), Color(0xFFF08A3C)],
  };

  /// Top, middle and bottom colours of the background gradient of [p].
  static List<Color> paletteColors(Palette p) => _palettes[p]!;

  /// Cross-fade of the background gradient between palettes.
  final PaletteFade fade = PaletteFade(Palette.dusk);
  bool _fadeReady = false;

  /// Forget the fade (new run): the next update snaps to the run's palette.
  void resetFade() => _fadeReady = false;

  /// Gradient colours currently shown (mid-fade blend).
  List<Color> get gradientColors {
    final a = _palettes[fade.from]!;
    final b = _palettes[fade.to]!;
    return [for (var i = 0; i < 3; i++) Color.lerp(a[i], b[i], fade.progress)!];
  }

  void update(double dt, WingyRun run, List<RunEvent> events) {
    if (!_fadeReady) {
      fade.snapTo(run.palette);
      _fadeReady = true;
    } else {
      fade.setTarget(run.palette, reduceMotion: reduceMotion);
      fade.update(dt);
    }
    time += dt;
    sinceFlap += dt;
    if (shake > 0) shake = max(0, shake - dt);
    if (!reduceMotion && run.phase == RunPhase.playing && !run.paused) {
      final mult = run.isDashing ? WingyWorld.dashSpeedFactor : 1.0;
      scrollX += run.scrollSpeed * mult * dt;
    }
    for (final e in events) {
      switch (e.type) {
        case RunEventType.flap:
          sinceFlap = 0;
        case RunEventType.pass:
          texts.add(FloatingText('+${e.points}', 100, e.y - 30, _white));
        case RunEventType.perfect:
          texts.add(
            FloatingText(
              '+${e.points}',
              100,
              e.y - 30,
              const Color(0xFFFFE066),
            ),
          );
        case RunEventType.orb:
          texts.add(FloatingText('+1', e.x, e.y - 18, const Color(0xFF7CF5FF)));
        case RunEventType.shatter:
          texts.add(
            FloatingText(
              '+${e.points}',
              100,
              e.y - 30,
              const Color(0xFFFFB347),
            ),
          );
          bursts.add(ShardBurst(e.x, e.y));
        case RunEventType.hit:
          if (!reduceMotion) shake = 0.25;
        default:
          break;
      }
    }
    for (final t in texts) {
      t.age += dt;
      t.y -= 40 * dt;
    }
    texts.removeWhere((t) => t.age >= FloatingText.life);
    for (final b in bursts) {
      b.age += dt;
    }
    bursts.removeWhere((b) => b.age >= ShardBurst.life);
  }

  static const _white = Color(0xFFFFFFFF);

  void paint(Canvas canvas, Size size, WingyRun run) {
    final s = min(
      size.width / WingyWorld.width,
      size.height / WingyWorld.height,
    );
    final ox = (size.width - WingyWorld.width * s) / 2;
    final oy = (size.height - WingyWorld.height * s) / 2;
    _background(canvas, size);
    canvas.save();
    var sx = 0.0;
    var sy = 0.0;
    if (shake > 0) {
      sx = sin(time * 90) * 5 * (shake / 0.25);
      sy = cos(time * 70) * 4 * (shake / 0.25);
    }
    canvas.translate(ox + sx * s, oy + sy * s);
    canvas.scale(s);
    _parallax(canvas, size, s, ox, oy);
    for (final p in run.pairs) {
      _spires(canvas, p);
    }
    for (final p in run.pairs) {
      if (p.hasOrb && !p.orbCollected) _orb(canvas, p.x, p.centerY);
    }
    _ground(canvas);
    for (final b in bursts) {
      _burst(canvas, b);
    }
    _moth(canvas, run);
    for (final t in texts) {
      _text(canvas, t);
    }
    canvas.restore();
  }

  void _background(Canvas canvas, Size size) {
    final c = gradientColors;
    final paint = Paint()
      ..shader = Gradient.linear(Offset.zero, Offset(0, size.height), c, const [
        0,
        0.55,
        1,
      ]);
    canvas.drawRect(Offset.zero & size, paint);
    final star = Paint();
    // Stars are drawn in screen space so they also fill letterboxed areas.
    for (final (x, y, ph) in stars) {
      final a = 0.25 + 0.55 * (0.5 + 0.5 * sin(time * 0.8 + ph * 6.28));
      star.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawCircle(
        Offset(x / 360 * size.width, y / 640 * size.height),
        0.8 + ph * 1.1,
        star,
      );
    }
  }

  void _parallax(Canvas canvas, Size size, double s, double ox, double oy) {
    // Far ridge, mid mist band, near floating rocks (positions loop with scrollX).
    final far = Paint()..color = const Color(0x553A2373);
    final ridge = Path()..moveTo(-60, 584);
    final fo = scrollX * 0.08;
    for (double x = -60; x <= 440; x += 20) {
      ridge.lineTo(x, 500 - 40 * sin((x + fo) / 55) - 22 * sin((x + fo) / 23));
    }
    ridge
      ..lineTo(440, 584)
      ..close();
    canvas.drawPath(ridge, far);
    final mist = Paint()
      ..shader = Gradient.linear(const Offset(0, 430), const Offset(0, 540), [
        const Color(0x00B79CFF),
        const Color(0x30B79CFF),
      ]);
    canvas.drawRect(const Rect.fromLTWH(-60, 430, 520, 120), mist);
    final rock = Paint()..color = const Color(0x66231552);
    final no = scrollX * 0.3;
    for (var i = 0; i < 5; i++) {
      final x = ((i * 130 - no) % 650) - 120;
      final y = 90.0 + (i * 53 % 160) + 6 * sin(time * 0.7 + i);
      final w = 26.0 + (i * 17 % 20);
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + w, y + 4)
        ..lineTo(x + w * 0.7, y + w * 0.7)
        ..lineTo(x + w * 0.3, y + w * 0.9)
        ..close();
      canvas.drawPath(path, rock);
    }
  }

  void _ground(Canvas canvas) {
    final g = Paint()
      ..shader = Gradient.linear(const Offset(0, 584), const Offset(0, 640), [
        const Color(0xFF1B2B2A),
        const Color(0xFF0B1413),
      ]);
    canvas.drawRect(const Rect.fromLTWH(-80, 584, 520, 60), g);
    canvas.drawRect(
      const Rect.fromLTWH(-80, 584, 520, 3),
      Paint()..color = const Color(0xFF3FA37A),
    );
    final glow = Paint();
    final off = scrollX * 0.6;
    for (var i = 0; i < 9; i++) {
      final x = ((i * 61 - off) % 540) - 90;
      final y = 600.0 + (i * 7 % 22);
      final a = 0.5 + 0.5 * sin(time * 1.5 + i);
      glow.color = Color.fromRGBO(120, 255, 200, 0.35 + 0.4 * a);
      canvas.drawCircle(Offset(x, y), 2.4, glow);
      glow.color = Color.fromRGBO(120, 255, 200, 0.08 * a);
      canvas.drawCircle(Offset(x, y), 7, glow);
    }
  }

  void _spires(Canvas canvas, SpirePair p) {
    if (p.shattered && p.passed) return;
    final alpha = p.shattered ? 0.3 : 1.0;
    final top = p.gapTop;
    final bottom = p.gapBottom;
    _spire(canvas, p.left, p.right, 0, top, true, alpha, p.drifting);
    _spire(
      canvas,
      p.left,
      p.right,
      bottom,
      WingyWorld.groundY,
      false,
      alpha,
      p.drifting,
    );
  }

  /// One spire column, for scenes outside a run (home screen).
  void drawSpire(
    Canvas canvas,
    double l,
    double r,
    double y0,
    double y1, {
    required bool hangs,
    double alpha = 1,
  }) => _spire(canvas, l, r, y0, y1, hangs, alpha, false);

  /// One glow orb, for scenes outside a run (home screen).
  void drawOrb(Canvas canvas, double x, double y) => _orb(canvas, x, y);

  void _spire(
    Canvas canvas,
    double l,
    double r,
    double y0,
    double y1,
    bool hangs,
    double alpha,
    bool shimmer,
  ) {
    if (y1 - y0 < 2) return;
    final rect = Rect.fromLTRB(l, y0, r, y1);
    final body = Paint()
      ..shader = Gradient.linear(Offset(l, y0), Offset(r, y1), [
        Color.fromRGBO(70, 220, 240, 0.55 * alpha),
        Color.fromRGBO(200, 80, 220, 0.55 * alpha),
      ]);
    canvas.drawRect(rect, body);
    // One stylised facet highlight.
    final facet = Path()
      ..moveTo(l + 8, y0)
      ..lineTo(l + 20, y0)
      ..lineTo(l + 12, y1)
      ..lineTo(l + 4, y1)
      ..close();
    canvas.drawPath(
      facet,
      Paint()..color = Color.fromRGBO(255, 255, 255, 0.14 * alpha),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.fromRGBO(220, 240, 255, 0.5 * alpha),
    );
    // Flat glowing tip at the gap side.
    final tipY = hangs ? y1 - 5 : y0;
    final pulse = shimmer ? 0.55 + 0.45 * sin(time * 8) : 0.7;
    canvas.drawRect(
      Rect.fromLTWH(l, tipY, r - l, 5),
      Paint()..color = Color.fromRGBO(255, 255, 255, pulse * alpha),
    );
    canvas.drawRect(
      Rect.fromLTWH(l - 3, tipY - (hangs ? 3 : 0), r - l + 6, 11),
      Paint()
        ..color = Color.fromRGBO(160, 255, 255, 0.18 * pulse * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _orb(Canvas canvas, double x, double y) {
    final pulse = 1 + 0.12 * sin(time * 5 + x * 0.05);
    final r = WingyWorld.orbRadius * pulse;
    canvas.drawCircle(
      Offset(x, y),
      r * 2.4,
      Paint()
        ..shader = Gradient.radial(Offset(x, y), r * 2.4, [
          const Color(0x667CF5FF),
          const Color(0x007CF5FF),
        ]),
    );
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()..color = const Color(0xFFE8FDFF),
    );
    canvas.drawCircle(
      Offset(x, y),
      r * 0.6,
      Paint()..color = const Color(0xFF7CF5FF),
    );
  }

  void _burst(Canvas canvas, ShardBurst b) {
    final t = b.age / ShardBurst.life;
    final paint = Paint()
      ..color = Color.fromRGBO(255, 150, 240, (1 - t).clamp(0, 1).toDouble());
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + 0.4;
      final d = 14 + 60 * t;
      final cx = b.x + cos(a) * d;
      final cy = b.y + sin(a) * d;
      final sc = (1 - t) * 9 + 1;
      final path = Path()
        ..moveTo(cx, cy - sc)
        ..lineTo(cx + sc * 0.8, cy + sc * 0.6)
        ..lineTo(cx - sc * 0.8, cy + sc * 0.6)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _moth(Canvas canvas, WingyRun run) {
    if (run.isInvulnerable && ((time * 14).floor() % 2 == 0)) return;
    final tilt = (run.vy / WingyWorld.terminalVelocity * 0.9).clamp(-0.5, 0.9);
    // Wing frame: 0 up, 1 mid, 2 down.
    final frame = sinceFlap < 0.07
        ? 0
        : sinceFlap < 0.14
        ? 1
        : (run.vy > 100 ? 2 : 1);
    drawMoth(
      canvas,
      WingyWorld.heroX,
      run.y,
      tilt: run.isDashing ? 0 : tilt.toDouble(),
      frame: frame,
      dashing: run.isDashing,
      grace: run.isGrace,
      ending: run.dashEnding,
    );
  }

  /// The moth at ([x], [y]); [frame] is the wing frame (0 up, 1 mid, 2 down).
  void drawMoth(
    Canvas canvas,
    double x,
    double y, {
    double tilt = 0,
    int frame = 1,
    bool dashing = false,
    bool grace = false,
    bool ending = false,
  }) {
    final sk = skin;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(tilt);
    if (ending) {
      // End-of-dash cue: pulsing scale and a brighter glow for the last 0.3 s.
      final pulse = 0.5 + 0.5 * sin(time * 40);
      canvas.scale(1 + 0.18 * pulse);
      canvas.drawCircle(
        Offset.zero,
        44,
        Paint()
          ..shader = Gradient.radial(Offset.zero, 44, [
            Color.fromARGB((90 + 120 * pulse).round(), 255, 255, 255),
            const Color(0x00FFFFFF),
          ]),
      );
    }
    if (dashing || grace) {
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()
          ..shader = Gradient.radial(Offset.zero, 34, [
            Color(0x99000000 | (sk.trail & 0xFFFFFF)),
            Color(sk.trail & 0xFFFFFF),
          ]),
      );
    }
    final lift = const [-18.0, -6.0, 12.0][frame];
    final wing = Paint()..color = Color(sk.wing);
    final wingEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Color(sk.wingEdge);
    final k = sk.wingLength / 22; // 1.0 for the moth
    for (final side in const [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(-2, 0)
        ..quadraticBezierTo(
          (-16 + side * 2) * k,
          lift - 4,
          -22 * k,
          lift * 0.8 + 2 * side,
        )
        ..quadraticBezierTo(-14 * k, 8 + lift * 0.2, -2, 3)
        ..close();
      // Two wings (near and far) drawn with a slight offset.
      canvas.save();
      canvas.translate(side > 0 ? 0 : 2, side > 0 ? 0 : -2);
      canvas.drawPath(path, wing);
      canvas.drawPath(path, wingEdge);
      if (sk.hindWing) {
        final hind = Path()
          ..moveTo(-2, 2)
          ..quadraticBezierTo(-12 * k, 6 + lift * 0.4, -15 * k, 12 + lift * 0.3)
          ..quadraticBezierTo(-6 * k, 12, -2, 5)
          ..close();
        canvas.drawPath(hind, wing);
        canvas.drawPath(hind, wingEdge);
      }
      canvas.restore();
    }
    // Body and glowing abdomen.
    canvas.drawOval(
      const Rect.fromLTWH(-9, -8, 20, 16),
      Paint()..color = Color(sk.body),
    );
    if (sk.antennae) {
      final ant = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color(sk.body);
      canvas.drawLine(const Offset(8, -6), const Offset(14, -13), ant);
      canvas.drawLine(const Offset(9, -4), const Offset(16, -9), ant);
    }
    canvas.drawCircle(
      const Offset(-8, 2),
      7,
      Paint()
        ..color = Color(sk.glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    if (sk.sparkle) {
      // Four-point star in place of the round glow core.
      final star = Path();
      const c = Offset(-8, 2);
      for (var i = 0; i < 8; i++) {
        final r = i.isEven ? 8.0 : 3.0;
        final a = i * pi / 4 + time * 2;
        final p = c + Offset(cos(a) * r, sin(a) * r);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..color = Color(sk.glowCore));
    } else {
      canvas.drawCircle(
        const Offset(-8, 2),
        4.5,
        Paint()..color = Color(sk.glowCore),
      );
    }
    canvas.drawCircle(const Offset(6, -2), 2.2, Paint()..color = _white);
    canvas.drawCircle(
      const Offset(6.6, -2),
      1.1,
      Paint()..color = const Color(0xFF1B1446),
    );
    canvas.restore();
  }

  void _text(Canvas canvas, FloatingText t) {
    final a = (1 - t.age / FloatingText.life).clamp(0, 1).toDouble();
    final builder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(
            TextStyle(
              color: t.color.withValues(alpha: a),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          )
          ..addText(t.text);
    final p = builder.build()..layout(const ParagraphConstraints(width: 80));
    canvas.drawParagraph(p, Offset(t.x - 40, t.y));
  }
}
