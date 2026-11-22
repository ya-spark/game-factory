/// Bridge builder rules (U3): the gap's slots, stages and scenery. Pure Dart, no Flutter.
/// The sum itself is judged by `equation_builder_rules.dart` (any sum equal to the target is right).
library;

import 'package:game_core/engine/engine.dart';

import 'equation_builder_rules.dart';

/// The three backdrops; a stage uses one.
enum Scenery { river, canyon, sky }

/// How a level plays: slots in the gap, the tiles (shared with the rules), the timer.
class BridgeSettings {
  const BridgeSettings({
    required this.slots,
    required this.equation,
    required this.secondsPerQuestion,
    this.gapsPerStage = 3,
  });

  /// Slots in the gap (a sum is at least 3 of them: number, sign, number).
  final int slots;
  final EquationSettings equation;

  /// 0 means no timer (younger levels and study mode).
  final int secondsPerQuestion;

  /// Gaps to cross before the flag.
  final int gapsPerStage;

  /// Younger: 3 slots, no timer. Older: 5 slots and a gentle timer; [study] never has a timer.
  factory BridgeSettings.forLevel(MiniGameLevel l, {bool study = false}) {
    final eq = EquationSettings.forLevel(l);
    return BridgeSettings(
      slots: l.older ? 5 : 3,
      equation: eq,
      secondsPerQuestion: study ? 0 : eq.secondsPerQuestion,
    );
  }
}

/// Where a round sits in the journey.
class BridgeStage {
  const BridgeStage({
    required this.stage,
    required this.gap,
    required this.gaps,
    required this.endsStage,
    required this.scenery,
  });

  /// Stage number from 0.
  final int stage;

  /// Gap within the stage from 0.
  final int gap;

  /// Gaps in this stage (the last stage may be shorter).
  final int gaps;

  /// True on the last gap of a stage: the character reaches the flag.
  final bool endsStage;
  final Scenery scenery;
}

/// The stage of round [round] (from 0) in a journey of [total] rounds.
BridgeStage bridgeStageFor(int round, int total, {int gapsPerStage = 3}) {
  final stage = round ~/ gapsPerStage;
  final gap = round % gapsPerStage;
  final first = stage * gapsPerStage;
  final gaps = (total - first).clamp(1, gapsPerStage);
  return BridgeStage(
    stage: stage,
    gap: gap,
    gaps: gaps,
    endsStage: gap == gaps - 1 || round == total - 1,
    scenery: Scenery.values[stage % Scenery.values.length],
  );
}

/// Stars at the flag: one for finishing, one for most gaps first go, one for all of them.
int bridgeStageStars({required int firstTry, required int gaps}) {
  if (gaps <= 0) return 0;
  if (firstTry >= gaps) return 3;
  if (firstTry * 2 >= gaps) return 2;
  return 1;
}

enum BridgeVerdict {
  /// Not enough tiles for a sum yet (fewer than number, sign, number).
  tooShort,

  /// The sum equals the target: a plank is laid.
  right,

  /// A sum that does not equal the target: the planks wobble and fall back.
  wrong,
}

/// The slots of one gap and the tiles on the bank. Slots hold tile indexes; a tile is in at most
/// one slot. The sum reads the filled slots left to right.
class BridgeBoard {
  BridgeBoard({required this.tiles, required this.slotCount})
    : _slots = List<int?>.filled(slotCount, null);

  final List<String> tiles;
  final int slotCount;
  final List<int?> _slots;
  final List<int> _order = [];

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

  /// The tiles of the filled slots, in slot order.
  List<String> get tokens => [
    for (final t in _slots)
      if (t != null) tiles[t],
  ];

  /// Puts [tile] in [slot] (a tile already there goes back to the bank), or in the first empty
  /// slot when [slot] is null. False when nothing changed.
  bool place(int tile, {int? slot}) {
    if (tile < 0 || tile >= tiles.length || isPlaced(tile)) return false;
    final target = slot ?? firstEmpty;
    if (target == null || target < 0 || target >= slotCount) return false;
    final old = _slots[target];
    if (old != null) _order.remove(old);
    _slots[target] = tile;
    _order.add(tile);
    return true;
  }

  /// Takes the tile out of [slot]; false when it was empty.
  bool removeSlot(int slot) {
    final t = _slots[slot];
    if (t == null) return false;
    _slots[slot] = null;
    _order.remove(t);
    return true;
  }

  /// Takes back the tile placed last (Backspace).
  bool removeLast() {
    if (_order.isEmpty) return false;
    final t = _order.removeLast();
    _slots[_slots.indexOf(t)] = null;
    return true;
  }

  void clear() {
    _slots.fillRange(0, slotCount, null);
    _order.clear();
  }

  /// Judges the sum. A single number never counts, even when it equals the target: a sum needs a sign.
  BridgeVerdict check(int target) {
    final t = tokens;
    if (t.length < 3) return BridgeVerdict.tooShort;
    return equationHitsTarget(t, target)
        ? BridgeVerdict.right
        : BridgeVerdict.wrong;
  }

  /// What the board does by itself after a tile is placed: a sum that hits the target is right at
  /// once, a full board that misses is wrong, anything else waits (null).
  BridgeVerdict? autoVerdict(int target) {
    final v = check(target);
    if (v == BridgeVerdict.right) return v;
    if (isFull && v == BridgeVerdict.wrong) return v;
    return null;
  }

  /// Screen-reader wording of the sum so far.
  String get spoken => tokens.map(spokenTile).join(' ');
}
