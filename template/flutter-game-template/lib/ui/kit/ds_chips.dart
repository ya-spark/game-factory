import 'package:flutter/material.dart';

import '../test_ids.dart';
import '../theme/app_theme.dart';
import '../../engine/content/progress.dart' show Mastery;
import 'ds_buttons.dart';

// Mastery (the engine's enum and rule) is shown by [DsMasteryChip] as a coloured dot and a word.
export '../../engine/content/progress.dart' show Mastery;

/// A rounded chip: optional leading widget and a label. Used by every chip below.
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.leading,
    this.minHeight,
    this.border,
    this.semanticLabel,
  });
  final String label;
  final Color bg;
  final Color fg;
  final Widget? leading;
  final double? minHeight;
  final Color? border;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Semantics(
      container: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight ?? 0),
        padding: EdgeInsets.symmetric(
          horizontal: t.sp('md'),
          vertical: t.sp('xs'),
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, SizedBox(width: t.sp('xs'))],
            Flexible(
              child: Text(
                label,
                style: t.styles['caption']!.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coins the player has. [semanticLabel] defaults to "N coins".
class DsCoinChip extends StatelessWidget {
  const DsCoinChip({
    super.key,
    this.id = 'coins',
    required this.coins,
    this.semanticLabel,
  });
  final String id;
  final int coins;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return _Pill(
      key: TestIds.dsCoinChip(id),
      label: '$coins',
      semanticLabel: semanticLabel ?? '$coins coins',
      bg: t.coin,
      fg: t.onCoin,
      minHeight: t.size('coin_chip_height'),
      leading: DsIcon('coin', size: t.size('icon_sm'), color: t.onCoin),
    );
  }
}

/// A small stat: streak (flame) or stars (star), or any icon and number. [semanticLabel] says
/// what it is ("3 day streak").
class DsStatChip extends StatelessWidget {
  const DsStatChip({
    super.key,
    required this.id,
    required this.icon,
    required this.value,
    required this.semanticLabel,
  });
  final String id;
  final String icon;
  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return _Pill(
      key: TestIds.dsStatChip(id),
      label: value,
      semanticLabel: semanticLabel,
      bg: t.surface,
      fg: t.text,
      border: t.border,
      leading: DsIcon(icon, size: t.size('icon_sm'), color: t.text),
    );
  }
}

/// Learning, Getting there or Mastered: a coloured dot and a word (never colour alone).
class DsMasteryChip extends StatelessWidget {
  const DsMasteryChip({
    super.key,
    required this.id,
    required this.mastery,
    this.labels = const {
      Mastery.learning: 'Learning',
      Mastery.gettingThere: 'Getting there',
      Mastery.mastered: 'Mastered',
    },
  });
  final String id;
  final Mastery mastery;
  final Map<Mastery, String> labels;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final dot = switch (mastery) {
      Mastery.learning => t.alt,
      Mastery.gettingThere => t.accent,
      Mastery.mastered => t.success,
    };
    return _Pill(
      key: TestIds.dsMasteryChip(id),
      label: labels[mastery]!,
      bg: t.surfaceAlt,
      fg: t.text,
      leading: Container(
        key: Key('ds.masteryChip.$id.dot'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
    );
  }
}

/// A plain text chip ("to revise", "Preview free", "Full pack", badges).
class DsLabelChip extends StatelessWidget {
  const DsLabelChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasis = false,
  });
  final String label;
  final String? icon;

  /// Accent look (the badge on a card); otherwise a quiet chip.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final fg = emphasis ? t.onAccent : t.text;
    return _Pill(
      label: label,
      bg: emphasis ? t.accent : t.surfaceAlt,
      fg: fg,
      leading: icon == null
          ? null
          : DsIcon(icon!, size: t.size('icon_sm'), color: fg),
    );
  }
}
