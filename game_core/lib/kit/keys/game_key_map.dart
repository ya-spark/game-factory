import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'game_action.dart';

/// Keys no one may bind: Escape leaves or cancels, Tab moves the focus, Shift, Control, Alt and
/// Meta are modifiers the browser and the system use.
final Set<LogicalKeyboardKey> reservedKeys = {
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
};

/// The agreed starting keys. Player 1 has the arrows and the right side, player 2 has W A S D and
/// the left side; Space pauses, Q asks the question and Escape leaves for both.
final Map<KeySlot, List<LogicalKeyboardKey>> defaultKeyBindings = {
  const KeySlot(GameAction.left, 1): [LogicalKeyboardKey.arrowLeft],
  const KeySlot(GameAction.right, 1): [LogicalKeyboardKey.arrowRight],
  const KeySlot(GameAction.up, 1): [LogicalKeyboardKey.arrowUp],
  const KeySlot(GameAction.down, 1): [LogicalKeyboardKey.arrowDown],
  const KeySlot(GameAction.action, 1): [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  ],
  const KeySlot(GameAction.pick1, 1): [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.numpad1,
  ],
  const KeySlot(GameAction.pick2, 1): [
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.numpad2,
  ],
  const KeySlot(GameAction.pick3, 1): [
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.numpad3,
  ],
  const KeySlot(GameAction.pick4, 1): [
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.numpad4,
  ],
  const KeySlot(GameAction.left, 2): [LogicalKeyboardKey.keyA],
  const KeySlot(GameAction.right, 2): [LogicalKeyboardKey.keyD],
  const KeySlot(GameAction.up, 2): [LogicalKeyboardKey.keyW],
  const KeySlot(GameAction.down, 2): [LogicalKeyboardKey.keyS],
  const KeySlot(GameAction.action, 2): [LogicalKeyboardKey.keyF],
  const KeySlot(GameAction.pick1, 2): [LogicalKeyboardKey.keyZ],
  const KeySlot(GameAction.pick2, 2): [LogicalKeyboardKey.keyX],
  const KeySlot(GameAction.pick3, 2): [LogicalKeyboardKey.keyC],
  const KeySlot(GameAction.pick4, 2): [LogicalKeyboardKey.keyV],
  const KeySlot(GameAction.pause, 0): [LogicalKeyboardKey.space],
  const KeySlot(GameAction.question, 0): [LogicalKeyboardKey.keyQ],
  const KeySlot(GameAction.exit, 0): [LogicalKeyboardKey.escape],
};

/// What happened when a key was assigned.
class AssignResult {
  const AssignResult._(this.ok, this.reason, this.swappedWith);

  /// The key was assigned.
  const AssignResult.assigned() : this._(true, null, null);

  /// The key was assigned and another slot that used it took this slot's old key.
  const AssignResult.swapped(KeySlot other) : this._(true, null, other);

  /// The key cannot be used (reserved, or the slot cannot be changed).
  const AssignResult.refused(String reason) : this._(false, reason, null);

  final bool ok;
  final String? reason;
  final KeySlot? swappedWith;
}

/// The player's keys: one list of keys per slot, changeable, never two slots on one key and never
/// a slot without a key. Containers load it once and provide it with `GameKeysScope`.
class GameKeyMap extends ChangeNotifier {
  GameKeyMap({Map<KeySlot, List<LogicalKeyboardKey>>? bindings})
    : _keys = {
        for (final e in (bindings ?? defaultKeyBindings).entries)
          e.key: List.of(e.value),
      };

  final Map<KeySlot, List<LogicalKeyboardKey>> _keys;

  /// The keys of [slot] (the first is the one shown).
  List<LogicalKeyboardKey> keysOf(KeySlot slot) =>
      List.unmodifiable(_keys[slot] ?? const []);

  /// The key shown for [slot].
  LogicalKeyboardKey primaryOf(KeySlot slot) => _keys[slot]!.first;

  /// True when [slot] still has its starting keys.
  bool isDefault(KeySlot slot) =>
      listEquals(_keys[slot], defaultKeyBindings[slot]);

  bool get allDefault => KeySlot.all.every(isDefault);

  /// The slot a key press belongs to, or null.
  KeySlot? slotFor(LogicalKeyboardKey key) {
    for (final e in _keys.entries) {
      if (e.value.contains(key)) return e.key;
    }
    return null;
  }

  /// A key press as the game sees it. In a single-player game the second player's keys also work
  /// and report player 1, so either hand can play; with [twoPlayer] they report player 2.
  GameInput? resolve(
    LogicalKeyboardKey key, {
    bool twoPlayer = false,
    bool repeat = false,
  }) {
    final slot = slotFor(key);
    if (slot == null) return null;
    final player = slot.player == 0 ? 1 : (twoPlayer ? slot.player : 1);
    return GameInput(slot.action, player, repeat: repeat);
  }

  /// Gives [slot] the key [key]. When another slot used it, that slot takes [slot]'s old keys, so
  /// no slot is left without a key. Escape (exit) and the reserved keys cannot be used.
  AssignResult assign(KeySlot slot, LogicalKeyboardKey key) {
    if (slot.action == GameAction.exit) {
      return const AssignResult.refused('Escape always leaves.');
    }
    if (reservedKeys.contains(key)) {
      return const AssignResult.refused('That key is kept for the system.');
    }
    final old = _keys[slot]!;
    if (listEquals(old, [key])) return const AssignResult.assigned();
    final other = slotFor(key);
    if (other != null && other != slot) {
      _keys[other] = List.of(old);
    }
    _keys[slot] = [key];
    notifyListeners();
    return other != null && other != slot
        ? AssignResult.swapped(other)
        : const AssignResult.assigned();
  }

  /// Puts every key back to its start.
  void reset() {
    _keys
      ..clear()
      ..addAll({
        for (final e in defaultKeyBindings.entries) e.key: List.of(e.value),
      });
    notifyListeners();
  }

  /// Replaces the keys with saved ones. A bad or incomplete save falls back to the starting keys
  /// for the slots it does not cover, and any key used twice is dropped, so the map stays valid.
  void restore(Map<KeySlot, List<LogicalKeyboardKey>> saved) {
    final used = <LogicalKeyboardKey>{};
    final next = <KeySlot, List<LogicalKeyboardKey>>{};
    for (final slot in KeySlot.all) {
      final keys = (saved[slot] ?? const <LogicalKeyboardKey>[])
          .where(
            (k) =>
                !used.contains(k) &&
                (slot.action == GameAction.exit || !reservedKeys.contains(k)),
          )
          .toList();
      if (keys.isNotEmpty) {
        used.addAll(keys);
        next[slot] = keys;
      }
    }
    for (final slot in KeySlot.all) {
      if (next.containsKey(slot)) continue;
      final defaults = defaultKeyBindings[slot]!
          .where((k) => !used.contains(k))
          .toList();
      next[slot] = defaults.isNotEmpty
          ? defaults
          : [defaultKeyBindings[slot]!.first];
      used.addAll(next[slot]!);
    }
    _keys
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// The saved form: slot id to key ids.
  Map<String, List<int>> toJson() => {
    for (final e in _keys.entries) e.key.id: [for (final k in e.value) k.keyId],
  };

  /// Reads the saved form back (unknown slots and keys are ignored).
  static Map<KeySlot, List<LogicalKeyboardKey>> fromJson(
    Map<String, Object?> json,
  ) {
    final out = <KeySlot, List<LogicalKeyboardKey>>{};
    for (final e in json.entries) {
      final slot = KeySlot.byId(e.key);
      final ids = e.value;
      if (slot == null || ids is! List) continue;
      final keys = <LogicalKeyboardKey>[];
      for (final id in ids) {
        if (id is! int) continue;
        final k = LogicalKeyboardKey.findKeyByKeyId(id);
        if (k != null) keys.add(k);
      }
      if (keys.isNotEmpty) out[slot] = keys;
    }
    return out;
  }
}

/// The words a key shows in a chip and a screen reader reads.
String keyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowLeft) return '←';
  if (key == LogicalKeyboardKey.arrowRight) return '→';
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.numpadEnter) return 'Num Enter';
  if (key == LogicalKeyboardKey.escape) return 'Esc';
  if (key == LogicalKeyboardKey.backspace) return 'Backspace';
  final label = key.keyLabel;
  if (label.isEmpty) return 'Key';
  return label.length == 1 ? label.toUpperCase() : label;
}

/// Spoken names for the arrows (the arrow symbols read badly).
String keySpokenLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowLeft) return 'Left arrow';
  if (key == LogicalKeyboardKey.arrowRight) return 'Right arrow';
  if (key == LogicalKeyboardKey.arrowUp) return 'Up arrow';
  if (key == LogicalKeyboardKey.arrowDown) return 'Down arrow';
  return keyLabel(key);
}
