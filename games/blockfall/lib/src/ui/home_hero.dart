import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../host/profile_store.dart';
import '../host/services.dart';
import '../game/rules/piece_type.dart';
import '../game/rules/well.dart';
import '../game/themes/block_theme.dart';
import '../game/themes/special_overlay.dart';
import 'test_ids.dart';

/// Animated scene above the title: the seven falling-block pieces and single gems (prism,
/// Boom, golden) slowly fall and drift sideways, some left to right and some right to left,
/// with a gentle spin. Painted with the current theme's block skin. Drawn in code, decorative
/// only (no gestures).
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
  BlockfallProfileStore? _profile;

  /// True while the ticker is animating the scene.
  bool get running => _ticker.isActive;

  /// Theme whose skin the pieces are painted with.
  BlockTheme get theme => _painter.theme;

  /// Number of animated objects (at most 12).
  int get objectCount => _HeroPainter.objects.length;

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
    final profile = BlockfallServicesScope.of(context).profile;
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

class _Obj {
  const _Obj(
    this.piece,
    this.x,
    this.fall,
    this.drift,
    this.spin,
    this.phase, [
    this.kind = CellKind.normal,
  ]);

  /// Piece shape; null = a single gem.
  final PieceType? piece;
  final double x;

  /// Fall speed in u/s.
  final double fall;

  /// Sideways speed in u/s (negative = right to left).
  final double drift;

  /// Spin speed in rad/s.
  final double spin;

  /// Start offset 0..1 along the fall.
  final double phase;
  final CellKind kind;
}

/// Scene in a 360 x 160 logical box, scaled to fit. 7 pieces + 3 single gems = 10 objects.
class _HeroPainter extends CustomPainter {
  _HeroPainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;
  BlockTheme theme = BlockTheme.byIndex(0);

  static const double _w = 360;
  static const double _h = 160;
  static const double _cell = 15;
  static const double _margin = 40;

  static final List<_Obj> objects = [
    for (var i = 0; i < 7; i++)
      _Obj(
        PieceType.values[i],
        20 + i * 50.0,
        11 + (i % 3) * 3,
        i.isEven ? 9 : -9,
        (i.isEven ? 1 : -1) * (0.3 + 0.1 * (i % 3)),
        i / 7,
      ),
    const _Obj(null, 70, 13, -8, 0.5, 0.2, CellKind.prism),
    const _Obj(null, 200, 10, 8, -0.45, 0.55, CellKind.boom),
    const _Obj(null, 310, 12, -7, 0.4, 0.85, CellKind.gold),
  ];

  void _drawObject(Canvas canvas, _Obj o, double t) {
    const fall = _h + 2 * _margin;
    const span = _w + 2 * _margin;
    final y = (o.phase * fall + t * o.fall) % fall - _margin;
    final x = ((o.x + _margin + t * o.drift) % span + span) % span - _margin;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(sin(t * o.spin + o.phase * 6) * 0.5);
    final cells = o.piece?.states.first ?? const [(0, 0)];
    var maxC = 0, maxR = 0;
    for (final (c, r) in cells) {
      maxC = max(maxC, c);
      maxR = max(maxR, r);
    }
    final ox = -(maxC + 1) * _cell / 2;
    final oy = -(maxR + 1) * _cell / 2;
    final colorId = o.piece?.colorId ?? 1 + (o.phase * 7).floor() % 7;
    var i = 0;
    for (final (c, r) in cells) {
      final rect = Rect.fromLTWH(ox + c * _cell, oy + r * _cell, _cell, _cell);
      // Prism gems, and one prism cell in some pieces.
      final prism =
          o.kind == CellKind.prism ||
          (o.piece != null && i == 1 && o.phase > 0.5);
      theme.paintCell(
        canvas,
        rect,
        colorId,
        prism: prism,
        pulse: (t * 0.5 + o.phase) % 1,
      );
      if (o.kind == CellKind.boom || o.kind == CellKind.gold) {
        drawSpecialOverlay(canvas, o.kind, rect);
      }
      i++;
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final s = min(size.width / _w, size.height / _h);
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - _w * s) / 2, (size.height - _h * s) / 2);
    canvas.scale(s);
    for (final o in objects) {
      _drawObject(canvas, o, t);
    }
  }

  @override
  bool shouldRepaint(_HeroPainter old) => false;
}
