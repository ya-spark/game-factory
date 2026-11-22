import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_action.dart';
import 'game_key_map.dart';
import 'game_keys_scope.dart';

/// "Next (Space)": the label of a button with the key that presses it (B-09: every button shows its key).
String withKey(String label, String key) => '$label ($key)';

/// The label of a button that an action key presses, with the player's real key ("Start (Enter)").
/// [alsoSpace]: Space (the shared pause key) goes on too in this state (U2), so both are shown
/// ("Start (Enter / Space)"); pass true on start, Next and results buttons only, never in play.
String keyedLabel(
  BuildContext context,
  String label,
  GameAction action, {
  int player = 1,
  bool alsoSpace = false,
}) {
  final map = GameKeysScope.of(context);
  final key = keyLabel(
    map.primaryOf(KeySlot(action, action.shared ? 0 : player)),
  );
  if (!alsoSpace) return withKey(label, key);
  final space = keyLabel(map.primaryOf(const KeySlot(GameAction.pause, 0)));
  return withKey(label, key == space ? key : '$key / $space');
}

/// A [Text] for a button label with its key, for example `KeyedText('Next', GameAction.action, alsoSpace: true)`.
class KeyedText extends StatelessWidget {
  const KeyedText(
    this.label,
    this.action, {
    super.key,
    this.player = 1,
    this.alsoSpace = false,
    this.style,
  });

  final String label;
  final GameAction action;
  final int player;
  final bool alsoSpace;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    keyedLabel(context, label, action, player: player, alsoSpace: alsoSpace),
    style: style,
    textAlign: TextAlign.center,
  );
}

/// An icon button that also prints its key beside the icon ("X  Esc"), for the small controls over a game.
class KeyedIconButton extends StatelessWidget {
  const KeyedIconButton({
    super.key,
    required this.icon,
    required this.keyName,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  /// The key text printed beside the icon ("Esc", "L").
  final String keyName;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: withKey(tooltip, keyName),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Semantics(
          label: withKey(tooltip, keyName),
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: 4),
              Text(
                keyName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed keys that sit beside the remappable map, for a screen's own buttons (Backspace, H, L, C...).
typedef KeyShortcuts = Map<LogicalKeyboardKey, VoidCallback>;

/// The back arrow of an app bar with its key beside it ("<- Esc"). Give the app bar
/// `leadingWidth: KeyedBackButton.width`.
class KeyedBackButton extends StatelessWidget {
  const KeyedBackButton({
    super.key,
    required this.onPressed,
    this.keyName = 'Esc',
    this.tooltip = 'Back',
    this.icon = Icons.arrow_back,
  });

  final IconData icon;

  static const double width = 96;

  final VoidCallback onPressed;
  final String keyName;
  final String tooltip;

  @override
  Widget build(BuildContext context) => KeyedIconButton(
    icon: icon,
    keyName: keyName,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// The key text of an action in the player's map ("Q"), for icon buttons.
String keyNameOf(BuildContext context, GameAction action, {int player = 1}) =>
    keyLabel(
      GameKeysScope.of(context)
          .primaryOf(KeySlot(action, action.shared ? 0 : player)),
    );
