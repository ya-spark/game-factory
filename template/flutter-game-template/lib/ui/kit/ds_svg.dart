import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The only file that imports `flutter_svg`. Renders a bundled design SVG (icon, hero scene or
/// mascot). Icons are drawn with `currentColor`, so [color] recolours them with the theme.
class DsSvg extends StatelessWidget {
  const DsSvg(
    this.asset, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
    this.bundle,
  });

  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      asset,
      bundle: bundle,
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      // The icon colour comes from the theme; scenes keep their own colours (color == null).
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      // Missing art (a game without a mascot) must never crash a screen.
      placeholderBuilder: (_) =>
          SizedBox(width: width ?? size, height: height ?? size),
    ),
  );
}
