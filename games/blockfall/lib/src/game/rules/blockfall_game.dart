import 'dart:math';

import 'active_piece.dart';
import 'bag.dart';
import 'events.dart';
import 'fit.dart';
import 'gravity.dart';
import 'piece_type.dart';
import 'powerups.dart';
import 'scoring.dart';
import 'well.dart';

/// Complete, deterministic Blockfall rules engine.
///
/// Pure Dart. Randomness comes from the injected [Random], time from the delta seconds
/// passed to [tick]. The UI/Flame layer calls the input methods, calls [tick] every frame,
/// reads the getters to draw, and consumes [drainEvents] for sounds/stats/retention.
class BlockfallGame {
  BlockfallGame({
    Random? random,
    Random? prismRandom,
    Random? fitRandom,
    PieceBag? bag,
    bool? adaptive,

    /// Lines already cleared at the start (tests use it to begin at a higher level).
    int startLines = 0,
    Well? well,
    Map<PowerUpType, int>? stock,
    this.prismInterval = prismEveryNthPiece,
    this.boomInterval = boomEveryNthPiece,
    this.goldInterval = goldEveryNthPiece,
    Random? specialRandom,
  }) : _random = prismRandom ?? random ?? Random(0),
       _specialRandom = specialRandom ?? Random(0xb00),
       _bag = bag ?? PieceBag(random ?? Random(0)),
       _fitRandom = fitRandom ?? Random(0xf17),
       // A fixed test sequence stays untouched unless adaptive is asked for.
       _adaptive = adaptive ?? bag == null,
       _lines = startLines,
       well = well ?? Well() {
    for (final t in PowerUpType.values) {
      _stock[t] = stock?[t] ?? 1;
      _uses[t] = 0;
    }
    _refillQueue();
    _spawn(_popQueue());
  }

  /// Deterministic game: the seed fixes bag order and prism placement.
  factory BlockfallGame.seeded(
    int seed, {
    int startLines = 0,
    Well? well,
    Map<PowerUpType, int>? stock,
  }) => BlockfallGame(
    random: Random(seed),
    prismRandom: Random(seed ^ 0x5eed),
    specialRandom: Random(seed ^ 0xb00),
    fitRandom: Random(seed ^ 0xf17),
    startLines: startLines,
    well: well,
    stock: stock,
  );

  /// The running game as JSON for the autosave: well, queue, hold, score, timers and stats.
  /// The falling piece is saved with its position. Not meaningful once the game is over.
  Map<String, Object?> toJson() {
    final a = _active;
    return {
      'well': {
        'colors': well.colorList,
        'kinds': [for (final k in well.kindList) k.index],
      },
      'queue': [for (final s in _queue) _specToJson(s)],
      'pool': [for (final t in _pool) t.index],
      'generated': _generated,
      'hold': _hold == null ? null : _specToJson(_hold!),
      'canHold': _canHold,
      if (a != null)
        'active': {
          'spec': a.spec == null ? null : _specToJson(a.spec!),
          'rotation': a.rotation,
          'col': a.col,
          'row': a.row,
        },
      'score': _score,
      'lines': _lines,
      'combo': _combo,
      'lastWasQuad': _lastWasQuad,
      'prismCoins': _prismCoins,
      'revivesUsed': _revivesUsed,
      'adRefills': _adRefills,
      'slowRemaining': _slowRemaining,
      'rushRemaining': _rushRemaining,
      'piecesPlaced': piecesPlaced,
      'maxCombo': maxCombo,
      'quads': quads,
      'prismRowsCleared': prismRowsCleared,
      'holdsUsed': holdsUsed,
      'perfectClears': perfectClears,
      'uses': {for (final e in _uses.entries) e.key.name: e.value},
    };
  }

  /// Rebuilds a game saved by [toJson]; [stock] is the player's current power-up stock.
  /// Returns null when [j] is unusable (a bad save starts a fresh game instead).
  static BlockfallGame? restore(
    Map<String, Object?> j, {
    required Map<PowerUpType, int> stock,
  }) {
    try {
      final w = j['well']! as Map;
      final well = Well.restore(
        [for (final c in w['colors']! as List) (c as num).toInt()],
        [
          for (final k in w['kinds']! as List)
            CellKind.values[(k as num).toInt()],
        ],
      );
      final g = BlockfallGame(
        random: Random(),
        specialRandom: Random(),
        fitRandom: Random(),
        well: well,
        stock: stock,
      );
      g._queue
        ..clear()
        ..addAll([
          for (final s in j['queue']! as List) _specFromJson(s as Map),
        ]);
      g._pool
        ..clear()
        ..addAll([
          for (final t in j['pool']! as List)
            PieceType.values[(t as num).toInt()],
        ]);
      g._generated = (j['generated']! as num).toInt();
      final hold = j['hold'];
      g._hold = hold == null ? null : _specFromJson(hold as Map);
      g._canHold = j['canHold']! as bool;
      g._score = (j['score']! as num).toInt();
      g._lines = (j['lines']! as num).toInt();
      g._combo = (j['combo']! as num).toInt();
      g._lastWasQuad = j['lastWasQuad']! as bool;
      g._prismCoins = (j['prismCoins']! as num).toInt();
      g._revivesUsed = (j['revivesUsed']! as num).toInt();
      g._adRefills = (j['adRefills']! as num).toInt();
      g._slowRemaining = (j['slowRemaining']! as num).toDouble();
      g._rushRemaining = (j['rushRemaining']! as num).toDouble();
      g.piecesPlaced = (j['piecesPlaced']! as num).toInt();
      g.maxCombo = (j['maxCombo']! as num).toInt();
      g.quads = (j['quads']! as num).toInt();
      g.prismRowsCleared = (j['prismRowsCleared']! as num).toInt();
      g.holdsUsed = (j['holdsUsed']! as num).toInt();
      g.perfectClears = (j['perfectClears']! as num).toInt();
      final uses = j['uses']! as Map;
      for (final t in PowerUpType.values) {
        g._uses[t] = (uses[t.name] as num?)?.toInt() ?? 0;
      }
      final a = j['active']! as Map;
      final spec = a['spec'];
      final active = spec == null
          ? ActivePiece.bomb(
              row: (a['row']! as num).toInt(),
              col: (a['col']! as num).toInt(),
            )
          : ActivePiece(
              spec: _specFromJson(spec as Map),
              rotation: (a['rotation']! as num).toInt() % 4,
              col: (a['col']! as num).toInt(),
              row: (a['row']! as num).toInt(),
            );
      // The constructor spawned a fresh piece; replace it with the saved one.
      g._gameOver = false;
      g._gameOverReason = null;
      g._pendingSpawn = null;
      if (!g._fits(active)) return null;
      g._active = active;
      g._fallAcc = 0;
      g._lockTimer = 0;
      g._restarts = 0;
      g._lowestRow = g._bottomRow(active);
      g._refillQueue();
      g._events.clear();
      return g;
    } on Object {
      return null;
    }
  }

  static Map<String, Object?> _specToJson(PieceSpec s) => {
    't': s.type.index,
    if (s.prismCell != null) 'p': s.prismCell,
    if (s.boomCell != null) 'b': s.boomCell,
    if (s.goldCell != null) 'g': s.goldCell,
  };

  static PieceSpec _specFromJson(Map m) => PieceSpec(
    PieceType.values[(m['t']! as num).toInt()],
    prismCell: (m['p'] as num?)?.toInt(),
    boomCell: (m['b'] as num?)?.toInt(),
    goldCell: (m['g'] as num?)?.toInt(),
  );

  static const int nextCount = 3;

  /// Every n-th piece carries one prism cell (0 disables prisms).
  final int prismInterval;

  /// Every n-th piece carries one Boom block cell / one golden cell (0 disables).
  final int boomInterval;
  final int goldInterval;

  /// Draws the prism cell; separate from the bag so prisms never change the bag order.
  final Random _random;

  /// Draws the cell of a Boom or golden block (also separate from the bag).
  final Random _specialRandom;
  final PieceBag _bag;
  final Random _fitRandom;
  final bool _adaptive;

  /// Pieces of the current bag not yet in the queue, in bag order.
  final List<PieceType> _pool = [];

  /// The playfield (read for drawing; tests and debug hooks may preload it).
  final Well well;

  final List<PieceSpec> _queue = [];
  final List<GameEvent> _events = [];
  final Map<PowerUpType, int> _stock = {};
  final Map<PowerUpType, int> _uses = {};

  int _generated = 0;
  ActivePiece? _active;
  PieceSpec? _hold;
  PieceSpec? _pendingSpawn;
  bool _canHold = true;

  int _score = 0;
  int _lines;
  int _combo = 0;
  bool _lastWasQuad = false;
  int _prismCoins = 0;

  double _fallAcc = 0;
  double _lockTimer = 0;
  int _restarts = 0;
  int _lowestRow = 0;
  bool _soft = false;
  bool _gameOver = false;
  GameOverReason? _gameOverReason;
  int _revivesUsed = 0;
  bool _softLatchedOff = false;
  int _adRefills = 0;
  double _slowRemaining = 0;
  double _rushRemaining = 0;

  // Statistics for GameSummary / challenges / achievements.
  int piecesPlaced = 0;
  int maxCombo = 0;
  int quads = 0;
  int prismRowsCleared = 0;
  int holdsUsed = 0;
  int perfectClears = 0;

  // ---------------------------------------------------------------- read state

  int get score => _score;
  int get lines => _lines;
  int get level => levelForLines(_lines);

  /// Lines still needed to reach the next level.
  int get goal => goalForLines(_lines);

  /// Consecutive clearing locks (0 after a lock without a clear).
  int get combo => _combo;
  bool get backToBackReady => _lastWasQuad;
  int get coinsFromPrisms => _prismCoins;

  bool get isGameOver => _gameOver;
  GameOverReason? get gameOverReason => _gameOverReason;
  bool get canRevive => _gameOver && revivesRemaining > 0;
  bool get reviveUsed => _revivesUsed > 0;
  int get revivesUsed => _revivesUsed;

  /// Ad revives left in this run (resets with every new game instance).
  int get revivesRemaining => PowerUpRules.maxRevivesPerRun - _revivesUsed;

  /// Pausing stops gravity, the lock timer, Slow and all input.
  bool isPaused = false;

  /// The falling piece, or null when the game is over.
  ActivePiece? get currentPiece => _active;

  /// Where the falling piece would land (same rotation and column), or null.
  ActivePiece? get ghostPiece {
    final a = _active;
    if (a == null) return null;
    return _dropped(a);
  }

  PieceSpec? get holdPiece => _hold;
  bool get canHold => _canHold && !_gameOver && !(_active?.isBomb ?? false);

  /// The next 3 pieces (always full).
  List<PieceSpec> get next => List.unmodifiable(_queue.take(nextCount));

  /// The whole upcoming queue (the Next pieces).
  List<PieceSpec> get upcoming => List.unmodifiable(_queue);

  /// Current seconds per row including a Slow power-up.
  double get secondsPerRow =>
      secondsPerRowForLevel(level) * (slowActive ? PowerUpRules.slowFactor : 1);

  /// Gold Rush: seconds of play time left (0 when off).
  double get rushRemaining => _rushRemaining;
  bool get rushActive => _rushRemaining > 0;

  bool get slowActive => _slowRemaining > 0;
  double get slowRemaining => _slowRemaining;
  bool get isSoftDropping => _soft;

  /// Seconds left on the lock timer of a resting piece.
  double get lockTimeLeft => lockDelaySeconds - _lockTimer;
  int get lockRestartsUsed => _restarts;

  int stock(PowerUpType t) => _stock[t]!;
  int usesThisGame(PowerUpType t) => _uses[t]!;
  int get adRefillsUsed => _adRefills;
  int get adRefillsLeft => PowerUpRules.maxAdRefillsPerGame - _adRefills;

  /// Cells of the well plus the falling piece as a color grid (for quick rendering/bots).
  int cellColor(int row, int col) => well.colorAt(row, col);

  /// Returns and clears the events recorded since the last call.
  List<GameEvent> drainEvents() {
    final out = List<GameEvent>.of(_events);
    _events.clear();
    return out;
  }

  // -------------------------------------------------------------------- input

  bool get _canAct => !_gameOver && !isPaused && _active != null;

  bool moveLeft() => _shift(-1);
  bool moveRight() => _shift(1);

  bool _shift(int dCol) {
    if (!_canAct) return false;
    final moved = _active!.shifted(dCol, 0);
    if (!_fits(moved)) return false;
    _active = moved;
    _afterSuccessfulMove();
    _events.add(const PieceMoved());
    return true;
  }

  /// Rotates clockwise with the kick order (0,0) (-1,0) (+1,0) (0,-1) (-2,0) (+2,0).
  bool rotate() {
    if (!_canAct) return false;
    final a = _active!;
    if (a.isBomb || a.type == PieceType.cube) return false;
    final turned = a.rotatedClockwise();
    const kicks = [(0, 0), (-1, 0), (1, 0), (0, -1), (-2, 0), (2, 0)];
    for (final (dx, dy) in kicks) {
      final c = turned.shifted(dx, dy);
      if (_fits(c)) {
        _active = c;
        _afterSuccessfulMove();
        _events.add(const PieceRotated());
        return true;
      }
    }
    return false;
  }

  /// Holds soft drop on or off (falls at 20x gravity, +1 point per row).
  ///
  /// The drop is latched to the current piece: once it locks (or is held away) the soft drop
  /// switches off and stays off until the caller releases it with `softDrop(false)`, so a
  /// long swipe never drags the next piece down.
  void softDrop(bool active) {
    if (!active) {
      _softLatchedOff = false;
      _soft = false;
    } else if (!_softLatchedOff) {
      _soft = true;
    }
  }

  /// Drops to the ghost position and locks at once (+2 per row). Returns rows dropped.
  int hardDrop() {
    if (!_canAct) return 0;
    final a = _active!;
    final landed = _dropped(a);
    final rows = landed.row - a.row;
    if (!a.isBomb) _score += hardDropPointsPerRow * rows;
    _active = landed;
    _events.add(HardDropped(rows));
    _lock();
    return rows;
  }

  /// Hold, once per piece. Returns false when ignored.
  bool hold() {
    if (!_canAct || !canHold) return false;
    final current = _active!.spec!;
    final held = _hold;
    _hold = current;
    _canHold = false;
    holdsUsed++;
    _latchSoftOff();
    _events.add(const HoldUsed());
    _spawn(held ?? _popQueue());
    return true;
  }

  /// Advances game time by [dt] seconds (ignored while paused or after game over).
  void tick(double dt) {
    if (dt <= 0 || isPaused || _gameOver) return;
    var remaining = dt;
    while (remaining > 0 && !_gameOver) {
      // Split at the end of Slow so the gravity change applies at the right moment.
      var chunk = remaining;
      var slowEnds = false;
      var rushEnds = false;
      if (_slowRemaining > 0 && _slowRemaining <= chunk) {
        chunk = _slowRemaining;
        slowEnds = true;
      }
      // Split at the end of Gold Rush too, so a clear is doubled exactly while it runs.
      if (_rushRemaining > 0 && _rushRemaining <= chunk) {
        chunk = _rushRemaining;
        rushEnds = true;
        slowEnds = _slowRemaining > 0 && _slowRemaining <= chunk;
      }
      _advance(chunk);
      if (_slowRemaining > 0) _slowRemaining -= chunk;
      if (slowEnds || _slowRemaining < 1e-9) _slowRemaining = 0;
      if (_rushRemaining > 0) _rushRemaining -= chunk;
      if (rushEnds || _rushRemaining < 1e-9) _rushRemaining = 0;
      remaining -= chunk;
    }
  }

  // ---------------------------------------------------------------- power-ups

  /// Uses a power-up from the stock. Refused uses cost nothing.
  PowerUpResult usePowerUp(PowerUpType type) {
    if (!_canAct) return PowerUpResult.notAllowed;
    if (_uses[type]! >= PowerUpRules.maxUsesPerTypePerGame) {
      return PowerUpResult.limitReached;
    }
    if (_stock[type]! <= 0) return PowerUpResult.noStock;
    switch (type) {
      case PowerUpType.sweep:
        _sweep();
      case PowerUpType.slow:
        if (slowActive) return PowerUpResult.alreadyActive;
        _slowRemaining = PowerUpRules.slowSeconds;
      case PowerUpType.bomb:
        if (_active!.isBomb) return PowerUpResult.notAllowed;
        _makeBomb();
    }
    _stock[type] = _stock[type]! - 1;
    _uses[type] = _uses[type]! + 1;
    _events.add(PowerUpUsed(type));
    return PowerUpResult.ok;
  }

  /// Adds stock (coin purchase or rewarded ad); the UI deducts coins itself.
  void addStock(PowerUpType type, [int n = 1]) {
    if (n > 0) _stock[type] = _stock[type]! + n;
  }

  /// Rewarded-ad refill: +1 of [type], at most 3 per game. Returns false when used up.
  bool refillWithAd(PowerUpType type) {
    if (_adRefills >= PowerUpRules.maxAdRefillsPerGame) return false;
    _adRefills++;
    addStock(type);
    return true;
  }

  /// Revive (up to [PowerUpRules.maxRevivesPerRun] per run) after game over: clears the top 8 rows, spawns the next piece.
  bool revive() {
    if (!canRevive) return false;
    _revivesUsed++;
    _gameOver = false;
    _gameOverReason = null;
    well.clearRowRange(0, PowerUpRules.reviveClearRows);
    _events.add(const Revived());
    final pending = _pendingSpawn;
    _pendingSpawn = null;
    _spawn(pending ?? _popQueue());
    return true;
  }

  // ----------------------------------------------------------------- internals

  void _sweep() {
    final total = Well.totalRows;
    well.removeRows([
      for (var i = 0; i < PowerUpRules.sweepRows; i++) total - 1 - i,
    ]);
    _addLines(PowerUpRules.sweepRows);
    // The stack moved down; lift the falling piece if it now overlaps something.
    var a = _active!;
    var guard = 0;
    while (!_fits(a) && guard++ < Well.totalRows) {
      a = a.shifted(0, -1);
    }
    _active = a;
    _lockTimer = 0;
  }

  void _makeBomb() {
    final cells = _active!.cells;
    var best = cells.first;
    final minCol = cells.map((c) => c.col).reduce(min);
    final maxCol = cells.map((c) => c.col).reduce(max);
    final center = minCol + (maxCol - minCol) ~/ 2;
    for (final c in cells) {
      final better =
          c.row < best.row ||
          (c.row == best.row &&
              (c.col - center).abs() < (best.col - center).abs());
      if (better) best = c;
    }
    _active = ActivePiece.bomb(row: best.row, col: best.col);
    _fallAcc = 0;
    _lockTimer = 0;
    _lowestRow = best.row;
  }

  void _addLines(int n) {
    final before = level;
    _lines += n;
    if (level > before) _events.add(LevelUp(level));
  }

  bool _fits(ActivePiece p) {
    for (final c in p.cells) {
      if (!Well.inBounds(c.row, c.col) || well.isFilled(c.row, c.col)) {
        return false;
      }
    }
    return true;
  }

  bool _grounded() => !_fits(_active!.shifted(0, 1));

  ActivePiece _dropped(ActivePiece a) {
    var p = a;
    while (_fits(p.shifted(0, 1))) {
      p = p.shifted(0, 1);
    }
    return p;
  }

  int _bottomRow(ActivePiece p) => p.cells.map((c) => c.row).reduce(max);

  void _afterSuccessfulMove() {
    if (_grounded()) {
      if (_restarts < maxLockRestarts) {
        _restarts++;
        _lockTimer = 0;
      }
    } else {
      _lockTimer = 0;
    }
  }

  void _advance(double dt) {
    var remaining = dt;
    const eps = 1e-9;
    while (remaining > eps && !_gameOver && _active != null) {
      if (_grounded()) {
        final need = lockDelaySeconds - _lockTimer;
        if (remaining + eps >= need) {
          remaining -= need;
          _lock();
        } else {
          _lockTimer += remaining;
          remaining = 0;
        }
      } else {
        _lockTimer = 0;
        final step = _soft ? softDropStep(secondsPerRow) : secondsPerRow;
        final need = step - _fallAcc;
        if (remaining + eps >= need) {
          remaining -= need;
          _fallAcc = 0;
          _active = _active!.shifted(0, 1);
          if (_soft && !_active!.isBomb) _score += softDropPointsPerRow;
          final bottom = _bottomRow(_active!);
          if (bottom > _lowestRow) {
            _lowestRow = bottom;
            _restarts = 0;
          }
        } else {
          _fallAcc += remaining;
          remaining = 0;
        }
      }
    }
  }

  void _lock() {
    _latchSoftOff();
    final p = _active!;
    _active = null;
    _canHold = true;
    if (p.isBomb) {
      _explode(p);
      _spawn(_popQueue());
      return;
    }
    final cells = p.cells;
    for (final c in cells) {
      well.set(c.row, c.col, p.type!.colorId, kind: c.kind);
    }
    piecesPlaced++;
    final hidden = cells.every((c) => c.row < Well.hiddenRows);
    _events.add(PieceLocked(hidden: hidden));
    if (hidden) {
      _endGame(GameOverReason.lockOut);
      return;
    }
    final full = [
      for (var r = 0; r < Well.totalRows; r++)
        if (well.isRowFull(r)) r,
    ];
    if (full.isEmpty) {
      _combo = 0;
      _lastWasQuad = false;
    } else {
      _clearRows(full);
    }
    _spawn(_popQueue());
  }

  void _explode(ActivePiece bomb) {
    final r0 = bomb.row, c0 = bomb.col;
    const k = PowerUpRules.bombRadius;
    for (var r = r0 - k; r <= r0 + k; r++) {
      for (var c = c0 - k; c <= c0 + k; c++) {
        if (Well.inBounds(r, c)) well.clearCell(r, c);
      }
    }
    _events.add(BombExploded(centerRow: r0, centerCol: c0));
  }

  void _clearRows(List<int> rows) {
    final n = rows.length;
    final lvl = level; // before any level-up from this clear
    var prismRows = 0;
    var prismCells = 0;
    var golds = 0;
    final booms = <(int, int)>[];
    for (final r in rows) {
      final p = well.prismCountInRow(r);
      if (p > 0) prismRows++;
      prismCells += p;
      golds += well.countKindInRow(r, CellKind.gold);
      for (var c = 0; c < Well.cols; c++) {
        if (well.kindAt(r, c) == CellKind.boom) booms.add((r, c));
      }
    }
    // Boom blocks blast the 3x3 area around them (like the Boom power-up: nothing falls
    // because of the blast, rows it fills are not cleared). Cells of the cleared rows go
    // anyway; blasted cells have no effect of their own except prisms, which still pay.
    final blasted = <(int, int)>{};
    for (final (br, bc) in booms) {
      for (var r = br - 1; r <= br + 1; r++) {
        for (var c = bc - 1; c <= bc + 1; c++) {
          if (Well.inBounds(r, c) && well.isFilled(r, c) && !rows.contains(r)) {
            blasted.add((r, c));
          }
        }
      }
    }
    for (final (r, c) in blasted) {
      if (well.prismAt(r, c)) prismCells++;
      well.clearCell(r, c);
    }
    final blastCells =
        [for (final (r, c) in blasted) (r + rows.where((x) => x > r).length, c)]
          ..sort(
            (a, b) =>
                a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
          );
    final doubled = rushActive;
    _combo++;
    if (_combo > maxCombo) maxCombo = _combo;
    final b2b = n == 4 && _lastWasQuad;
    var gain = lineClearScore(
      rows: n,
      prismRows: prismRows,
      level: lvl,
      backToBack: b2b,
    );
    gain += comboBonus(combo: _combo, level: lvl);
    well.removeRows(rows);
    final perfect = well.isEmpty;
    if (perfect) {
      gain += perfectClearBonus * lvl;
      perfectClears++;
    }
    // Gold Rush doubles line, combo, back-to-back and perfect-clear scores. The clear that
    // brings the golden block is not doubled itself unless a rush is already running.
    if (doubled) gain *= rushMultiplier;
    gain += blastCellPoints * lvl * blasted.length;
    if (golds > 0) {
      _rushRemaining = rushActive
          ? min(_rushRemaining + rushSeconds * golds, rushCapSeconds)
          : min(rushSeconds * golds, rushCapSeconds);
    }
    _score += gain;
    _lastWasQuad = n == 4;
    if (n == 4) quads++;
    prismRowsCleared += prismRows;
    final coins = min(prismCells, prismCoinCapPerGame - _prismCoins);
    _prismCoins += coins;
    _events.add(
      LinesCleared(
        rows: rows,
        prismRows: prismRows,
        prismCoins: coins,
        scoreGained: gain,
        combo: _combo,
        backToBack: b2b,
        perfectClear: perfect,
        blastCells: blastCells,
        goldBlocks: golds,
        rushDoubled: doubled,
      ),
    );
    if (coins > 0) _events.add(PrismCoinsEarned(coins));
    _addLines(n);
  }

  void _latchSoftOff() {
    if (_soft) _softLatchedOff = true;
    _soft = false;
  }

  void _endGame(GameOverReason reason) {
    _gameOver = true;
    _gameOverReason = reason;
    _soft = false;
    _events.add(GameOver(reason));
  }

  /// Keeps the Next queue full. Each piece is chosen when it enters the queue, from the
  /// unused pieces of the current bag: the best fit for the well with probability
  /// [fitProbability] of the level, otherwise the next piece in bag order.
  void _refillQueue() {
    while (_queue.length < nextCount) {
      if (_pool.isEmpty) _pool.addAll(_bag.nextBag());
      var i = 0;
      if (_adaptive && _pool.length > 1) {
        final p = fitProbability(level);
        if (p >= 1 || (p > 0 && _fitRandom.nextDouble() < p)) {
          i = bestFitIndex(well, _pool);
        }
      }
      final t = _pool.removeAt(i);
      // One special cell at most: gold, then boom, then prism. The prism draw happens
      // whenever a prism is due, so prism placement never depends on the other kinds.
      int? prism;
      if (prismInterval > 0 &&
          _generated % prismInterval == prismInterval - 1) {
        prism = _random.nextInt(4);
      }
      int? boom;
      if (boomInterval > 0 && _generated % boomInterval == boomInterval - 1) {
        boom = _specialRandom.nextInt(4);
      }
      int? gold;
      if (goldInterval > 0 && _generated % goldInterval == goldInterval - 1) {
        gold = _specialRandom.nextInt(4);
      }
      if (gold != null) {
        boom = null;
        prism = null;
      } else if (boom != null) {
        prism = null;
      }
      _generated++;
      _queue.add(
        PieceSpec(t, prismCell: prism, boomCell: boom, goldCell: gold),
      );
    }
  }

  PieceSpec _popQueue() {
    final s = _queue.removeAt(0);
    _refillQueue();
    return s;
  }

  void _spawn(PieceSpec spec) {
    final p = ActivePiece(
      spec: spec,
      rotation: 0,
      col: spec.type.spawnCol,
      row: spec.type.spawnRow,
    );
    _fallAcc = 0;
    _lockTimer = 0;
    _restarts = 0;
    _lowestRow = _bottomRow(p);
    if (!_fits(p)) {
      _active = null;
      _pendingSpawn = spec;
      _endGame(GameOverReason.blockOut);
      return;
    }
    _active = p;
    _events.add(const PieceSpawned());
  }
}
