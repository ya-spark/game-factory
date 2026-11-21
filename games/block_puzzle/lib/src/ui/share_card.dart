import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../game/themes/block_theme.dart';

/// What the share card shows. No player name, no id, no store text.
class ShareCardData {
  const ShareCardData({
    required this.gameName,
    required this.headline,
    required this.big,
    required this.best,
    required this.theme,
  });

  final String gameName;

  /// Small line above the big value ("Score", "Achievement unlocked").
  final String headline;

  /// The big value: the score, or the achievement title.
  final String big;
  final int best;

  /// The look of the game: the current theme's background and block skin.
  final BlockTheme theme;
}

/// Logical size of the card; rendered at [ShareCard.pixelRatio] for a 1080 px wide PNG.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  final ShareCardData data;

  static const double width = 360;
  static const double height = 450;
  static const double pixelRatio = 3;

  @override
  Widget build(BuildContext context) {
    const shadow = [
      Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 2)),
    ];
    const base = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      shadows: shadow,
      decoration: TextDecoration.none,
    );
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CardBackground(data.theme),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                data.gameName.toUpperCase(),
                style: base.copyWith(fontSize: 34, letterSpacing: 4),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.headline,
                    style: base.copyWith(fontSize: 18, color: Colors.white70),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      data.big,
                      textAlign: TextAlign.center,
                      style: base.copyWith(fontSize: 96),
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Best ${data.best}', style: base.copyWith(fontSize: 24)),
                  const SizedBox(height: 10),
                  CustomPaint(
                    size: const Size(8 * 30, 30),
                    painter: _SkinRow(data.theme),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBackground extends CustomPainter {
  _CardBackground(this.theme);
  final BlockTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    theme.paintBackground(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardBackground old) => old.theme.id != theme.id;
}

/// One block of every colour of the theme, drawn with its skin.
class _SkinRow extends CustomPainter {
  _SkinRow(this.theme);
  final BlockTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height;
    for (var i = 0; i < theme.palette.length; i++) {
      theme.paintCell(canvas, Rect.fromLTWH(i * cell, 0, cell, cell), i);
    }
  }

  @override
  bool shouldRepaint(_SkinRow old) => old.theme.id != theme.id;
}

/// Renders a [RepaintBoundary] to PNG bytes.
Future<Uint8List?> boundaryToPng(
  RenderRepaintBoundary boundary, {
  double pixelRatio = ShareCard.pixelRatio,
}) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes?.buffer.asUint8List();
}

/// Draws [data] off screen in the overlay of [context] and returns it as a PNG.
/// Returns null if rendering fails: sharing then falls back to text only.
Future<Uint8List?> captureShareCard(
  BuildContext context,
  ShareCardData data,
) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -ShareCard.width - 100,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ShareCard(data: data),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return await boundaryToPng(boundary);
  } catch (_) {
    return null;
  } finally {
    entry.remove();
  }
}
