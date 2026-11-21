import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../rules/piece.dart';
import '../rules/theme_rotation.dart';

/// Tiles are recorded once in this square unit space and scaled when drawn.
const double tileUnit = 64;

/// One theme = background + block skin + 8 colours + empty-cell and grid colours.
/// Everything is drawn in code. The board only stores a colour index per cell.
class BlockTheme {
  const BlockTheme({
    required this.id,
    required this.palette,
    required this.emptyCell,
    required this.gridLine,
    required this.boardBackdrop,
    required this.backgroundTop,
    this.hudText = const Color(0xFFFFFFFF),
    this.hudSubtle = const Color(0xFF7FB7BD),
    this.hudShadows = const [],
    required this.paintBackground,
    required this.paintSkin,
  }) : assert(palette.length == Piece.colorCount);

  final String id;

  /// [Piece.colorCount] colours, indexed by a piece's colour index.
  final List<Color> palette;
  final Color emptyCell;
  final Color gridLine;
  final Color boardBackdrop;

  /// Top colour of the background gradient (what the HUD text must contrast with).
  final Color backgroundTop;

  /// HUD text drawn straight on the background (score, streak, combo, rush chip, best).
  final Color hudText;

  /// Secondary HUD text (the "SCORE" label).
  final Color hudSubtle;

  /// Soft dark shadow under the HUD texts (keeps 4.5:1 contrast on bright backgrounds).
  final List<Shadow> hudShadows;

  /// 2 px blur, 40 % black.
  static const List<Shadow> softHudShadow = [
    Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Paints the whole-screen background.
  final void Function(Canvas canvas, Size size) paintBackground;

  /// Paints one cell into the [tileUnit] square for [color] (the palette entry of [index]).
  final void Function(Canvas canvas, Rect r, Color color, int index) paintSkin;

  Color colorAt(int index) => palette[index % palette.length];

  /// Paints one cell with colour [index] into [rect] (direct, uncached; used by tests).
  void paintCell(Canvas canvas, Rect rect, int index) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / tileUnit, rect.height / tileUnit);
    paintSkin(
      canvas,
      const Rect.fromLTWH(0, 0, tileUnit, tileUnit),
      colorAt(index),
      index % Piece.colorCount,
    );
    canvas.restore();
  }

  static BlockTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => gems);

  static BlockTheme byIndex(int rotationIndex) =>
      all[rotationIndex % all.length];

  /// In rotation order (see [ThemeRotation.ids]).
  static final List<BlockTheme> all = [gems, cakes, wood, candy, ocean, space];

  static final BlockTheme gems = BlockTheme(
    id: 'gems',
    palette: const [
      Color(0xFF2EC4B6), // teal
      Color(0xFFFF6B5E), // coral
      Color(0xFFFFC145), // amber
      Color(0xFF8E7DFF), // violet
      Color(0xFF4CC9F0), // sky
      Color(0xFF9BDE5B), // lime
      Color(0xFFF06EAA), // pink
      Color(0xFFB5651D), // bronze
    ],
    emptyCell: const Color(0xFF132A34),
    gridLine: const Color(0x332EC4B6),
    boardBackdrop: const Color(0xFF0A1A22),
    backgroundTop: const Color(0xFF35C2D8),
    hudShadows: softHudShadow,
    paintBackground: (c, s) => _radial(c, s, const [
      Color(0xFF35C2D8),
      Color(0xFF2C73E0),
      Color(0xFF4A3FB5),
    ]),
    paintSkin: _gemSkin,
  );

  static final BlockTheme cakes = BlockTheme(
    id: 'cakes',
    palette: const [
      Color(0xFFFF9EB5), // strawberry
      Color(0xFFFFF1C9), // vanilla
      Color(0xFFD2956A), // chocolate
      Color(0xFFB9E4A1), // pistachio
      Color(0xFFFFB86B), // orange
      Color(0xFFB7A0F2), // blueberry
      Color(0xFF8FD6E8), // mint-blue
      Color(0xFFFF7A8A), // cherry
    ],
    emptyCell: const Color(0xFF4A2D1F),
    gridLine: const Color(0x44FFD9A8),
    boardBackdrop: const Color(0xFF2E1A10),
    backgroundTop: const Color(0xFF6B4332),
    paintBackground: _cakesBackground,
    paintSkin: _cakeSkin,
  );

  static final BlockTheme wood = BlockTheme(
    id: 'wood',
    palette: const [
      Color(0xFFC98B4B), // oak
      Color(0xFFB07B40), // walnut
      Color(0xFFE0B77A), // pine
      Color(0xFFC4724A), // cherry wood
      Color(0xFFD9A066), // maple
      Color(0xFFA07C5A), // dark
      Color(0xFFE8C99B), // birch
      Color(0xFFB5753A), // teak
    ],
    emptyCell: const Color(0xFF16402C),
    gridLine: const Color(0x44A8E6B8),
    boardBackdrop: const Color(0xFF0C2A1B),
    backgroundTop: const Color(0xFF3E9A5A),
    paintBackground: (c, s) => _linear(c, s, const [
      Color(0xFF3E9A5A),
      Color(0xFF1F6B3F),
      Color(0xFF0E3F26),
    ]),
    paintSkin: _woodSkin,
  );

  static final BlockTheme candy = BlockTheme(
    id: 'candy',
    palette: const [
      Color(0xFFC4155A), // raspberry
      Color(0xFFA84F00), // orange
      Color(0xFF7A5B00), // lemon
      Color(0xFF106A36), // lime
      Color(0xFF1565B0), // blue raspberry
      Color(0xFF6D32C4), // grape
      Color(0xFFBE2424), // cherry
      Color(0xFF0B6B68), // mint
    ],
    emptyCell: const Color(0xFFF7D6E6),
    gridLine: const Color(0x55FFFFFF),
    boardBackdrop: const Color(0xFFE9B8D0),
    backgroundTop: const Color(0xFFFFB7D5),
    hudText: const Color(0xFF5B2A55),
    hudSubtle: const Color(0xFF6E3A68),
    paintBackground: (c, s) => _linear(c, s, const [
      Color(0xFFFFB7D5),
      Color(0xFFFFD9EC),
      Color(0xFFA8DCFF),
    ]),
    paintSkin: _candySkin,
  );

  static final BlockTheme ocean = BlockTheme(
    id: 'ocean',
    palette: const [
      Color(0xFFF7C6D0), // pink pearl
      Color(0xFFFFE9B0), // sand
      Color(0xFFA6E3E9), // aqua
      Color(0xFFD6CAF8), // lilac
      Color(0xFFFFB38A), // coral
      Color(0xFF9FE0B0), // sea green
      Color(0xFFFFFFFF), // white pearl
      Color(0xFFA3CEFF), // blue
    ],
    emptyCell: const Color(0xFF123A66),
    gridLine: const Color(0x4400E5FF),
    boardBackdrop: const Color(0xFF082545),
    backgroundTop: const Color(0xFF1B6FB5),
    hudShadows: softHudShadow,
    paintBackground: _oceanBackground,
    paintSkin: _shellSkin,
  );

  static final BlockTheme space = BlockTheme(
    id: 'space',
    palette: const [
      Color(0xFFE76F51), // mars
      Color(0xFF4CC9F0), // neptune
      Color(0xFFF4D35E), // saturn
      Color(0xFF7BD389), // green world
      Color(0xFFB388EB), // violet
      Color(0xFFF28482), // rose
      Color(0xFFCAD2C5), // moon
      Color(0xFF4D7CFE), // deep blue
    ],
    emptyCell: const Color(0xFF241A4A),
    gridLine: const Color(0x44B9A7FF),
    boardBackdrop: const Color(0xFF130D2E),
    backgroundTop: const Color(0xFF2A1659),
    paintBackground: _spaceBackground,
    paintSkin: _planetSkin,
  );
}

// ---- helpers ---------------------------------------------------------------

Color _shade(Color c, double dl) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + dl).clamp(0.0, 1.0)).toColor();
}

void _radial(Canvas canvas, Size s, List<Color> colors) {
  canvas.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = Gradient.radial(
        Offset(s.width / 2, 0),
        s.longestSide * 0.95,
        colors,
        const [0, 0.55, 1],
      ),
  );
}

void _linear(Canvas canvas, Size s, List<Color> colors) {
  canvas.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, s.height),
        colors,
        const [0, 0.5, 1],
      ),
  );
}

// ---- backgrounds -----------------------------------------------------------

void _cakesBackground(Canvas canvas, Size s) {
  _linear(canvas, s, const [
    Color(0xFF6B4332),
    Color(0xFF50301F),
    Color(0xFF3A2216),
  ]);
  // Soft wafer pattern: a diagonal grid of faint lines.
  final p = Paint()
    ..color = const Color(0x14FFE0B8)
    ..strokeWidth = 2;
  const step = 28.0;
  for (var x = -s.height; x < s.width + s.height; x += step) {
    canvas.drawLine(Offset(x, 0), Offset(x + s.height, s.height), p);
    canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
  }
}

void _oceanBackground(Canvas canvas, Size s) {
  _linear(canvas, s, const [
    Color(0xFF1B6FB5),
    Color(0xFF0C3F7A),
    Color(0xFF051C45),
  ]);
  final rng = Random(7);
  final fill = Paint()..color = const Color(0x14FFFFFF);
  final edge = Paint()
    ..color = const Color(0x33FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  for (var i = 0; i < 26; i++) {
    final c = Offset(rng.nextDouble() * s.width, rng.nextDouble() * s.height);
    final r = 4 + rng.nextDouble() * 16;
    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, edge);
  }
}

void _spaceBackground(Canvas canvas, Size s) {
  _linear(canvas, s, const [
    Color(0xFF2A1659),
    Color(0xFF190E3D),
    Color(0xFF0B0623),
  ]);
  final rng = Random(11);
  final star = Paint();
  for (var i = 0; i < 90; i++) {
    final c = Offset(rng.nextDouble() * s.width, rng.nextDouble() * s.height);
    star.color = Color.fromRGBO(255, 255, 255, 0.35 + rng.nextDouble() * 0.5);
    canvas.drawCircle(c, 0.6 + rng.nextDouble() * 1.4, star);
  }
}

// ---- skins -----------------------------------------------------------------

/// Small mark that differs per colour index, so colours stay distinguishable without hue.
void _mark(Canvas canvas, Rect r, int index, {Color? color}) {
  final c = r.center;
  final u = r.width / 64;
  final fill = Paint()..color = color ?? const Color(0xD9FFFFFF);
  final line = Paint()
    ..color = color ?? const Color(0xD9FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3 * u
    ..strokeCap = StrokeCap.round;
  switch (index % 8) {
    case 0:
      canvas.drawCircle(c, 5 * u, fill);
    case 1:
      canvas.drawCircle(c, 7 * u, line);
    case 2:
      canvas.drawLine(c.translate(-8 * u, 0), c.translate(8 * u, 0), line);
    case 3:
      canvas.drawLine(c.translate(0, -8 * u), c.translate(0, 8 * u), line);
    case 4:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 8 * u)
          ..lineTo(c.dx + 7 * u, c.dy)
          ..lineTo(c.dx, c.dy + 8 * u)
          ..lineTo(c.dx - 7 * u, c.dy)
          ..close(),
        fill,
      );
    case 5:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 8 * u)
          ..lineTo(c.dx + 8 * u, c.dy + 6 * u)
          ..lineTo(c.dx - 8 * u, c.dy + 6 * u)
          ..close(),
        fill,
      );
    case 6:
      canvas.drawLine(c.translate(-7 * u, 0), c.translate(7 * u, 0), line);
      canvas.drawLine(c.translate(0, -7 * u), c.translate(0, 7 * u), line);
    default:
      canvas.drawCircle(c.translate(-6 * u, 0), 3.5 * u, fill);
      canvas.drawCircle(c.translate(6 * u, 0), 3.5 * u, fill);
  }
}

/// Rounded-square base tile that fills the whole cell (1 unit grid gap, corner radius 16 % of
/// the cell), tinted from the dark shade of [color], with a 1.5 unit outline at 45 % black and
/// a 1 unit light inner edge on the top and left at 35 % white. The skin motif is drawn on top.
void paintBaseTile(Canvas canvas, Rect rect, Color color) {
  final t = rect.deflate(rect.width * 0.5 / tileUnit);
  final radius = Radius.circular(t.width * 0.16);
  final rr = RRect.fromRectAndRadius(t, radius);
  canvas.drawRRect(rr, Paint()..color = _shade(color, -0.3));
  final edge = Paint()
    ..color = const Color(0x59FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final e = t.deflate(2);
  canvas.drawPath(
    Path()
      ..moveTo(e.left, e.bottom - t.width * 0.12)
      ..lineTo(e.left, e.top + t.width * 0.12)
      ..quadraticBezierTo(e.left, e.top, e.left + t.width * 0.12, e.top)
      ..lineTo(e.right - t.width * 0.12, e.top),
    edge,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(t.deflate(0.75), radius),
    Paint()
      ..color = const Color(0x73000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

/// Glossy rounded gem: diagonal gradient, soft edge, specular dot.
void _gemSkin(Canvas canvas, Rect rect, Color color, int index) {
  final r = rect.deflate(rect.width * 0.03);
  final rrect = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.26));
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = Gradient.linear(
        r.topLeft,
        r.bottomRight,
        [_shade(color, 0.12), color, _shade(color, -0.12)],
        const [0.0, 0.55, 1.0],
      ),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x22000000),
  );
  canvas.drawCircle(
    Offset(r.left + r.width * 0.3, r.top + r.height * 0.27),
    r.width * 0.09,
    Paint()..color = const Color(0xB3FFFFFF),
  );
  _mark(canvas, r.translate(r.width * 0.06, r.height * 0.08), index);
}

/// Biscuit with cream icing and sprinkles.
void _cakeSkin(Canvas canvas, Rect rect, Color color, int index) {
  paintBaseTile(canvas, rect, color);
  final r = rect.deflate(2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.22)),
    Paint()..color = const Color(0xFFD9A55E),
  );
  final icing = r.deflate(r.width * 0.1);
  canvas.drawRRect(
    RRect.fromRectAndRadius(icing, Radius.circular(icing.width * 0.3)),
    Paint()
      ..shader = Gradient.linear(
        icing.topLeft,
        icing.bottomRight,
        [_shade(color, 0.08), color, _shade(color, -0.08)],
        const [0, 0.6, 1],
      ),
  );
  const sprinkles = [
    (0.22, 0.28, 0.5, Color(0xFFFFFFFF)),
    (0.68, 0.22, -0.7, Color(0xFFFFE066)),
    (0.3, 0.7, -0.4, Color(0xFF7BD389)),
    (0.72, 0.68, 0.9, Color(0xFF4DB6FF)),
  ];
  final sp = Paint()
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  for (final (fx, fy, a, col) in sprinkles) {
    final o = Offset(r.left + r.width * fx, r.top + r.height * fy);
    final d = Offset(cos(a), sin(a)) * 4;
    sp.color = col;
    canvas.drawLine(o - d, o + d, sp);
  }
  _mark(canvas, r, index, color: _shade(color, -0.35));
}

/// Wooden tile with grain lines.
void _woodSkin(Canvas canvas, Rect rect, Color color, int index) {
  paintBaseTile(canvas, rect, color);
  final r = rect.deflate(2);
  final rrect = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.12));
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = Gradient.linear(
        r.topCenter,
        r.bottomCenter,
        [_shade(color, 0.07), color, _shade(color, -0.07)],
        const [0, 0.5, 1],
      ),
  );
  final grain = Paint()
    ..color = _shade(color, -0.16).withAlpha(150)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  for (var i = 1; i <= 4; i++) {
    final y = r.top + r.height * i / 5;
    canvas.drawPath(
      Path()
        ..moveTo(r.left + 4, y)
        ..quadraticBezierTo(
          r.center.dx,
          y + (i.isEven ? 5 : -5),
          r.right - 4,
          y + (i.isEven ? -1 : 2),
        ),
      grain,
    );
  }
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _shade(color, -0.25),
  );
  _mark(canvas, r, index, color: _shade(color, -0.32));
}

/// Glossy gumdrop sweet.
void _candySkin(Canvas canvas, Rect rect, Color color, int index) {
  paintBaseTile(canvas, rect, color);
  final r = rect.deflate(2);
  final rrect = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.42));
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = Gradient.radial(
        Offset(r.left + r.width * 0.38, r.top + r.height * 0.32),
        r.width * 0.8,
        [_shade(color, 0.2), color, _shade(color, -0.1)],
        const [0, 0.55, 1],
      ),
  );
  canvas.drawOval(
    Rect.fromLTWH(
      r.left + r.width * 0.2,
      r.top + r.height * 0.12,
      r.width * 0.3,
      r.height * 0.16,
    ),
    Paint()..color = const Color(0xB3FFFFFF),
  );
  final sugar = Paint()..color = const Color(0x66FFFFFF);
  for (final (fx, fy) in const [(0.7, 0.3), (0.78, 0.55), (0.3, 0.78)]) {
    canvas.drawCircle(
      Offset(r.left + r.width * fx, r.top + r.height * fy),
      1.6,
      sugar,
    );
  }
  _mark(canvas, r.translate(0, r.height * 0.06), index);
}

/// Pearly shell with fan ridges.
void _shellSkin(Canvas canvas, Rect rect, Color color, int index) {
  paintBaseTile(canvas, rect, color);
  final r = rect.deflate(2);
  final rrect = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.3));
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = Gradient.radial(
        Offset(r.center.dx, r.top + r.height * 0.3),
        r.width * 0.85,
        [const Color(0xFFFFFFFF), color, _shade(color, -0.14)],
        const [0, 0.5, 1],
      ),
  );
  canvas.save();
  canvas.clipRRect(rrect);
  final ridge = Paint()
    ..color = _shade(color, -0.2).withAlpha(120)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  final base = Offset(r.center.dx, r.bottom + 2);
  for (var i = -3; i <= 3; i++) {
    final a = -pi / 2 + i * 0.3;
    canvas.drawLine(
      base,
      base + Offset(cos(a), sin(a)) * r.height * 0.95,
      ridge,
    );
  }
  canvas.restore();
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x55FFFFFF),
  );
  _mark(
    canvas,
    r.translate(0, -r.height * 0.1),
    index,
    color: _shade(color, -0.4),
  );
}

/// Round planet with a ring and craters.
void _planetSkin(Canvas canvas, Rect rect, Color color, int index) {
  paintBaseTile(canvas, rect, color);
  final c = rect.center;
  final rad = rect.width * 0.415;
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..color = _shade(color, 0.2).withAlpha(210);
  final ringRect = Rect.fromCenter(
    center: c,
    width: rect.width * 0.96,
    height: rect.height * 0.3,
  );
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-0.35);
  canvas.translate(-c.dx, -c.dy);
  // Back half of the ring, planet, then front half.
  canvas.drawArc(ringRect, pi, pi, false, ring);
  canvas.restore();
  canvas.drawCircle(
    c,
    rad,
    Paint()
      ..shader = Gradient.radial(
        c.translate(-rad * 0.35, -rad * 0.4),
        rad * 1.7,
        [_shade(color, 0.15), color, _shade(color, -0.2)],
        const [0, 0.5, 1],
      ),
  );
  final crater = Paint()..color = _shade(color, -0.18).withAlpha(150);
  canvas.drawCircle(c.translate(rad * 0.35, -rad * 0.35), rad * 0.16, crater);
  canvas.drawCircle(c.translate(-rad * 0.45, rad * 0.1), rad * 0.12, crater);
  canvas.drawCircle(c.translate(rad * 0.1, rad * 0.5), rad * 0.1, crater);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-0.35);
  canvas.translate(-c.dx, -c.dy);
  canvas.drawArc(ringRect, 0, pi, false, ring);
  canvas.restore();
  _mark(
    canvas,
    rect.translate(0, -rect.height * 0.12),
    index,
    color: _shade(color, -0.4),
  );
}

// ---- cache -----------------------------------------------------------------

/// Pictures of every (theme, colour) cell, recorded on first use, so drawing a cell is
/// one `drawPicture` and a theme change costs nothing per frame.
class ThemeTileCache {
  final Map<(String, int), Picture> _tiles = {};

  Picture tile(BlockTheme theme, int index) {
    final i = index % Piece.colorCount;
    return _tiles.putIfAbsent((theme.id, i), () {
      final rec = PictureRecorder();
      theme.paintCell(
        Canvas(rec),
        const Rect.fromLTWH(0, 0, tileUnit, tileUnit),
        i,
      );
      return rec.endRecording();
    });
  }

  /// Draws the cell at [rect].
  void draw(Canvas canvas, BlockTheme theme, int index, Rect rect) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / tileUnit, rect.height / tileUnit);
    canvas.drawPicture(tile(theme, index));
    canvas.restore();
  }

  void dispose() {
    for (final p in _tiles.values) {
      p.dispose();
    }
    _tiles.clear();
  }
}
