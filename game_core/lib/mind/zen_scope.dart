import 'package:flutter/material.dart';

import 'zen.dart';

/// Tells the game screen below it whether this run is Zen (M5). The hub wraps a game screen in it
/// when the game is started, with the Zen switch as it was at that moment, so flipping the switch
/// never changes a game already open. Outside a scope the run is normal.
///
/// A Zen run also turns Reduce motion on for the screen below (through the media query), without
/// touching the saved setting. Voice, vibration and tips are never read by the hub-native games.
class ZenScope extends StatelessWidget {
  const ZenScope({super.key, required this.zen, required this.child});
  final bool zen;
  final Widget child;

  /// The policy of the run the context belongs to.
  static ZenPolicy of(BuildContext context) => ZenPolicy.of(zenOf(context));

  static bool zenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ZenInherited>()?.zen ?? false;

  @override
  Widget build(BuildContext context) {
    Widget body = _ZenInherited(zen: zen, child: child);
    if (zen) {
      final mq = MediaQuery.maybeOf(context);
      if (mq != null) {
        body = MediaQuery(
          data: mq.copyWith(disableAnimations: true),
          child: body,
        );
      }
    }
    return body;
  }
}

class _ZenInherited extends InheritedWidget {
  const _ZenInherited({required this.zen, required super.child});
  final bool zen;

  @override
  bool updateShouldNotify(_ZenInherited old) => zen != old.zen;
}
