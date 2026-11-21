import 'package:flutter/material.dart';

import '../../host/game_host.dart';
import 'frame_ids.dart';
import 'window_class.dart';

/// The frame around a game: the game is centered with a widest size, and the ad sits beside or
/// above it by window class, never over it.
///
/// - compact (under 600 dp): the game fills the width; an anchored banner at the bottom while
///   [showAds] is true (menu and results).
/// - medium (600 to 1023): a 728 x 90 strip on top, the game centered below it.
/// - expanded (1024 and up): the game and a right rail (300 x 600, or 160 x 600 when the window
///   is narrow), the pair centered.
///
/// The container decides what fills each ad place (`GameHost.adUnit`); no unit, no space is kept.
/// Games pass [showAds] false while a round is being played.
class GameFrame extends StatelessWidget {
  const GameFrame({
    super.key,
    required this.child,
    this.maxWidth = 780,
    this.showAds = true,
    this.phoneBanner = GameBannerSlot.menu,
    this.gap = 24,
    this.minStage = 720,
    this.padding = const EdgeInsets.all(12),
  });

  /// The game. It gets the full height and a width up to [maxWidth].
  final Widget child;

  /// Widest the game gets (the stage), whatever the window.
  final double maxWidth;

  /// False while a round is being played: no ad is shown or reserved.
  final bool showAds;

  /// Which banner slot the phone layout uses (menu, or postGame on results).
  final GameBannerSlot phoneBanner;

  /// Space between the game and the rail or strip.
  final double gap;

  /// The narrowest the stage may get beside the half-page rail; below it the slimmer skyscraper is used.
  final double minStage;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final host = GameHostScope.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final cls = WindowClass.of(box.maxWidth);
        final stage = KeyedSubtree(key: FrameIds.stage, child: child);
        Widget body;
        switch (cls) {
          case WindowClass.compact:
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: stage),
                if (showAds)
                  Center(
                    child: KeyedSubtree(
                      key: FrameIds.banner,
                      child: host.banner(context, phoneBanner),
                    ),
                  ),
              ],
            );
          case WindowClass.medium:
            final strip = showAds
                ? host.adUnit(context, GameAdFormat.leaderboard)
                : null;
            body = Column(
              children: [
                if (strip != null) ...[
                  SizedBox(
                    key: FrameIds.strip,
                    width: strip.size.width,
                    height: strip.size.height,
                    child: strip.widget,
                  ),
                  SizedBox(height: gap / 2),
                ],
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: stage,
                    ),
                  ),
                ),
              ],
            );
          case WindowClass.expanded:
            final room = box.maxWidth - padding.horizontal;
            var unit = showAds
                ? host.adUnit(context, GameAdFormat.halfPage)
                : null;
            if (unit != null && room - gap - unit.size.width < minStage) {
              unit = host.adUnit(context, GameAdFormat.skyscraper);
            }
            // An ad that does not fit the height as its real size is left out: no stretched ads.
            if (unit != null &&
                box.maxHeight - padding.vertical < unit.size.height) {
              unit = null;
            }
            final rail = unit;
            body = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      maxWidth + (rail == null ? 0 : gap + rail.size.width),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: stage),
                    if (rail != null) ...[
                      SizedBox(width: gap),
                      SizedBox(
                        key: FrameIds.rail,
                        width: rail.size.width,
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: rail.size.width,
                            height: rail.size.height,
                            child: rail.widget,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
        }
        return Padding(key: FrameIds.frame, padding: padding, child: body);
      },
    );
  }
}
