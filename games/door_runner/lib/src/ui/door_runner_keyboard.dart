import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

/// Wraps the play area and turns the player's keys (the shared key map: `docs/KEYBOARD.md`) into
/// Door runner callbacks: left and right steer, up zaps, down slows while it is held, 1 to 4 pick
/// a door, Enter or Q open the question, Space or Esc pause. Remapped keys work here too.
class DoorRunnerKeyboard extends StatelessWidget {
  const DoorRunnerKeyboard({
    super.key,
    required this.child,
    required this.onLeft,
    required this.onRight,
    required this.onZap,
    required this.onSlow,
    required this.onPause,
    required this.onQuestion,
    required this.onDoor,
  });
  final Widget child;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onZap;
  final void Function(bool held) onSlow;
  final VoidCallback onPause;
  final VoidCallback onQuestion;
  final void Function(int index) onDoor;

  void _input(GameInput i) {
    final n = i.action.pickNumber;
    if (n != null) {
      if (!i.repeat) onDoor(n - 1);
      return;
    }
    switch (i.action) {
      case GameAction.down:
        if (!i.repeat) onSlow(true);
      case GameAction.left:
        if (!i.repeat) onLeft();
      case GameAction.right:
        if (!i.repeat) onRight();
      case GameAction.up:
        if (!i.repeat) onZap();
      case GameAction.pause || GameAction.exit:
        if (!i.repeat) onPause();
      case GameAction.question || GameAction.action:
        if (!i.repeat) onQuestion();
      default:
        break;
    }
  }

  void _release(GameInput i) {
    if (i.action == GameAction.down) onSlow(false);
  }

  @override
  Widget build(BuildContext context) =>
      GameKeyboard(onInput: _input, onRelease: _release, child: child);
}

/// The key hint line under the field (shown on a wide window), with the player's real keys.
class DoorRunnerKeyHints extends StatelessWidget {
  const DoorRunnerKeyHints({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('door_runner.keys'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Center(
        child: KeyHints(
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          words: const {
            GameAction.up: 'zap',
            GameAction.down: 'slow',
            GameAction.pick1: 'pick door',
            GameAction.action: 'question',
          },
          actions: const [
            GameAction.left,
            GameAction.right,
            GameAction.up,
            GameAction.down,
            GameAction.pick1,
            GameAction.pick2,
            GameAction.pick3,
            GameAction.pick4,
            GameAction.action,
            GameAction.pause,
          ],
        ),
      ),
    );
  }
}
