import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../rules/theme_rotation.dart';
import '../rules/well.dart';
import 'special_overlay.dart';

/// Tiles are recorded once in this square unit space and scaled when drawn.
const double tileUnit = 64;

/// Length of the cross-fade between two themes, in milliseconds.
const int kThemeFadeMs = 1500;

/// Colours per theme: one per piece type (colour ids 1..7 stored in the well).
const int colorCount = 7;

/// Soft dark shadow (about 2 px blur, 40 % black) that keeps HUD text at 4.5:1 on bright backgrounds.
const List<Shadow> kHudTextShadow = [
  Shadow(color: Color(0x66000000), blurRadius: 2),
];

/// One theme = background + block skin + 7 colours + well and grid colours.
/// Everything is drawn in code. The well only stores a colour id and a prism flag per cell.
class BlockTheme {
  const BlockTheme({
    required this.id,
    required this.palette,
    required this.wellColor,
    required this.gridLine,
    required this.backgroundTop,
    this.hudText = const Color(0xFFFFFFFF),
    this.hudSubtle = const Color(0xFF7FB7BD),
    this.hudShadows = const [],
    required this.paintBackground,
    required this.paintSkin,
  }) : assert(palette.length == colorCount);

  final String id;

  /// [colorCount] colours; colour id `n` (1..7) uses entry `n - 1`.
  final List<Color> palette;

  /// Fill of the well panel and the colour of its grid lines.
  final Color wellColor;
  final Color gridLine;

  /// Top colour of the background gradient (what the HUD text must contrast with).
  final Color backgroundTop;

  /// HUD text drawn straight on the background (score, streak, combo, rush chip, best).
  final Color hudText;

  /// Secondary HUD text (the "SCORE" label).
  final Color hudSubtle;

  /// Soft text shadow for the HUD texts (empty on themes that do not need it).
  final List<Shadow> hudShadows;

  /// Paints the whole-screen background.
  final void Function(Canvas canvas, Size size) paintBackground;

  /// Paints one cell into the [tileUnit] square for [color] (the palette entry of [index]).
  final void Function(Canvas canvas, Rect r, Color color, int index) paintSkin;

  /// Colour for colour id 1..7.
  Color colorOf(int colorId) => palette[(colorId.clamp(1, colorCount)) - 1];

  /// Paints one cell with colour id [colorId] into [rect] (direct, uncached; used by tests
  /// and the cache). With [prism] the bright sparkle core is drawn on top.
  void paintCell(
    Canvas canvas,
    Rect rect,
    int colorId, {
    bool prism = false,
    double pulse = 0,
  }) {
    final id = colorId.clamp(1, colorCount);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / tileUnit, rect.height / tileUnit);
    paintSkin(
      canvas,
      const Rect.fromLTWH(0, 0, tileUnit, tileUnit),
      palette[id - 1],
      id - 1,
    );
    canvas.restore();
    if (prism) drawPrismGlow(canvas, rect, pulse);
  }

  /// Faint outline where the piece would land.
  void paintGhost(Canvas canvas, Rect cell, int colorId) {
    final color = colorOf(colorId);
    final r = RRect.fromRectAndRadius(
      cell.deflate(cell.width * 0.09),
      Radius.circular(cell.width * 0.22),
    );
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawRRect(
      r,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cell.width * 0.07),
    );
  }

  static BlockTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => gems);

  static BlockTheme byIndex(int rotationIndex) =>
      all[rotationIndex % all.length];

  /// In rotation order (see [ThemeRotation.ids]).
  static final List<BlockTheme> all = [gems, cakes, wood, candy, ocean, space];

  static final BlockTheme gems = BlockTheme(
    id: 'gems',
    hudShadows: kHudTextShadow,
    palette: const [
      Color(0xFF39D0F2), // cyan
      Color(0xFFFFC145), // gold
      Color(0xFF9A7BFF), // violet
      Color(0xFF7FDB5A), // green
      Color(0xFFFF5F57), // red
      Color(0xFF3F7CFF), // blue
      Color(0xFFFF9340), // orange
    ],
    wellColor: const Color(0xE608141B),
    gridLine: const Color(0x0DFFFFFF),
    backgroundTop: const Color(0xFF35C2D8),
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
      Color(0xFFFF7A8A), // cherry
    ],
    wellColor: const Color(0xE62E1A10),
    gridLine: const Color(0x22FFD9A8),
    backgroundTop: const Color(0xFF6B4332),
    paintBackground: _cakesBackground,
    paintSkin: _cakeSkin,
  );

  static final BlockTheme wood = BlockTheme(
    id: 'wood',
    palette: const [
      Color(0xFFC98B4B), // oak
      Color(0xFFA8743A), // walnut
      Color(0xFFE0B77A), // pine
      Color(0xFFBC6A3E), // cherry wood
      Color(0xFFD9A066), // maple
      Color(0xFFA07C5A), // dark
      Color(0xFFE8C99B), // birch
    ],
    wellColor: const Color(0xE60C2A1B),
    gridLine: const Color(0x22A8E6B8),
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
    ],
    wellColor: const Color(0xE6E9B8D0),
    gridLine: const Color(0x55FFFFFF),
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
    hudShadows: kHudTextShadow,
    palette: const [
      Color(0xFFF7C6D0), // pink pearl
      Color(0xFFFFE9B0), // sand
      Color(0xFFA6E3E9), // aqua
      Color(0xFFD6CAF8), // lilac
      Color(0xFFFFB38A), // coral
      Color(0xFF9FE0B0), // sea green
      Color(0xFFA3CEFF), // blue
    ],
    wellColor: const Color(0xE6082545),
    gridLine: const Color(0x2200E5FF),
    backgroundTop: const Color(0xFF1B6FB5),
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
      Color(0xFF4D7CFE), // deep blue
    ],
    wellColor: const Color(0xE6130D2E),
    gridLine: const Color(0x22B9A7FF),
    backgroundTop: const Color(0xFF2A1659),
    paintBackground: _spaceBackground,
    paintSkin: _planetSkin,
  );
}

/// Bright white-cyan sparkle core over a cell; the same in every skin.
void drawPrismGlow(Canvas canvas, Rect cell, double pulse) {
  final s = cell.width;
  final c = cell.center;
  final k = 0.75 + 0.25 * sin(pulse * 2 * pi);
  final glow = Paint()
    ..shader = Gradient.radial(
      c,
      s * 0.62 * k,
      const [Color(0xFFFFFFFF), Color(0x88B8F6FF), Color(0x0039D0F2)],
      const [0.0, 0.4, 1.0],
    );
  canvas.drawCircle(c, s * 0.62 * k, glow);
  canvas.drawCircle(c, s * 0.12, Paint()..color = const Color(0xFFFFFFFF));
  final ray = Paint()
    ..color = const Color(0xCCFFFFFF)
    ..strokeWidth = max(1, s * 0.05)
    ..strokeCap = StrokeCap.round;
  final r = s * 0.3 * k;
  canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), ray);
  canvas.drawLine(c.translate(0, -r), c.translate(0, r), ray);
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
  switch (index % colorCount) {
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
    default:
      canvas.drawLine(c.translate(-7 * u, 0), c.translate(7 * u, 0), line);
      canvas.drawLine(c.translate(0, -7 * u), c.translate(0, 7 * u), line);
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

/// Glossy faceted gem (the original Blockfall look): diagonal gradient, facet, specular dots.
void _gemSkin(Canvas canvas, Rect rect, Color color, int index) {
  final size = rect.width;
  final box = Rect.fromLTWH(0, 0, size, size);
  final body = RRect.fromRectAndRadius(
    box.deflate(size * 0.05),
    Radius.circular(size * 0.24),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..shader = Gradient.linear(
        box.topLeft,
        box.bottomRight,
        [
          Color.lerp(color, const Color(0xFFFFFFFF), 0.38)!,
          color,
          Color.lerp(color, const Color(0xFF000000), 0.4)!,
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.17, size * 0.14, size * 0.66, size * 0.4),
      Radius.circular(size * 0.16),
    ),
    Paint()
      ..shader = Gradient.linear(
        Offset(0, size * 0.14),
        Offset(0, size * 0.54),
        const [Color(0x55FFFFFF), Color(0x00FFFFFF)],
      ),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, size * 0.05)
      ..color = Color.lerp(color, const Color(0xFF000000), 0.55)!,
  );
  final spec = Paint()..color = const Color(0xE6FFFFFF);
  canvas.drawCircle(Offset(size * 0.3, size * 0.27), size * 0.075, spec);
  canvas.drawCircle(Offset(size * 0.38, size * 0.2), size * 0.035, spec);
  _mark(canvas, box.translate(size * 0.06, size * 0.1), index);
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
/// one `drawPicture` and a theme change costs nothing per frame. The prism sparkle pulses,
/// so it is drawn live on top of the cached tile.
class ThemeTileCache {
  final Map<(String, int), Picture> _tiles = {};

  Picture tile(BlockTheme theme, int colorId) {
    final id = colorId.clamp(1, colorCount);
    return _tiles.putIfAbsent((theme.id, id), () {
      final rec = PictureRecorder();
      theme.paintCell(
        Canvas(rec),
        const Rect.fromLTWH(0, 0, tileUnit, tileUnit),
        id,
      );
      return rec.endRecording();
    });
  }

  /// Draws the cell at [rect].
  void draw(
    Canvas canvas,
    BlockTheme theme,
    int colorId,
    Rect rect, {
    bool prism = false,
    CellKind kind = CellKind.normal,
    double pulse = 0,
  }) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / tileUnit, rect.height / tileUnit);
    canvas.drawPicture(tile(theme, colorId));
    canvas.restore();
    if (prism || kind == CellKind.prism) drawPrismGlow(canvas, rect, pulse);
    drawSpecialOverlay(canvas, kind, rect);
  }

  void dispose() {
    for (final p in _tiles.values) {
      p.dispose();
    }
    _tiles.clear();
  }
}
