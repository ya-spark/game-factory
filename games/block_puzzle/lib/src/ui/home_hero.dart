import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../host/profile_store.dart';
import '../host/services.dart';
import '../game/rules/piece.dart';
import '../game/themes/block_theme.dart';
import 'test_ids.dart';

/// Animated scene above the title: two lanes of catalogue pieces drift in opposite directions,
/// painted with the current theme's block skin; about every 6 s a lane "completes" with a small
/// sparkle. Drawn in code, decorative only (no gestures).
///
/// One ticker drives one painter. It stops while the home route is covered or the app is in the
/// background.
class HomeHero extends StatefulWidget {
  const HomeHero({super.key, this.height = maxHeight});

  /// Height of the band in dp.
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
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final _HeroPainter _painter = _HeroPainter(_time);
  Duration _last = Duration.zero;
  bool _covered = false;
  bool _background = false;
  BlockPuzzleProfileStore? _profile;

  /// True while the ticker is animating the scene.
  bool get running => _ticker.isActive;

  /// Theme whose skin the pieces are painted with.
  BlockTheme get theme => _painter.theme;

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
    final profile = BlockPuzzleServicesScope.of(context).profile;
    if (!identical(profile, _profile)) {
      _profile?.removeListener(_onProfile);
      _profile = profile..addListener(_onProfile);
    }
    _onProfile();
  }

  void _onProfile() {
    final t = BlockTheme.byIndex(_profile!.data.themeIndex);
    if (t.id != _painter.theme.id) {
      _painter.theme = t;
      _time.value += 1e-6; // repaint
    }
    _sync();
  }

  void _sync() {
    final shouldRun = !_covered && !_background;
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
          child: CustomPaint(painter: _painter, size: Size.infinite),
        ),
      ),
    ),
  );
}

/// Scene in a 360 x 160 logical box, scaled to fit. 2 lanes x 5 pieces = 10 objects.
class _HeroPainter extends CustomPainter {
  _HeroPainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;
  BlockTheme theme = BlockTheme.byIndex(0);

  static const double _w = 360;
  static const double _h = 160;
  static const double _cell = 18;
  static const int _perLane = 5;
  static const double _gap = 90; // spacing between piece slots
  static const double _span = _perLane * _gap;

  static final List<Piece> _pieces = _fourCell();

  static List<Piece> _fourCell() {
    final four = [
      for (final p in PieceCatalog.all)
        if (p.size == 4) p,
    ];
    return four.isEmpty ? PieceCatalog.all : four;
  }

  void _drawPiece(Canvas canvas, Piece p, int color, double x, double y) {
    final ox = x - p.width * _cell / 2;
    final oy = y - p.height * _cell / 2;
    for (final (r, c) in p.cells) {
      theme.paintCell(
        canvas,
        Rect.fromLTWH(ox + c * _cell, oy + r * _cell, _cell, _cell),
        color % Piece.colorCount,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final s = min(size.width / _w, size.height / _h);
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - _w * s) / 2, (size.height - _h * s) / 2);
    canvas.scale(s);

    // (speed in u/s, negative = right to left; y; phase)
    const lanes = <(double, double, double)>[(-22, 46, 0), (15, 114, 1.7)];
    for (var li = 0; li < lanes.length; li++) {
      final (speed, y, phase) = lanes[li];
      for (var i = 0; i < _perLane; i++) {
        final raw = i * _gap + t * speed;
        final x = ((raw % _span) + _span) % _span - 60;
        final bob = 5 * sin(t * 1.4 + i * 1.3 + li * 2 + phase);
        final p = _pieces[(i * 7 + li * 11 + 3) % _pieces.length];
        _drawPiece(canvas, p, i * 3 + li * 5 + 1, x, y + bob);
      }
    }

    // A lane completes about every 6 s, alternating lanes: a short sparkle across it.
    final cycle = (t / 6).floor();
    final f = t - cycle * 6;
    if (cycle > 0 && f < 1.0) {
      final y = cycle.isEven ? 46.0 : 114.0;
      final paint = Paint()..color = Color.fromRGBO(255, 255, 255, 1 - f);
      for (var k = 0; k < 6; k++) {
        final px = 30 + k * 60 + 10 * sin(k * 2.1 + f * 4);
        final py = y + (k.isEven ? -1 : 1) * (8 + 14 * f);
        _star(canvas, Offset(px, py), 3 + 4 * sin(f * pi), paint);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final rr = i.isEven ? r : r * 0.35;
      final pt = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_HeroPainter old) => false;
}
