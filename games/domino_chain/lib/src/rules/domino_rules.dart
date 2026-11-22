/// The row of a chain: slots, placing, swapping and the Go verdict. Pure Dart, no Flutter.
library;

/// What Go finds.
enum DominoVerdictKind {
  /// A slot is still empty: Go is not allowed yet.
  incomplete,

  /// Every slot holds the right step: the chain topples all the way.
  right,

  /// The chain stops at [DominoVerdict.firstWrong].
  wrong,
}

class DominoVerdict {
  const DominoVerdict(this.kind, [this.firstWrong]);
  final DominoVerdictKind kind;

  /// The slot (from 0) of the first domino that is not the next step.
  final int? firstWrong;

  bool get isRight => kind == DominoVerdictKind.right;
}

/// The slots of one chain and the dominoes in the tray. A slot holds a tile index; a tile is in at
/// most one slot. Equal step texts are interchangeable.
class DominoBoard {
  DominoBoard({required this.tiles, required this.steps})
    : assert(tiles.length == steps.length),
      _slots = List<int?>.filled(steps.length, null);

  /// The dominoes as they lie in the tray.
  final List<String> tiles;

  /// The right order.
  final List<String> steps;
  final List<int?> _slots;
  final List<int> _order = [];

  int get slotCount => steps.length;
  int? tileAt(int slot) => _slots[slot];
  bool isPlaced(int tile) => _slots.contains(tile);
  int? slotOf(int tile) {
    final i = _slots.indexOf(tile);
    return i < 0 ? null : i;
  }

  bool get isEmpty => _order.isEmpty;
  bool get isFull => !_slots.contains(null);
  int? get firstEmpty {
    final i = _slots.indexOf(null);
    return i < 0 ? null : i;
  }

  /// The text in [slot], or null when empty.
  String? textAt(int slot) {
    final t = _slots[slot];
    return t == null ? null : tiles[t];
  }

  /// Puts [tile] in [slot] (or the first empty slot when [slot] is null). A tile already there
  /// goes back to the tray; a tile that was in another slot swaps places with it. False when
  /// nothing changed.
  bool place(int tile, {int? slot}) {
    if (tile < 0 || tile >= tiles.length) return false;
    final from = slotOf(tile);
    final target = slot ?? (from == null ? firstEmpty : null);
    if (target == null || target < 0 || target >= slotCount) return false;
    if (from == target) return false;
    final old = _slots[target];
    if (from != null) {
      // Moving a placed domino: swap with whatever is in the target slot.
      _slots[from] = old;
      _slots[target] = tile;
      _order
        ..remove(tile)
        ..add(tile);
      return true;
    }
    if (old != null) _order.remove(old);
    _slots[target] = tile;
    _order.add(tile);
    return true;
  }

  /// Swaps the dominoes of two slots (either may be empty).
  bool swap(int a, int b) {
    if (a == b || a < 0 || b < 0 || a >= slotCount || b >= slotCount) {
      return false;
    }
    final t = _slots[a];
    _slots[a] = _slots[b];
    _slots[b] = t;
    return t != null || _slots[a] != null;
  }

  /// Takes the domino out of [slot]; false when it was empty.
  bool take(int slot) {
    final t = _slots[slot];
    if (t == null) return false;
    _slots[slot] = null;
    _order.remove(t);
    return true;
  }

  /// Takes back the domino placed last (Backspace).
  bool takeLast() {
    if (_order.isEmpty) return false;
    final t = _order.removeLast();
    _slots[_slots.indexOf(t)] = null;
    return true;
  }

  void clear() {
    _slots.fillRange(0, slotCount, null);
    _order.clear();
  }

  /// Puts every domino in its right slot (shown after time ran out).
  void solve() {
    clear();
    final used = <int>{};
    for (var s = 0; s < slotCount; s++) {
      for (var t = 0; t < tiles.length; t++) {
        if (!used.contains(t) && tiles[t] == steps[s]) {
          used.add(t);
          _slots[s] = t;
          _order.add(t);
          break;
        }
      }
    }
  }

  /// What Go finds. With empty slots the verdict is [DominoVerdictKind.incomplete].
  DominoVerdict get verdict {
    if (!isFull) return const DominoVerdict(DominoVerdictKind.incomplete);
    final w = firstWrong;
    return w == null
        ? const DominoVerdict(DominoVerdictKind.right)
        : DominoVerdict(DominoVerdictKind.wrong, w);
  }

  /// The first slot that is empty or holds the wrong step; null when all are right.
  int? get firstWrong {
    for (var i = 0; i < slotCount; i++) {
      if (textAt(i) != steps[i]) return i;
    }
    return null;
  }

  /// The slot a hint lights: the first one that is not right yet.
  int? get hintSlot => firstWrong;

  /// The tray domino that belongs in [hintSlot]: one with that text, preferably not placed.
  int? get hintTile {
    final s = hintSlot;
    if (s == null) return null;
    int? placed;
    for (var t = 0; t < tiles.length; t++) {
      if (tiles[t] != steps[s]) continue;
      if (!isPlaced(t)) return t;
      placed ??= t;
    }
    return placed;
  }

  /// Slots 0 up to (not including) the break: the dominoes that fall.
  int get fallenCount => firstWrong ?? slotCount;
}
