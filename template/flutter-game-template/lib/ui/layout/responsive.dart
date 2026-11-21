import 'package:flutter/material.dart';

/// Screen size classes for the web version (the app keeps its phone layout).
/// New screens use these instead of hard-coded widths, so the layout changes with the window.
enum WindowClass {
  /// Under 600 logical pixels: a phone, one column.
  compact,

  /// 600 to 1023: a tablet or a narrow window, content centred, two columns where it helps.
  medium,

  /// 1024 and up: a desktop window, a side panel and a wide content area.
  expanded;

  static const double mediumFrom = 600;
  static const double expandedFrom = 1024;

  static WindowClass of(double width) => width >= expandedFrom
      ? expanded
      : (width >= mediumFrom ? medium : compact);

  static WindowClass ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}

/// Widest the main content gets, per window class. Text and play fields stay readable.
double contentMaxWidth(WindowClass c) => switch (c) {
  WindowClass.compact => double.infinity,
  WindowClass.medium => 720,
  WindowClass.expanded => 1120,
};

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
