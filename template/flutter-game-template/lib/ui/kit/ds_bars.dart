import 'package:flutter/material.dart';

import '../test_ids.dart';
import '../theme/app_theme.dart';
import 'ds_buttons.dart';
import 'ds_chips.dart';

/// A surface card with the token radius and border. Tappable when [onTap] is set.
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    this.id,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding,
    this.color,
  });
  final String? id;
  final Widget child;
  final VoidCallback? onTap;

  /// Required for a tappable card: what a screen reader announces.
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final radius = BorderRadius.circular(t.cardRadius);
    final body = Padding(
      padding: padding ?? EdgeInsets.all(t.sp('lg')),
      child: child,
    );
    final card = Material(
      key: id == null ? null : TestIds.dsCard(id!),
      color: color ?? t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: t.minTouch),
                child: body,
              ),
            ),
    );
    if (onTap == null) return card;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: card,
    );
  }
}

/// Progress as a bar: thick (12) or thin (6). [value] is 0 to 1. The percentage is announced
/// to screen readers; [semanticLabel] says what is progressing.
class DsProgressBar extends StatelessWidget {
  const DsProgressBar({
    super.key,
    required this.id,
    required this.value,
    this.thin = false,
    this.semanticLabel,
  });
  final String id;
  final double value;
  final bool thin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final h = t.size(thin ? 'progress_bar_thin' : 'progress_bar');
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: semanticLabel ?? 'Progress',
      value: '${(v * 100).round()} percent',
      excludeSemantics: true,
      child: ClipRRect(
        key: TestIds.dsProgress(id),
        borderRadius: BorderRadius.circular(h),
        child: SizedBox(
          height: h,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: t.surfaceAlt)),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: ColoredBox(color: t.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top bar: [title] (or [leading]) on the left, then [modeToggle] (a slot; the toggle itself is
/// issue 02B) and the coin chip. [overlay] mode (transparent, on a hero scene) is selected by
/// `transparent`.
class DsTopBar extends StatelessWidget {
  const DsTopBar({
    super.key,
    this.id = 'main',
    this.title,
    this.leading,
    this.modeToggle,
    this.coins,
    this.transparent = false,
  });
  final String id;
  final String? title;
  final Widget? leading;
  final Widget? modeToggle;
  final int? coins;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Container(
      key: TestIds.dsTopBar(id),
      color: transparent ? Colors.transparent : t.bg,
      padding: EdgeInsets.symmetric(
        horizontal: t.sp('lg'),
        vertical: t.sp('sm'),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: t.sp('sm'))],
          if (title != null)
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.styles['title']!,
                ),
              ),
            ),
          if (modeToggle != null || coins != null)
            // Wraps to a second line at large text instead of overflowing.
            Flexible(
              // Without a title the toggle and coins take the whole row, aligned to the end.
              fit: title == null ? FlexFit.tight : FlexFit.loose,
              child: Padding(
                padding: EdgeInsets.only(left: t.sp('sm')),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: t.sp('sm'),
                  runSpacing: t.sp('xs'),
                  children: [
                    ?modeToggle,
                    if (coins != null) DsCoinChip(coins: coins!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tab of [DsBottomBar]: [icon] is a design icon name.
class DsTab {
  const DsTab({required this.id, required this.label, required this.icon});
  final String id;
  final String label;
  final String icon;
}

/// Bottom bar with three tabs and a pill behind the active one.
class DsBottomBar extends StatelessWidget {
  const DsBottomBar({
    super.key,
    this.id = 'main',
    required this.tabs,
    required this.selected,
    required this.onSelect,
  }) : assert(tabs.length == 3, 'the bottom bar has exactly 3 tabs');
  final String id;
  final List<DsTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Material(
      key: TestIds.dsBottomBar(id),
      color: t.surface,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(minHeight: t.size('bottom_bar_height')),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.border)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: t.sp('md'),
            vertical: t.sp('sm'),
          ),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    key: TestIds.dsTab(id, tabs[i].id),
                    tab: tabs[i],
                    active: i == selected,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.tab,
    required this.active,
    required this.onTap,
  });
  final DsTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final reduce = t.reduceMotion || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.buttonRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouch),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: reduce ? Duration.zero : t.duration(fast: true),
                padding: EdgeInsets.symmetric(
                  horizontal: t.sp('lg'),
                  vertical: t.sp('xs'),
                ),
                decoration: BoxDecoration(
                  color: active ? t.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: DsIcon(
                  tab.icon,
                  size: t.size('icon_md'),
                  color: active ? t.onPrimary : t.textMuted,
                ),
              ),
              SizedBox(height: t.sp('xs')),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.styles['caption']!.copyWith(
                  color: active ? t.text : t.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
