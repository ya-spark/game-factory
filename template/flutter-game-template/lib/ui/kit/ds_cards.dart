import 'package:flutter/material.dart';

import '../test_ids.dart';
import '../theme/app_theme.dart';
import 'ds_bars.dart';
import 'ds_buttons.dart';
import 'ds_chips.dart';
import 'ds_svg.dart';

/// Game tile (Game mode): art slot, badge, stars, a thin progress bar with a note, or a lock and
/// the coin price when locked. Coin prices belong to games only; never put a price on a topic or
/// pack card.
class DsGameTile extends StatelessWidget {
  const DsGameTile({
    super.key,
    required this.id,
    required this.title,
    required this.art,
    required this.onTap,
    this.badge,
    this.stars,
    this.progress,
    this.note,
    this.lockedPrice,
    this.semanticLabel,
  });
  final String id;
  final String title;

  /// Art slot, `card_art_height` tall (an SVG, an icon, a mini board...).
  final Widget art;
  final VoidCallback onTap;

  /// Daily, New, Popular.
  final String? badge;

  /// 0 to 3; null hides the row.
  final int? stars;

  /// 0 to 1 with an optional [note] ("24 questions open"); null hides both.
  final double? progress;
  final String? note;

  /// Set when the game is locked: shows the lock and this many coins.
  final int? lockedPrice;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final locked = lockedPrice != null;
    final label =
        semanticLabel ??
        [
          title,
          ?badge,
          if (stars != null) '$stars of 3 stars',
          ?note,
          if (locked) 'locked, $lockedPrice coins',
        ].join(', ');
    return DsCard(
      id: 'tile.$id',
      onTap: onTap,
      semanticLabel: label,
      padding: EdgeInsets.all(t.sp('md')),
      child: KeyedSubtree(
        key: TestIds.dsGameTile(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: t.size('card_art_height'),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(t.cardRadius / 2),
                      child: ColoredBox(color: t.surfaceAlt, child: art),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      left: t.sp('xs'),
                      top: t.sp('xs'),
                      child: DsLabelChip(label: badge!, emphasis: true),
                    ),
                  if (locked)
                    Positioned(
                      right: t.sp('xs'),
                      top: t.sp('xs'),
                      child: DsIcon('lock', size: t.size('icon_md')),
                    ),
                ],
              ),
            ),
            SizedBox(height: t.sp('sm')),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.styles['subheading']!,
            ),
            if (stars != null) ...[
              SizedBox(height: t.sp('xs')),
              _Stars(stars!.clamp(0, 3)),
            ],
            if (progress != null) ...[
              SizedBox(height: t.sp('sm')),
              DsProgressBar(id: 'tile.$id', value: progress!, thin: true),
              if (note != null)
                Padding(
                  padding: EdgeInsets.only(top: t.sp('xs')),
                  child: Text(
                    note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.styles['caption']!.copyWith(color: t.textMuted),
                  ),
                ),
            ],
            if (locked) ...[
              SizedBox(height: t.sp('sm')),
              Align(
                alignment: Alignment.centerLeft,
                child: DsCoinChip(id: 'price.$id', coins: lockedPrice!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: t.sp('xs')),
              child: DsIcon(
                'star',
                size: t.size('icon_sm'),
                color: i < count ? t.coin : t.border,
              ),
            ),
        ],
      ),
    );
  }
}

/// Content (topic) card: subject badge, items passed of total, progress bar, mastery chip and a
/// "to revise" chip. Accuracy shows only when [showAccuracy] is true (off for Scout).
class DsTopicCard extends StatelessWidget {
  const DsTopicCard({
    super.key,
    required this.id,
    required this.title,
    required this.subject,
    required this.passed,
    required this.total,
    required this.mastery,
    required this.onTap,
    this.toRevise = 0,
    this.accuracyPercent,
    this.showAccuracy = false,
  });
  final String id;
  final String title;
  final String subject;
  final int passed;
  final int total;
  final Mastery mastery;
  final VoidCallback onTap;

  /// Items due for revision; the chip shows only when above 0.
  final int toRevise;
  final int? accuracyPercent;

  /// Feature flag per app: false for Scout.
  final bool showAccuracy;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final accuracy = showAccuracy && accuracyPercent != null
        ? accuracyPercent
        : null;
    return DsCard(
      id: 'topic.$id',
      onTap: onTap,
      semanticLabel: [
        title,
        subject,
        '$passed of $total passed',
        if (accuracy != null) '$accuracy percent correct',
        if (toRevise > 0) '$toRevise to revise',
      ].join(', '),
      child: KeyedSubtree(
        key: TestIds.dsTopicCard(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsLabelChip(label: subject, emphasis: true),
            SizedBox(height: t.sp('sm')),
            Text(title, style: t.styles['heading']!),
            SizedBox(height: t.sp('xs')),
            Text(
              '$passed of $total passed',
              style: t.styles['caption']!.copyWith(color: t.textMuted),
            ),
            SizedBox(height: t.sp('sm')),
            DsProgressBar(
              id: 'topic.$id',
              value: total == 0 ? 0 : passed / total,
              semanticLabel: '$title progress',
            ),
            SizedBox(height: t.sp('sm')),
            Wrap(
              spacing: t.sp('sm'),
              runSpacing: t.sp('xs'),
              children: [
                DsMasteryChip(id: 'topic.$id', mastery: mastery),
                if (toRevise > 0) DsLabelChip(label: '$toRevise to revise'),
                if (accuracy != null) DsLabelChip(label: '$accuracy% correct'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pack card: "Preview free" and a locked "Full pack" chip. **No price on the card**: the
/// price shows only after the parent gate.
class DsPackCard extends StatelessWidget {
  const DsPackCard({
    super.key,
    required this.id,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.previewLabel = 'Preview free',
    this.fullLabel = 'Full pack',
    this.fullUnlocked = false,
  });
  final String id;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String previewLabel;
  final String fullLabel;
  final bool fullUnlocked;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return DsCard(
      id: 'pack.$id',
      onTap: onTap,
      semanticLabel: [
        title,
        previewLabel,
        fullUnlocked ? fullLabel : '$fullLabel, locked',
      ].join(', '),
      child: KeyedSubtree(
        key: TestIds.dsPackCard(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: t.styles['heading']!),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(top: t.sp('xs')),
                child: Text(
                  subtitle!,
                  style: t.styles['caption']!.copyWith(color: t.textMuted),
                ),
              ),
            SizedBox(height: t.sp('sm')),
            Wrap(
              spacing: t.sp('sm'),
              runSpacing: t.sp('xs'),
              children: [
                DsLabelChip(label: previewLabel, icon: 'check'),
                DsLabelChip(
                  label: fullLabel,
                  icon: fullUnlocked ? 'check' : 'lock',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Try next" card at the top of Play and Learn ("Continue" in the Mind apps). The choice of what
/// to suggest is issue 02B.
class DsSuggestedCard extends StatelessWidget {
  const DsSuggestedCard({
    super.key,
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.actionLabel,
    required this.onTap,
    this.subtitle,
  });
  final String id;

  /// "Try next", "Continue".
  final String eyebrow;
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return DsCard(
      id: 'suggested.$id',
      color: t.surfaceAlt,
      child: KeyedSubtree(
        key: TestIds.dsSuggestedCard(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eyebrow,
              style: t.styles['caption']!.copyWith(color: t.textMuted),
            ),
            SizedBox(height: t.sp('xs')),
            Text(title, style: t.styles['title']!),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(top: t.sp('xs')),
                child: Text(subtitle!, style: t.styles['body']!),
              ),
            SizedBox(height: t.sp('md')),
            DsButton(
              id: 'suggested.$id',
              label: actionLabel,
              icon: 'chevron_right',
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero header: the app's scene SVG filling the top, an optional mascot, title, subtitle, stat
/// chips, and an [overlay] slot (the top bar) above it all. The scene is decorative.
class DsHeroHeader extends StatelessWidget {
  const DsHeroHeader({
    super.key,
    this.id = 'main',
    required this.sceneAsset,
    required this.title,
    this.mascotAsset,
    this.subtitle,
    this.chips = const [],
    this.overlay,
  });
  final String id;
  final String sceneAsset;
  final String? mascotAsset;
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return ConstrainedBox(
      key: TestIds.dsHero(id),
      constraints: BoxConstraints(minHeight: t.size('hero_height')),
      child: Stack(
        children: [
          Positioned.fill(child: DsSvg(sceneAsset, fit: BoxFit.cover)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ?overlay,
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.sp('lg'),
                  t.sp('md'),
                  t.sp('lg'),
                  t.sp('lg'),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text sits on a surface chip so contrast never depends on the scene.
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: t.sp('md'),
                              vertical: t.sp('sm'),
                            ),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(
                                t.buttonRadius,
                              ),
                            ),
                            child: Semantics(
                              header: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: t.styles['display']!),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      style: t.styles['body']!.copyWith(
                                        color: t.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (chips.isNotEmpty) ...[
                            SizedBox(height: t.sp('sm')),
                            Wrap(
                              spacing: t.sp('sm'),
                              runSpacing: t.sp('xs'),
                              children: chips,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (mascotAsset != null)
                      Padding(
                        padding: EdgeInsets.only(left: t.sp('sm')),
                        child: DsSvg(mascotAsset!, size: t.size('icon_lg') * 2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A themed dialog with a title, a body and up to two actions. Returns true for the primary
/// action, false for the secondary, null when dismissed.
Future<bool?> showDsDialog(
  BuildContext context, {
  required String id,
  required String title,
  required String body,
  required String primaryLabel,
  String? secondaryLabel,
}) => showDialog<bool>(
  context: context,
  builder: (ctx) {
    final t = ThemeTokens.of(ctx);
    return AlertDialog(
      key: TestIds.dsDialog(id),
      title: Text(title, style: t.styles['title']!),
      content: SingleChildScrollView(
        child: Text(body, style: t.styles['body']!),
      ),
      actions: [
        if (secondaryLabel != null)
          DsButton(
            id: '$id.secondary',
            label: secondaryLabel,
            kind: DsButtonKind.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        DsButton(
          id: '$id.primary',
          label: primaryLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    );
  },
);
