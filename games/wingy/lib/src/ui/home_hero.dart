import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../host/profile_store.dart';
import '../host/services.dart';
import '../core/skins/flyer_skins.dart';
import '../game/flame/wingy_painter.dart';
import '../game/rules/world.dart';
import 'test_ids.dart';

/// Animated scene above the title: the moth flies left to right while crystal spires and glow
/// orbs scroll right to left in three parallax layers, with a Glow Dash trail now and then.
/// Drawn in code with the game's own [WingyPainter]; decorative only (no gestures).
///
/// One ticker drives one painter. It stops while the home route is covered or the app is in the
/// background, and with Reduce motion on it shows one still frame.
class HomeHero extends StatefulWidget {
  const HomeHero({super.key, this.height = maxHeight});

  /// Height of the band when there is room, and the least it shrinks to, in dp.
  static const double maxHeight = 160;
  static const double minHeight = 96;

  /// Height of the band in dp (the scene is scaled to fit).
  final double height;

  @override
  State<HomeHero> createState() => HomeHeroState();
}

class HomeHeroState extends State<HomeHero>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _time = ValueNotifier(_stillTime);
  final WingyPainter _painter = WingyPainter();
  late final _HeroPainter _heroPainter = _HeroPainter(_painter, _time);
  Duration _last = Duration.zero;
  bool _covered = false;
  bool _background = false;
  bool _reduceMotion = false;

  /// Frame shown with Reduce motion on: the moth mid-scene, spires and orbs spread out.
  static const double _stillTime = 6;

  /// True while the ticker is animating the scene.
  bool get running => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profile?.removeListener(_onProfile);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    final profile = WingyServicesScope.of(context).profile;
    if (!identical(profile, _profile)) {
      _profile?.removeListener(_onProfile);
      _profile = profile..addListener(_onProfile);
    }
    _reduceMotion = profile.data.reduceMotion;
    _painter.skin = FlyerSkins.of(profile.data.equippedSkin);
    _sync();
  }

  WingyProfileStore? _profile;

  void _onProfile() {
    _reduceMotion = _profile!.data.reduceMotion;
    _painter.skin = FlyerSkins.of(_profile!.data.equippedSkin);
    _sync();
  }

  void _sync() {
    final shouldRun = !_covered && !_background && !_reduceMotion;
    if (_reduceMotion) {
      // Nudge so the still frame repaints after a skin change.
      _time.value = _time.value == _stillTime ? _stillTime + 1e-6 : _stillTime;
    }
    if (shouldRun && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _time.value += min(dt, 0.1);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: TestIds.homeHero,
    height: widget.height,
    width: double.infinity,
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: _heroPainter, size: Size.infinite),
        ),
      ),
    ),
  );
}

/// Scene in a 360 x 160 logical box, scaled to fit. At most 12 moving objects: the moth, the
/// dash trail, 6 spires and 3 orbs spread over three layers.
class _HeroPainter extends CustomPainter {
  _HeroPainter(this.painter, this.time) : super(repaint: time);

  final WingyPainter painter;
  final ValueNotifier<double> time;

  static const double _w = 360;
  static const double _h = 160;

  // (speed u/s, scale, alpha, spire x offsets, orb x offset or null)
  static const _layers = <(double, double, double, List<double>, double?)>[
    (14, 0.5, 0.35, [40, 230], null),
    (30, 0.7, 0.6, [120, 300], 200),
    (56, 0.9, 0.9, [10, 190], 90),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    painter.time = t;
    final s = min(size.width / _w, size.height / _h);
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - _w * s) / 2, (size.height - _h * s) / 2);
    canvas.scale(s);

    const span = _w + 120;
    for (var li = 0; li < _layers.length; li++) {
      final (speed, sc, alpha, spires, orb) = _layers[li];
      for (var i = 0; i < spires.length; i++) {
        final x = ((spires[i] - t * speed) % span + span) % span - 60;
        final up = (i + li).isEven;
        final hgt = (46 + 26 * ((i * 3 + li * 5) % 4)) * sc;
        final w = WingyWorld.spireWidth * sc;
        if (up) {
          painter.drawSpire(
            canvas,
            x,
            x + w,
            _h - hgt,
            _h,
            hangs: false,
            alpha: alpha,
          );
        } else {
          painter.drawSpire(
            canvas,
            x,
            x + w,
            0,
            hgt,
            hangs: true,
            alpha: alpha,
          );
        }
      }
      if (orb != null) {
        final x = ((orb - t * speed) % span + span) % span - 60;
        final y = 60 + 22 * sin(t * 1.3 + li * 2);
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(sc);
        painter.drawOrb(canvas, 0, 0);
        canvas.restore();
      }
    }

    // Moth: left to right, gentle bob and flap.
    const mothSpan = _w + 100;
    final mx = (t * 26) % mothSpan - 50;
    final my = _h / 2 + 16 * sin(t * 1.7);
    final frame = [0, 1, 2, 1][(t * 7).floor() % 4];
    // Glow Dash trail for 1.4 s of every 11 s.
    final phase = t % 11;
    if (phase < 1.4) {
      final f = sin(phase / 1.4 * pi);
      final trail = Rect.fromLTWH(mx - 130, my - 7, 130, 14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(trail, const Radius.circular(7)),
        Paint()
          ..shader = ui.Gradient.linear(trail.centerRight, trail.centerLeft, [
            Color(painter.skin.trail).withValues(alpha: 0.55 * f),
            Color(painter.skin.trail & 0xFFFFFF),
          ]),
      );
    }
    painter.drawMoth(
      canvas,
      mx,
      my,
      tilt: 0.12 * cos(t * 1.7),
      frame: frame,
      dashing: phase < 1.4,
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) => false;
}
