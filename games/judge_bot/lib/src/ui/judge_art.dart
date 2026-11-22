import 'dart:math';

import 'package:flutter/material.dart';

/// Code art of Judge bot (a toy judge robot behind a desk; no person, no animal). Thick ink
/// outline, flat bright colours, as Bridge builder.
const Color judgeInk = Color(0xFF2B2A4C);

/// TRUE lamp: white text on it is at least 4.5:1 (checked in the tests); the icon doubles the cue.
const Color judgeTrueGreen = Color(0xFF1E7B46);

/// FALSE lamp: white text on it is at least 4.5:1.
const Color judgeFalseRed = Color(0xFFC62F2F);

/// Time up.
const Color judgeAmber = Color(0xFFF2A93B);

/// The ticket: cream with dark ink text (at least 7:1).
const Color judgeTicket = Color(0xFFFFF6DC);

enum RobotMood { wait, think, happy, oops, buzz }

String robotLabel(RobotMood m) => switch (m) {
  RobotMood.wait => 'Judge bot, waiting',
  RobotMood.think => 'Judge bot, thinking',
  RobotMood.happy => 'Judge bot, happy',
  RobotMood.oops => 'Judge bot, shrugging',
  RobotMood.buzz => 'Judge bot, buzzing, time is up',
};

/// The robot on a 200 x 200 canvas that is scaled to fit.
class JudgeRobotPainter extends CustomPainter {
  JudgeRobotPainter({
    this.mood = RobotMood.wait,
    this.eyeLeft,
    this.lit = 0,
    this.gold = false,
    this.lamp,
    this.gavel = 0,
    this.cheer = 0,
    this.confetti = false,
    this.spin = 0,
  });

  final RobotMood mood;

  /// 0..1 of the timer left (a ring round the eye), null without a timer.
  final double? eyeLeft;

  /// Streak bulbs lit (0..5) and whether they are the gold row.
  final int lit;
  final bool gold;

  /// The lit shoulder lamp (green, red or amber), null when both are dark.
  final Color? lamp;

  /// Gavel tap, 0..1..0 over the beat (0 rests).
  final double gavel;

  /// Celebration 0..1 (nod and confetti); [spin] 0..1 turns the head once.
  final double cheer;
  final bool confetti;
  final double spin;

  Paint _fill(Color c) => Paint()..color = c;
  Paint get _line => Paint()
    ..color = judgeInk
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _box(Canvas c, Rect r, double rad, Color fill) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
    c.drawRRect(rr.shift(const Offset(0, 3)), _fill(const Color(0x33000000)));
    c.drawRRect(rr, _fill(fill));
    c.drawRRect(rr, _line);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 200;
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);
    final bob = mood == RobotMood.happy && cheer > 0
        ? -5 * sin(cheer * pi * 3).abs()
        : 0.0;
    // body and shoulder lamps
    _box(
      canvas,
      const Rect.fromLTWH(48, 82, 104, 78),
      14,
      const Color(0xFF6C7BD8),
    );
    _box(
      canvas,
      const Rect.fromLTWH(72, 112, 56, 12),
      4,
      const Color(0xFF1D1C36),
    );
    for (final x in [38.0, 162.0]) {
      canvas.drawCircle(
        Offset(x, 92),
        11,
        _fill(lamp ?? const Color(0xFFB9BEE0)),
      );
      canvas.drawCircle(Offset(x, 92), 11, _line);
      if (lamp != null) {
        canvas.drawCircle(
          Offset(x, 92),
          17,
          Paint()..color = lamp!.withValues(alpha: 0.35),
        );
      }
    }
    // gavel arm on the right
    final ang = -0.9 + gavel * 1.1;
    canvas.save();
    canvas.translate(152, 110);
    canvas.rotate(ang);
    canvas.drawLine(Offset.zero, const Offset(0, -34), _line..strokeWidth = 5);
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -48, 24, 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(head, _fill(const Color(0xFFB9783F)));
    canvas.drawRRect(head, _line);
    canvas.restore();
    // head (turns once on a long streak)
    canvas.save();
    canvas.translate(100, 52 + bob);
    canvas.rotate(spin * 2 * pi);
    canvas.translate(-100, -52);
    // antenna and streak bulbs on the hat
    canvas.drawLine(const Offset(100, 24), const Offset(100, 12), _line);
    for (var i = 0; i < 5; i++) {
      final on = i < lit;
      final c = Offset(66.0 + i * 17, 16);
      canvas.drawCircle(
        c,
        6.5,
        _fill(
          on
              ? (gold ? const Color(0xFFFFC21A) : judgeAmber)
              : const Color(0xFFD9DCF3),
        ),
      );
      canvas.drawCircle(c, 6.5, _line..strokeWidth = 2.5);
    }
    _box(
      canvas,
      const Rect.fromLTWH(58, 26, 84, 56),
      16,
      const Color(0xFF8FA0F0),
    );
    // eye with the timer ring
    const eye = Offset(100, 52);
    canvas.drawCircle(eye, 17, _fill(Colors.white));
    canvas.drawCircle(eye, 17, _line..strokeWidth = 3.5);
    canvas.drawCircle(
      eye.translate(mood == RobotMood.think ? 3 : 0, 0),
      7,
      _fill(judgeInk),
    );
    if (eyeLeft != null) {
      final ring = Paint()
        ..color = mood == RobotMood.buzz ? judgeAmber : const Color(0xFFFFD166)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: eye, radius: 23),
        -pi / 2,
        2 * pi * eyeLeft!.clamp(0.0, 1.0),
        false,
        ring,
      );
    }
    // mouth
    final mouth = _line..strokeWidth = 3.5;
    switch (mood) {
      case RobotMood.happy:
        canvas.drawArc(
          const Rect.fromLTWH(86, 66, 28, 12),
          0.2,
          pi - 0.4,
          false,
          mouth,
        );
      case RobotMood.oops:
        canvas.drawArc(
          const Rect.fromLTWH(88, 72, 24, 10),
          pi + 0.3,
          pi - 0.6,
          false,
          mouth,
        );
      case RobotMood.buzz:
        final p = Path()..moveTo(86, 74);
        for (var i = 1; i <= 4; i++) {
          p.lineTo(86 + i * 7.0, i.isOdd ? 70 : 76);
        }
        canvas.drawPath(p, mouth);
      default:
        canvas.drawLine(const Offset(90, 73), const Offset(110, 73), mouth);
    }
    canvas.restore();
    // desk
    _box(
      canvas,
      const Rect.fromLTWH(10, 150, 180, 40),
      10,
      const Color(0xFF9C6A43),
    );
    // confetti pop
    if (confetti && cheer > 0 && cheer < 1 && mood == RobotMood.happy) {
      const colors = [
        Color(0xFFFFC21A),
        Color(0xFFE63946),
        Color(0xFF2EC4B6),
        Color(0xFF6C7BD8),
      ];
      for (var i = 0; i < 12; i++) {
        final a = i / 12 * 2 * pi;
        final d = 30 + 70 * cheer;
        canvas.drawCircle(
          Offset(100 + cos(a) * d, 60 + sin(a) * d * 0.8),
          3.5 * (1 - cheer * 0.5),
          _fill(colors[i % 4]),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(JudgeRobotPainter o) =>
      o.mood != mood ||
      o.eyeLeft != eyeLeft ||
      o.lit != lit ||
      o.gold != gold ||
      o.lamp != lamp ||
      o.gavel != gavel ||
      o.cheer != cheer ||
      o.confetti != confetti ||
      o.spin != spin;
}
