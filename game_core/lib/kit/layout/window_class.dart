import 'package:flutter/widgets.dart';

/// Screen size classes (docs/WEB_LAYOUT.md): the same breakpoints for every game, app and the web.
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
