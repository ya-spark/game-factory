/// Blockfall, versus: two wells played side by side, the same pieces for both, garbage rows sent
/// to the other well. Pure Dart, no Flutter. Each well is a [BlockfallGame]; this adds the garbage,
/// the clock that raises the level and the winner. Power-ups, prisms and the special blocks are
/// off. Nothing here touches a profile or a score: a versus game records no progress.
library;

import 'dart:math';

import 'bag.dart';
import 'blockfall_game.dart';
import 'events.dart';
import 'powerups.dart';

/// Garbage rows a clear sends: a single none, a double 1, a triple 2, a quad 4, and a back-to-back
/// quad one more.
int garbageForLines(int lines, {bool backToBack = false}) => switch (lines) {
  2 => 1,
  3 => 2,
  4 => backToBack ? 5 : 4,
  _ => 0,
};

/// Seconds of play between level rises.
const double versusLevelSeconds = 45;

class BlockfallVersus {
  /// [bagFor] makes each well's piece bag (tests pass a fixed sequence); the default is the same
  /// seeded 7-bag for both.
  BlockfallVersus({required int seed, PieceBag Function()? bagFor})
    : _hole = Random(seed ^ 0x6a3d),
      _g1 = _wellFor(seed, bagFor),
      _g2 = _wellFor(seed, bagFor) {
    forceLevels();
  }

  /// One well: the same seed gives the same piece order, no best-fit helper, no special blocks
  /// and no power-up stock, so luck is equal and the rules are plain.
  static BlockfallGame _wellFor(int seed, PieceBag Function()? bagFor) =>
      BlockfallGame(
        random: Random(seed),
        bag: bagFor?.call() ?? PieceBag(Random(seed)),
        adaptive: false,
        prismInterval: 0,
        boomInterval: 0,
        goldInterval: 0,
        stock: {for (final t in PowerUpType.values) t: 0},
      );

  final Random _hole;
  final BlockfallGame _g1;
  final BlockfallGame _g2;
  final Map<int, int> _pending = {1: 0, 2: 0};
  double _elapsed = 0;
  bool _paused = false;
  bool _decided = false;

  /// Player 1's well is [game] 1, player 2's is 2.
  BlockfallGame game(int player) => player == 1 ? _g1 : _g2;

  /// Garbage rows waiting to rise in [player]'s well (they arrive after the player's next lock).
  int pendingFor(int player) => _pending[player]!;

  double get elapsed => _elapsed;
  bool get paused => _paused;

  /// The level both wells fall at: 1, +1 every [versusLevelSeconds] of play.
  int get level => 1 + _elapsed ~/ versusLevelSeconds;

  /// 1 or 2, or 0 for a draw; null while both are still playing.
  int? get winner {
    final a = _g1.isGameOver, b = _g2.isGameOver;
    if (!a && !b) return null;
    if (a && b) return 0;
    return a ? 2 : 1;
  }

  bool get isOver => winner != null;

  void forceLevels() {
    _g1.forcedLevel = level;
    _g2.forcedLevel = level;
  }

  void pause() {
    _paused = true;
    _g1.isPaused = true;
    _g2.isPaused = true;
  }

  void resume() {
    _paused = false;
    _g1.isPaused = false;
    _g2.isPaused = false;
  }

  bool get _live => !_paused && !_decided;

  // ---- input, one method per command; each settles the garbage afterwards ----

  bool moveLeft(int p) => _live && _then(p, game(p).moveLeft());
  bool moveRight(int p) => _live && _then(p, game(p).moveRight());
  bool rotate(int p) => _live && _then(p, game(p).rotate());
  bool hold(int p) => _live && _then(p, game(p).hold());

  void softDrop(int p, bool on) {
    if (_live || !on) game(p).softDrop(on);
  }

  /// Drops [p]'s piece at once; returns the rows dropped.
  int hardDrop(int p) {
    if (!_live) return 0;
    final rows = game(p).hardDrop();
    _settle(p);
    return rows;
  }

  bool _then(int p, bool moved) {
    _settle(p);
    return moved;
  }

  /// Advances both wells by [dt] seconds of play.
  void tick(double dt) {
    if (!_live || dt <= 0) return;
    _elapsed += dt;
    forceLevels();
    _g1.tick(dt);
    _g2.tick(dt);
    _settle(1);
    _settle(2);
  }

  // ---- garbage ----

  /// Reads what happened in [p]'s well since the last look: a clear first cancels the garbage
  /// waiting for [p], then sends the rest to the other player; a lock with no clear lets the
  /// waiting garbage rise.
  void _settle(int p) {
    if (_decided) return;
    final events = game(p).drainEvents();
    var locked = false;
    var send = 0;
    for (final e in events) {
      if (e is PieceLocked) locked = true;
      if (e is LinesCleared) {
        send += garbageForLines(e.rows.length, backToBack: e.backToBack);
      }
    }
    if (send > 0) {
      final cancel = min(send, _pending[p]!);
      _pending[p] = _pending[p]! - cancel;
      send -= cancel;
      if (send > 0) {
        final other = p == 1 ? 2 : 1;
        _pending[other] = _pending[other]! + send;
      }
    }
    if (locked && _pending[p]! > 0) {
      final n = _pending[p]!;
      _pending[p] = 0;
      game(p).receiveGarbage(n, _hole.nextInt(10));
    }
    if (_g1.isGameOver || _g2.isGameOver) _decided = true;
  }
}
