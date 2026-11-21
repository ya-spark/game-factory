import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What a key press means in Door runner.
enum DoorRunnerKey { left, right, zap, slow, pause, question, door }

/// Maps a physical key to its meaning; [doorIndex] is set for the keys 1 to 4. Pure, for tests.
({DoorRunnerKey key, int? doorIndex})? doorRunnerKeyFor(LogicalKeyboardKey k) {
  const digits = [
    [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
    [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
    [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
    [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
  ];
  for (var i = 0; i < digits.length; i++) {
    if (digits[i].contains(k)) return (key: DoorRunnerKey.door, doorIndex: i);
  }
  DoorRunnerKey? m;
  if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
    m = DoorRunnerKey.left;
  } else if (k == LogicalKeyboardKey.arrowRight ||
      k == LogicalKeyboardKey.keyD) {
    m = DoorRunnerKey.right;
  } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
    m = DoorRunnerKey.zap;
  } else if (k == LogicalKeyboardKey.arrowDown ||
      k == LogicalKeyboardKey.keyS) {
    m = DoorRunnerKey.slow;
  } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.escape) {
    m = DoorRunnerKey.pause;
  } else if (k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.keyQ) {
    m = DoorRunnerKey.question;
  }
  return m == null ? null : (key: m, doorIndex: null);
}

/// Wraps the play area and turns keys into callbacks. Slow is "held": [onSlow] gets true on
/// key down and false on key up. It takes the keyboard focus back whenever focus is lost (a
/// tapped button that disappears, a closed dialog), so the keys keep working after a click.
class DoorRunnerKeyboard extends StatefulWidget {
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

  @override
  State<DoorRunnerKeyboard> createState() => _DoorRunnerKeyboardState();
}

class _DoorRunnerKeyboardState extends State<DoorRunnerKeyboard> {
  final FocusNode _node = FocusNode(debugLabel: 'door runner keys');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reclaim());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  void _onFocus() {
    final pf = FocusManager.instance.primaryFocus;
    if (pf == null || pf is FocusScopeNode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reclaim());
    }
  }

  void _reclaim() {
    if (!mounted) return;
    final pf = FocusManager.instance.primaryFocus;
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop && (pf == null || pf is FocusScopeNode)) _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Focus(
      focusNode: _node,
      autofocus: true,
      onKeyEvent: (node, event) {
        final m = doorRunnerKeyFor(event.logicalKey);
        if (m == null) return KeyEventResult.ignored;
        if (m.key == DoorRunnerKey.slow) {
          if (event is KeyRepeatEvent) return KeyEventResult.handled;
          w.onSlow(event is KeyDownEvent);
          return KeyEventResult.handled;
        }
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (m.key) {
          case DoorRunnerKey.left:
            w.onLeft();
          case DoorRunnerKey.right:
            w.onRight();
          case DoorRunnerKey.zap:
            w.onZap();
          case DoorRunnerKey.pause:
            w.onPause();
          case DoorRunnerKey.question:
            w.onQuestion();
          case DoorRunnerKey.door:
            w.onDoor(m.doorIndex!);
          case DoorRunnerKey.slow:
            break;
        }
        return KeyEventResult.handled;
      },
      child: w.child,
    );
  }
}

/// The key hint line under the field, with key caps (hidden on a compact window).
class DoorRunnerKeyHints extends StatelessWidget {
  const DoorRunnerKeyHints({super.key});

  static const _items = <(List<Object>, String)>[
    ([Icons.arrow_back, Icons.arrow_forward], 'move'),
    ([Icons.arrow_upward], 'zap'),
    ([Icons.arrow_downward], 'slow'),
    (['1–4'], 'pick door'),
    (['Enter'], 'question'),
    (['Space'], 'pause'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('door_runner.keys'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (keys, label) in _items) ...[
            for (final k in keys) _KeyCap(k),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  /// A String (letters) or an IconData (arrows).
  final Object label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: label is IconData
          ? Icon(label as IconData, color: Colors.white, size: 15)
          : Text(
              label as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
