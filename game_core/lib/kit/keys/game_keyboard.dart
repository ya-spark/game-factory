import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_action.dart';
import 'game_key_map.dart';
import 'game_keys_scope.dart';
import 'key_ids.dart';

/// Turns key presses into [GameInput]s for a game, through the player's [GameKeyMap]. Wrap the
/// play area in it. It takes the focus, gets it back after a tap on a button, and lets
/// Ctrl, Alt and Meta shortcuts through to the browser.
///
/// [twoPlayer]: player 2's keys report player 2; otherwise they also work and report player 1.
class GameKeyboard extends StatefulWidget {
  const GameKeyboard({
    super.key,
    required this.child,
    required this.onInput,
    this.onRelease,
    this.twoPlayer = false,
    this.enabled = true,
    this.focusNode,
  });

  final Widget child;

  /// A mapped key went down (or repeats while held).
  final void Function(GameInput input) onInput;

  /// A mapped key came up (for games where holding a key means holding a direction).
  final void Function(GameInput input)? onRelease;

  final bool twoPlayer;

  /// False while a dialog or a text field should have the keys.
  final bool enabled;

  final FocusNode? focusNode;

  @override
  State<GameKeyboard> createState() => _GameKeyboardState();
}

class _GameKeyboardState extends State<GameKeyboard> {
  FocusNode? _own;
  FocusNode get _node =>
      widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'GameKeyboard'));

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _own?.dispose();
    super.dispose();
  }

  /// A button that vanishes or a dialog that closes leaves no focus: take it back, so the keys
  /// keep working without a click. Only while this game is the page on top.
  void _onFocusChange() {
    final pf = FocusManager.instance.primaryFocus;
    if (pf == null || pf is FocusScopeNode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reclaim());
    }
  }

  void _reclaim() {
    if (!mounted || !widget.enabled) return;
    final pf = FocusManager.instance.primaryFocus;
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop && (pf == null || pf is FocusScopeNode)) _node.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final map = GameKeysScope.read(context);
    final input = map.resolve(
      event.logicalKey,
      twoPlayer: widget.twoPlayer,
      repeat: event is KeyRepeatEvent,
    );
    if (input == null) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      widget.onRelease?.call(input);
    } else {
      widget.onInput(input);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // A tap on a button moves the focus to it; take it back so the keys keep working.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) {
        if (mounted && widget.enabled) _node.requestFocus();
      },
      child: Focus(
        focusNode: _node,
        autofocus: true,
        onKeyEvent: _onKey,
        child: widget.child,
      ),
    );
  }
}

/// A row of key-cap chips with a short word each, for the foot of a game ("← →  move", "1-4  answer").
/// Shows the keys the player really has, so a remapped key reads right.
class KeyHints extends StatelessWidget {
  const KeyHints({
    super.key,
    required this.actions,
    this.player = 1,
    this.style,
    this.words = const {},
  });

  /// Replaces the short word of an action (Door runner says "zap" for up and "slow" for down).
  final Map<GameAction, String> words;

  /// The actions to show, in order.
  final List<GameAction> actions;
  final int player;
  final TextStyle? style;

  static String _word(GameAction a) => switch (a) {
    GameAction.left || GameAction.right => 'move',
    GameAction.up => 'select',
    GameAction.down => 'best',
    GameAction.action => 'go',
    GameAction.pause => 'pause',
    GameAction.question => 'question',
    GameAction.exit => 'exit',
    _ => 'answer',
  };

  @override
  Widget build(BuildContext context) {
    final map = GameKeysScope.of(context);
    final theme = Theme.of(context);
    final base =
        style ?? theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    // Left and right read as one pair; the four answers as one range.
    final shown = <(String, String, GameAction)>[];
    bool has(GameAction a) => actions.contains(a);
    String key(GameAction a) =>
        keyLabel(map.primaryOf(KeySlot(a, a.shared ? 0 : player)));
    for (final a in actions) {
      if (a == GameAction.right && has(GameAction.left)) {
        continue;
      }
      final laterPick =
          a.pickNumber != null &&
          a != GameAction.pick1 &&
          has(GameAction.pick1);
      if (laterPick) {
        continue;
      }
      if (a == GameAction.left && has(GameAction.right)) {
        shown.add((
          '${key(GameAction.left)} ${key(GameAction.right)}',
          words[GameAction.left] ?? 'move',
          a,
        ));
      } else if (a == GameAction.pick1 && has(GameAction.pick4)) {
        shown.add((
          '${key(GameAction.pick1)}-${key(GameAction.pick4)}',
          words[GameAction.pick1] ?? 'answer',
          a,
        ));
      } else {
        shown.add((key(a), words[a] ?? _word(a), a));
      }
    }
    return Wrap(
      key: KeyIds.hints,
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (k, w, a) in shown)
          Row(
            key: KeyIds.hint(a),
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyCap(label: k),
              const SizedBox(width: 6),
              Text(
                w,
                style: base.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
      ],
    );
  }
}

/// One key-cap chip.
class KeyCap extends StatelessWidget {
  const KeyCap({
    super.key,
    required this.label,
    this.highlight = false,
    this.accent,
  });

  final String label;

  /// Draws the chip as the one waiting for a key.
  final bool highlight;

  /// Overrides the outline colour (player 2 uses a second colour).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final outline = highlight ? cs.tertiary : (accent ?? cs.outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? cs.tertiary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outline, width: highlight ? 2 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: highlight ? cs.onTertiary : cs.onSurface,
        ),
      ),
    );
  }
}
