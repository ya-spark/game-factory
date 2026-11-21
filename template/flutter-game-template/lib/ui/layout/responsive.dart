import 'package:flutter/material.dart';
import 'package:game_core/kit/layout/window_class.dart';

// One copy of the breakpoints for every game, app and the web: WindowClass and contentMaxWidth live in
// game_core and are re-exported here, so screens keep importing this file.
export 'package:game_core/kit/layout/window_class.dart';

/// Centres its child and limits its width by window class. Wrap a screen body in this.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final c = WindowClass.of(box.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(c)),
            child: child,
          ),
        );
      },
    );
  }
}

/// One column on a phone, two side by side on a wider window. [side] is the secondary pane (a
/// summary, the rules, the next step); on a phone it goes under [main].
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 320,
    this.gap = 24,
  });
  final Widget main;
  final Widget side;
  final double sideWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final c = WindowClass.of(box.maxWidth);
        if (c == WindowClass.compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              main,
              SizedBox(height: gap),
              side,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: main),
            SizedBox(width: gap),
            SizedBox(width: sideWidth, child: side),
          ],
        );
      },
    );
  }
}

/// Columns for a grid of cards at this width: 2 on a phone, 3 or 4 on wider windows.
int gridColumns(double width, {double minTile = 160}) =>
    (width / minTile).floor().clamp(2, 6);
