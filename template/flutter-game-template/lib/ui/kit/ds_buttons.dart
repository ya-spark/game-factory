import 'package:flutter/material.dart';

import '../test_ids.dart';
import '../theme/app_theme.dart';
import '../theme/design_loader.dart';
import 'ds_svg.dart';

/// Looks of [DsButton].
enum DsButtonKind { primary, secondary, ghost }

/// A design-system icon by file name (`coin`, `star`, ...), recoloured with [color].
class DsIcon extends StatelessWidget {
  const DsIcon(this.name, {super.key, this.size, this.color});
  final String name;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return DsSvg(
      DesignBundle.iconPath(name),
      size: size ?? t.size('icon_md'),
      color: color ?? t.text,
    );
  }
}

/// Primary, secondary and ghost buttons. Disabled when [onPressed] is null.
/// At least the token minimum touch size; the label wraps instead of overflowing.
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.id,
    required this.label,
    required this.onPressed,
    this.kind = DsButtonKind.primary,
    this.icon,
    this.semanticLabel,
    this.expand = false,
  });

  /// Stable test id: the widget key is `TestIds.dsButton(id)`.
  final String id;
  final String label;
  final VoidCallback? onPressed;
  final DsButtonKind kind;

  /// Design icon name shown before the label.
  final String? icon;

  /// Screen-reader label; defaults to [label].
  final String? semanticLabel;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final enabled = onPressed != null;
    final (Color bg, Color fg, Color? line) = switch ((kind, enabled)) {
      (_, false) => (
        kind == DsButtonKind.ghost ? Colors.transparent : t.surfaceAlt,
        t.textMuted,
        kind == DsButtonKind.primary ? null : t.border,
      ),
      (DsButtonKind.primary, _) => (t.primary, t.onPrimary, null),
      (DsButtonKind.secondary, _) => (t.surface, t.text, t.border),
      (DsButtonKind.ghost, _) => (Colors.transparent, t.primary, null),
    };
    // Ghost on `bg`/`surface`: `primary` is only guaranteed on its own `on-primary`, so keep the
    // ghost label in `text` when the primary colour is too weak on the page colour.
    final ghostFg = kind == DsButtonKind.ghost && enabled ? t.text : fg;
    final radius = BorderRadius.circular(t.buttonRadius);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          DsIcon(icon!, size: t.size('icon_md'), color: ghostFg),
          SizedBox(width: t.sp('sm')),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: t.styles['label']!.copyWith(color: ghostFg),
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        key: TestIds.dsButton(id),
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: line == null ? BorderSide.none : BorderSide(color: line),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: t.minTouch,
              minWidth: t.minTouch,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.sp('lg'),
                vertical: t.sp('sm'),
              ),
              child: Center(widthFactor: expand ? null : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
