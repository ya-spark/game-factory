import 'package:flutter/material.dart';

import 'game_action.dart';
import 'game_keyboard.dart';
import 'key_labels.dart';

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
    this.spaceGoesOn = false,
    this.shortcuts = const {},
    this.extraHints = const [],
  });

  /// Chips for the fixed keys of [shortcuts]: (key text, word).
  final List<(String, String)> extraHints;

  /// Fixed keys for the screen's own buttons (see [GameKeyboard.shortcuts]).
  final KeyShortcuts shortcuts;

  final void Function(GameInput input) onInput;
  final void Function(GameInput input)? onRelease;
  final List<GameAction> hints;

  /// Replaces the short word of a hint (see [KeyHints.words]).
  final Map<GameAction, String> words;
  final bool enabled;

  /// Space also goes on (see [KeyHints.spaceGoesOn]): pass true on intro, results and Next states.
  final bool spaceGoesOn;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = keyHintsFit(context);
    return GameKeyboard(
      onInput: onInput,
      onRelease: onRelease,
      enabled: enabled,
      shortcuts: shortcuts,
      child: !wide
          ? child
          : Column(
              children: [
                Expanded(child: child),
                if (hints.isNotEmpty || extraHints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KeyHints(
                      actions: hints,
                      words: words,
                      spaceGoesOn: spaceGoesOn,
                      extra: extraHints,
                    ),
                  ),
              ],
            ),
    );
  }
}
