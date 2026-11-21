import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../door_runner_ids.dart';
import 'door_runner_fx.dart';
import 'door_runner_style.dart';
import 'door_runner_view.dart';

/// Where things sit in the perspective view: a floor that narrows toward the horizon, one lane
/// per door. Pure maths so the painter and the widgets agree (and tests can check it).
class DoorRunnerGeometry {
  DoorRunnerGeometry(this.size, this.lanes)
    : horizon = size.height * (size.width < 500 ? 0.2 : 0.27),
      runnerLine = size.height - (size.width < 500 ? 92 : 104);
  final Size size;
  final int lanes;
  final double horizon;

  /// Where the doors' feet are when they reach the runner.
  final double runnerLine;

  double get cx => size.width / 2;
  double get _h0 => size.width * 0.15;
  double get _hb => size.width / 2;

  /// Half the floor width at depth [s] (0 horizon, 1 runner line, above 1 in front).
  double halfWidth(double s) => _h0 + (_hb - _h0) * s;
  double yAt(double s) => horizon + (runnerLine - horizon) * s;
  double get sMax => (size.height - horizon) / (runnerLine - horizon);
  double laneCenter(int i, double s) =>
      cx - halfWidth(s) + (2 * halfWidth(s) / lanes) * (i + 0.5);

  /// Depth of the doors for an approach of 0 (far) to 1 (at the runner).
  static double depth(double approach) => 0.2 + 0.8 * approach.clamp(0.0, 1.0);
}

/// The scene: sky details, floor, lanes and the doors coming down them, the runner at the
/// bottom, and effects. Draws [view] only. Tapping a door zaps it.
class DoorRunnerField extends StatefulWidget {
  const DoorRunnerField({
    super.key,
    required this.view,
    required this.onZap,
    this.fx,
    this.reduceMotion = false,
    this.interactive = true,
  });
  final DoorRunnerView view;

  /// False in the race: doors are not tappable (two players share one keyboard).
  final bool interactive;
  final void Function(int doorIndex) onZap;
  final DoorRunnerFx? fx;
  final bool reduceMotion;

  @override
  State<DoorRunnerField> createState() => _DoorRunnerFieldState();
}

class _DoorRunnerFieldState extends State<DoorRunnerField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _time = 0;
  double _scroll = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _ticker.start();
  }

  @override
  void didUpdateWidget(DoorRunnerField old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion && _ticker.isActive) _ticker.stop();
    if (!widget.reduceMotion && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration d) {
    final dt = _last == Duration.zero ? 0.0 : (d - _last).inMicroseconds / 1e6;
    _last = d;
    _time += dt;
    final v = widget.view;
    if (!v.paused && !v.answered) _scroll += dt * 0.35 * v.speed;
    widget.fx?.age(dt);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final n = v.doors.length;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final g = DoorRunnerGeometry(size, n);
        final approach = widget.reduceMotion ? 1.0 : v.approach;
        final shake = widget.fx == null || widget.fx!.shake <= 0
            ? Offset.zero
            : Offset(sin(_time * 90) * 5, cos(_time * 70) * 4) *
                  (widget.fx!.shake / 0.25);
        final rs = size.width < 500 ? 72.0 : 84.0;
        return Transform.translate(
          offset: shake,
          child: Stack(
            key: DoorRunnerIds.field,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ScenePainter(
                    g: g,
                    active: v.lane,
                    time: _time,
                    scroll: _scroll,
                    world: v.world,
                  ),
                ),
              ),
              for (var i = 0; i < n; i++)
                Positioned.fromRect(
                  key: DoorRunnerIds.lane(i),
                  rect: Rect.fromLTWH(
                    g.laneCenter(i, 1.0) - size.width / n / 2,
                    0,
                    size.width / n,
                    size.height,
                  ),
                  child: const IgnorePointer(),
                ),
              for (var i = 0; i < n; i++) _doorAt(g, approach, i, v),
              // Trail behind each runner, then the runner. In a race two runners (circle and
              // square marker) share the field and stand side by side when they share a lane.
              for (final r in _runners(v, g, rs)) ..._runner(g, r, rs, n),
              if (widget.fx != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: FxPainter(widget.fx!, g, approach),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_Runner> _runners(DoorRunnerView v, DoorRunnerGeometry g, double rs) {
    if (!v.race) {
      return [
        _Runner(
          g.laneCenter(v.lane, 1.0),
          rs,
          null,
          DrColors.cyan,
          false,
          v.lane,
        ),
      ];
    }
    final size = rs * 0.8;
    final shared = v.lane == v.lane2;
    final off = shared ? size * 0.3 : 0.0;
    return [
      _Runner(
        g.laneCenter(v.lane, 1.0) + off,
        size,
        1,
        const Color(0xFFFFC740),
        v.locked1,
        v.lane,
      ),
      _Runner(
        g.laneCenter(v.lane2!, 1.0) - off,
        size,
        2,
        const Color(0xFF59CC9E),
        v.locked2,
        v.lane2!,
      ),
    ];
  }

  List<Widget> _runner(DoorRunnerGeometry g, _Runner r, double rs, int n) {
    final v = widget.view;
    final dur = widget.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final sz = r.size;
    return [
      for (final (dy, a, t) in [
        (sz * 0.62, 0.28, sz * 0.5),
        (sz * 0.92, 0.14, sz * 0.36),
      ])
        AnimatedPositioned(
          duration: dur,
          left: r.x - t / 2,
          top: g.runnerLine + sz * 0.5 + dy - t / 2,
          width: t,
          height: t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r.tint.withValues(alpha: a),
            ),
          ),
        ),
      AnimatedPositioned(
        duration: dur,
        curve: Curves.easeOut,
        left: r.x - sz / 2,
        top: g.runnerLine + 4,
        width: sz,
        height: sz,
        child: Opacity(
          opacity: r.locked ? 0.4 : 1,
          child: Semantics(
            label: r.player == null
                ? 'Runner in lane ${r.lane + 1} of $n'
                : 'Player ${r.player} in lane ${r.lane + 1} of $n${r.locked ? ', locked out' : ''}',
            child: CustomPaint(
              key: r.player == null
                  ? DoorRunnerIds.runner
                  : (r.player == 1
                        ? DoorRunnerIds.runner1
                        : DoorRunnerIds.runner2),
              painter: RunnerPainter(
                time: _time,
                speed: v.paused || r.locked ? 0 : v.speed,
                tint: r.tint,
                marker: r.player,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _doorAt(
    DoorRunnerGeometry g,
    double approach,
    int i,
    DoorRunnerView v,
  ) {
    final s = DoorRunnerGeometry.depth(approach);
    final laneW = 2 * g.halfWidth(s) / g.lanes;
    final w = min(laneW * 0.86, 160.0);
    final h = w * 260 / 160;
    final x = g.laneCenter(i, s);
    final door = v.doors[i];
    final can =
        widget.interactive &&
        !v.answered &&
        !v.paused &&
        door.mark != DoorMark.wrong;
    return Positioned(
      left: x - w / 2,
      top: g.yAt(s) - h + 2,
      width: w,
      height: h,
      child: DoorWidget(
        key: DoorRunnerIds.door(i),
        door: door,
        index: i,
        enabled: can,
        onZap: () => widget.onZap(i),
      ),
    );
  }
}

/// One door: painted arch and panel with a label plaque and its key number. Drawn at 160 by 260
/// and scaled to fit.
class DoorWidget extends StatelessWidget {
  const DoorWidget({
    super.key,
    required this.door,
    required this.index,
    required this.enabled,
    required this.onZap,
  });
  final DoorView door;
  final int index;
  final bool enabled;
  final VoidCallback onZap;

  @override
  Widget build(BuildContext context) {
    final off = door.mark == DoorMark.wrong;
    final right = door.mark == DoorMark.right;
    final status = off
        ? ', not this door'
        : right
        ? ', the right door'
        : '';
    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: enabled,
      label: 'Door ${index + 1}: ${door.label}$status',
      onTap: enabled ? onZap : null,
      child: FocusableActionDetector(
        enabled: enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onZap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onZap : null,
          child: FittedBox(
            child: SizedBox(
              width: 160,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(80),
                  ),
                  boxShadow: off
                      ? null
                      : drGlow(
                          right ? DrColors.mint : DrColors.lilac,
                          alpha: right ? 0.8 : 0.5,
                          blur: right ? 36 : 28,
                        ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: DoorPainter(door.mark)),
                    ),
                    Positioned(
                      left: 22,
                      top: 100,
                      width: 116,
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: off ? 0.18 : 0.3,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              door.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(
                                  alpha: off ? 0.6 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 212,
                      width: 28,
                      height: 28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (off)
                      const Positioned(
                        right: 14,
                        top: 212,
                        child: Icon(
                          Icons.block,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                    if (right)
                      const Positioned(
                        right: 14,
                        top: 212,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The door art: stone arch, glowing panel, grooves, knob. 160 by 260.
class DoorPainter extends CustomPainter {
  DoorPainter(this.mark);
  final DoorMark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final (frame, panel) = switch (mark) {
      DoorMark.idle => (
        const [Color(0xFF8F78E8), Color(0xFF3A2A80)],
        const [Color(0xFF9A7BFF), Color(0xFF5A3FD0)],
      ),
      DoorMark.wrong => (
        const [Color(0xFF4A4468), Color(0xFF2C2750)],
        const [Color(0xFF3B3560), Color(0xFF2A2548)],
      ),
      DoorMark.right => (
        const [Color(0xFF7DF5C4), Color(0xFF1B7F58)],
        const [Color(0xFF58F0B0), Color(0xFF16A36B)],
      ),
    };
    Path arch(double inset) {
      final r = 76.0 - inset;
      return Path()
        ..moveTo(4 + inset, 256 - inset)
        ..lineTo(4 + inset, 84)
        ..arcToPoint(
          Offset(156 - inset, 84),
          radius: Radius.circular(r),
          clockwise: true,
        )
        ..lineTo(156 - inset, 256 - inset)
        ..close();
    }

    Shader grad(List<Color> c) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: c,
    ).createShader(Offset.zero & size);
    canvas.drawPath(arch(0), Paint()..shader = grad(frame));
    canvas.drawPath(
      arch(0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF231760),
    );
    canvas.drawPath(arch(12), Paint()..shader = grad(panel));
    canvas.drawPath(
      arch(12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    final groove = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(80, 22), const Offset(80, 250), groove);
    canvas.drawLine(const Offset(30, 190), const Offset(130, 190), groove);
    canvas.drawCircle(
      const Offset(132, 170),
      8,
      Paint()..color = DrColors.gold,
    );
    canvas.drawCircle(
      const Offset(132, 170),
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFB8860B),
    );
    canvas.save();
    canvas.translate(60, 40);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 52, height: 20),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DoorPainter old) => old.mark != mark;
}

/// Stars, moon, hills, towers, the perspective floor, lanes, the moving cross lines and the
/// runner line. The sky gradient itself is the frame's backdrop.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.g,
    required this.active,
    required this.time,
    required this.scroll,
    required this.world,
  });
  final DoorRunnerGeometry g;
  final int active;
  final double time;
  final double scroll;
  final int world;

  static final List<(double, double, double)> _stars = () {
    final r = Random(11);
    return [
      for (var i = 0; i < 46; i++)
        (r.nextDouble(), r.nextDouble(), r.nextDouble()),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, hz = g.horizon;
    final star = Paint();
    for (final (x, y, ph) in _stars) {
      final a = 0.3 + 0.6 * (0.5 + 0.5 * sin(time * 0.8 + ph * 6.28));
      star.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x * w, y * (hz - 10)), 0.7 + ph * 1.3, star);
    }
    final moon = Offset(w * 0.8, hz * 0.42);
    canvas.drawCircle(
      moon,
      hz * 0.36,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE9A8).withValues(alpha: 0.5),
            const Color(0x00FFE9A8),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: hz * 0.36)),
    );
    canvas.drawCircle(
      moon,
      min(26, hz * 0.15),
      Paint()..color = const Color(0xFFFFE08A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(g.cx, hz),
        width: w * 1.1,
        height: hz * 0.9,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFB86B).withValues(alpha: 0.7),
                const Color(0x00FFB86B),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(g.cx, hz),
                width: w * 1.1,
                height: hz * 0.9,
              ),
            ),
    );
    // Far hills and castle towers.
    final hills = Path()
      ..moveTo(0, hz)
      ..lineTo(0, hz * 0.84)
      ..cubicTo(w * 0.12, hz * 0.7, w * 0.22, hz * 0.9, w * 0.34, hz * 0.8)
      ..cubicTo(w * 0.46, hz * 0.7, w * 0.6, hz * 0.66, w * 0.72, hz * 0.86)
      ..cubicTo(w * 0.8, hz * 0.95, w * 0.92, hz * 0.72, w, hz * 0.88)
      ..lineTo(w, hz)
      ..close();
    canvas.drawPath(
      hills,
      Paint()..color = const Color(0xFF3A2A8A).withValues(alpha: 0.75),
    );
    for (final (tx, th, tw) in const [
      (0.14, 0.30, 0.05),
      (0.2, 0.22, 0.04),
      (0.62, 0.34, 0.055),
      (0.68, 0.24, 0.04),
      (0.4, 0.18, 0.035),
    ]) {
      final x = w * tx, tww = w * tw, h = hz * th * 1.6, c = hz * 0.04;
      canvas.drawPath(
        Path()
          ..moveTo(x, hz)
          ..lineTo(x, hz - h)
          ..relativeLineTo(tww * 0.25, 0)
          ..relativeLineTo(0, -c)
          ..relativeLineTo(tww * 0.2, 0)
          ..relativeLineTo(0, c)
          ..relativeLineTo(tww * 0.2, 0)
          ..relativeLineTo(0, -c)
          ..relativeLineTo(tww * 0.2, 0)
          ..relativeLineTo(0, c)
          ..relativeLineTo(tww * 0.15, 0)
          ..lineTo(x + tww, hz)
          ..close(),
        Paint()..color = const Color(0xFF2A1B6B),
      );
    }
    // Floor.
    final sm = g.sMax;
    final floor = Path()
      ..moveTo(g.cx - g.halfWidth(0), hz)
      ..lineTo(g.cx + g.halfWidth(0), hz)
      ..lineTo(g.cx + g.halfWidth(sm), size.height)
      ..lineTo(g.cx - g.halfWidth(sm), size.height)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1F7A), Color(0xFF120A38)],
        ).createShader(Offset.zero & size),
    );
    double lt(int k) =>
        g.cx - g.halfWidth(0) + (2 * g.halfWidth(0) / g.lanes) * k;
    double lb(int k) =>
        g.cx - g.halfWidth(sm) + (2 * g.halfWidth(sm) / g.lanes) * k;
    canvas.drawPath(
      Path()
        ..moveTo(lt(active), hz)
        ..lineTo(lt(active + 1), hz)
        ..lineTo(lb(active + 1), size.height)
        ..lineTo(lb(active), size.height)
        ..close(),
      Paint()..color = DrColors.cyan.withValues(alpha: 0.13),
    );
    // Cross lines scroll toward the runner (speed feel).
    for (var k = 0; k < 8; k++) {
      final p = ((k / 8) + scroll) % 1.0;
      final s = p * p * 1.12;
      final y = g.yAt(s);
      if (y > size.height || s < 0.02) continue;
      canvas.drawLine(
        Offset(g.cx - g.halfWidth(s), y),
        Offset(g.cx + g.halfWidth(s), y),
        Paint()
          ..color = DrColors.lilac.withValues(alpha: 0.1 + 0.2 * s.clamp(0, 1))
          ..strokeWidth = 1 + 2 * s,
      );
    }
    final lane = Paint()
      ..strokeWidth = 3
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          DrColors.lilac.withValues(alpha: 0.2),
          DrColors.lilac.withValues(alpha: 0.75),
        ],
      ).createShader(Offset.zero & size);
    for (var k = 0; k <= g.lanes; k++) {
      canvas.drawLine(Offset(lt(k), hz), Offset(lb(k), size.height), lane);
    }
    // Runner line, dashed and cyan.
    final dash = Paint()
      ..color = DrColors.cyan.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    final x0 = g.cx - g.halfWidth(1), x1 = g.cx + g.halfWidth(1);
    for (var x = x0; x < x1; x += 24) {
      canvas.drawLine(
        Offset(x, g.runnerLine),
        Offset(min(x + 14, x1), g.runnerLine),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) => true;
}

/// A round friendly critter (no person): halo, feet that bob, body, eyes, cheeks, smile.
class RunnerPainter extends CustomPainter {
  RunnerPainter({
    required this.time,
    required this.speed,
    this.tint = DrColors.cyan,
    this.marker,
  });
  final double time;
  final double speed;

  /// The glow colour (a race gives each player their own).
  final Color tint;

  /// Race: 1 draws a circle badge over the runner, 2 a square one (colour is never the only cue).
  final int? marker;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    canvas.scale(k);
    const c = Offset(48, 48);
    canvas.drawCircle(
      c,
      46,
      Paint()
        ..shader = RadialGradient(
          colors: [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: 46)),
    );
    final stride = sin(time * 14 * speed) * 3 * (speed > 0 ? 1 : 0);
    final foot = Paint()..color = DrColors.gold;
    final footLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFB8860B);
    for (final (x, dy) in [(36.0, stride), (60.0, -stride)]) {
      final r = Rect.fromCenter(
        center: Offset(x, 80 + dy),
        width: 18,
        height: 10,
      );
      canvas.drawOval(r, foot);
      canvas.drawOval(r, footLine);
    }
    final bob = speed > 0 ? sin(time * 14 * speed).abs() * -2 : 0.0;
    final body = Offset(48, 46 + bob);
    canvas.drawCircle(
      body,
      28,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9BF7FF), Color(0xFF3F8BFF)],
        ).createShader(Rect.fromCircle(center: body, radius: 28)),
    );
    canvas.drawCircle(
      body,
      28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF1B3E9C),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: body + const Offset(-10, -14),
        width: 18,
        height: 10,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    for (final dx in [-10.0, 10.0]) {
      canvas.drawCircle(
        body + Offset(dx, 0),
        7.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        body + Offset(dx + 1, -2),
        3.6,
        Paint()..color = DrColors.ink,
      );
    }
    for (final dx in [-18.0, 18.0]) {
      canvas.drawCircle(
        body + Offset(dx, 10),
        4,
        Paint()..color = const Color(0xFFFF7BAC).withValues(alpha: 0.6),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(body.dx - 6, body.dy + 12)
        ..quadraticBezierTo(body.dx, body.dy + 17, body.dx + 6, body.dy + 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1B3E9C),
    );
    if (marker != null) {
      final badge = Paint()..color = tint;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white;
      const at = Offset(48, 8);
      if (marker == 1) {
        canvas.drawCircle(at, 8, badge);
        canvas.drawCircle(at, 8, ring);
      } else {
        final r = Rect.fromCenter(center: at, width: 15, height: 15);
        canvas.drawRect(r, badge);
        canvas.drawRect(r, ring);
      }
    }
  }

  @override
  bool shouldRepaint(RunnerPainter old) =>
      old.time != time ||
      old.speed != speed ||
      old.tint != tint ||
      old.marker != marker;
}

/// Floating "+N" and sparkle bursts over the doors.
class FxPainter extends CustomPainter {
  FxPainter(this.fx, this.g, this.approach) : super(repaint: fx);
  final DoorRunnerFx fx;
  final DoorRunnerGeometry g;
  final double approach;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in fx.bursts) {
      final t = b.age / FxBurst.life;
      final c = Offset(g.laneCenter(b.lane, 1.0), g.runnerLine - 40);
      final p = Paint()..color = b.color.withValues(alpha: (1 - t).clamp(0, 1));
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + 0.3;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * (14 + 60 * t),
          4 * (1 - t) + 1,
          p,
        );
      }
    }
    for (final t in fx.texts) {
      final c = Offset(
        g.laneCenter(t.lane, 1.0),
        g.runnerLine - 30 - 50 * t.age,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color.withValues(
              alpha: (1 - t.age / FxText.life).clamp(0, 1),
            ),
            fontSize: 30,
            fontWeight: FontWeight.w800,
            shadows: drTextShadow,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(FxPainter old) => true;
}

/// Where a runner stands and how it looks (private to the field).
class _Runner {
  const _Runner(
    this.x,
    this.size,
    this.player,
    this.tint,
    this.locked,
    this.lane,
  );
  final double x;
  final double size;
  final int? player;
  final Color tint;
  final bool locked;
  final int lane;
}
