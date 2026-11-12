import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'test_ids.dart';

/// The one image loader for game art and content images.
///
/// Loads from the asset bundle (or a local file). No network images: the games
/// have no backend. Shows a neutral placeholder until the first frame, and a
/// drawn fallback shape (never a person) when the image is missing or cannot be
/// decoded, so a screen never shows a broken image. The fade-in is skipped when
/// reduce motion is on. Flutter's image cache handles caching.
class AppImage extends StatelessWidget {
  const AppImage.asset(
    String this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  }) : filePath = null;

  const AppImage.file(
    String this.filePath, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  }) : asset = null;

  final String? asset;
  final String? filePath;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Null marks the image as decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // A browser has no local files: a file image shows the drawn fallback there.
    if (asset == null && kIsWeb) {
      return _Fallback(width: width, height: height);
    }
    final ImageProvider provider = asset != null
        ? AssetImage(asset!)
        : FileImage(File(filePath!));
    final image = Image(
      key: TestIds.appImageImage,
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        if (frame == null) return _Placeholder(width: width, height: height);
        if (reduce) return child;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 150),
          builder: (context, v, c) => Opacity(opacity: v, child: c),
          child: child,
        );
      },
      errorBuilder: (context, error, stack) =>
          _Fallback(width: width, height: height),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        key: TestIds.appImage,
        width: width,
        height: height,
        child: image,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: TestIds.appImagePlaceholder,
    width: width,
    height: height,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
  );
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: TestIds.appImageFallback,
      width: width,
      height: height,
      child: CustomPaint(
        painter: _FallbackPainter(
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A rounded tile with a simple mountain-and-sun shape.
class _FallbackPainter extends CustomPainter {
  _FallbackPainter(this.bg, this.fg);
  final Color bg;
  final Color fg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = bg,
    );
    final s = size.shortestSide;
    final paint = Paint()..color = fg.withValues(alpha: 0.5);
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.3),
      s * 0.08,
      paint,
    );
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.75)
      ..lineTo(size.width * 0.45, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height * 0.6)
      ..lineTo(size.width * 0.72, size.height * 0.5)
      ..lineTo(size.width * 0.85, size.height * 0.75)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FallbackPainter old) => old.bg != bg || old.fg != fg;
}
