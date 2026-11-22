import 'package:flutter/material.dart';

import '../layout/window_class.dart';
import 'game_action.dart';
import 'game_keyboard.dart';

/// The body of a game screen with keyboard play: a [GameKeyboard] around [child], and under it the
/// key hints (windows 600 dp and wider) for [hints]. An empty [hints] list shows no hint row.
class KeyedBody extends StatelessWidget {
  const KeyedBody({
    super.key,
    required this.onInput,
    required this.child,
    this.onRelease,
    this.hints = const [],
    this.words = const {},
    this.enabled = true,
  });

  final void Function(GameInput input) onInput;
  final void Function(GameInput input)? onRelease;
  final List<GameAction> hints;

  /// Replaces the short word of a hint (see [KeyHints.words]).
  final Map<GameAction, String> words;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return GameKeyboard(
      onInput: onInput,
      onRelease: onRelease,
      enabled: enabled,
      child: !wide
          ? child
          : Column(
              children: [
                Expanded(child: child),
                if (hints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KeyHints(actions: hints, words: words),
                  ),
              ],
            ),
    );
  }
}
