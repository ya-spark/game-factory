import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// The prepared start of a new game: a mostly full board with no complete line and a first
/// tray whose pieces each clear lines. Pure Dart, deterministic for a seeded [Random].
class StartBoard {
  const StartBoard(this.board, this.tray);
  final Board board;
  final List<Piece> tray;

  /// Target fill is [targetFilled] plus or minus [fillSpread] cells (70% of 64).
  static const int targetFilled = 45;
  static const int fillSpread = 2;

  /// Lines each first-tray piece should clear (1 is the fallback).
  static const int wantedLines = 2;

  static const int _attempts = 300;

  static StartBoard generate(Random rng, {int size = 8}) {
    for (final lines in [wantedLines, 1]) {
      for (var i = 0; i < _attempts; i++) {
        final s = _attempt(rng, size, lines);
        if (s != null) return s;
      }
    }
    // Unreachable in practice: an empty board with a plain tray.
    return StartBoard(Board.empty(size), [
      PieceCatalog.byId('z4_0'),
      PieceCatalog.byId('j4_0'),
      PieceCatalog.byId('t4_0'),
    ]);
  }

  static StartBoard? _attempt(Random rng, int size, int lines) {
    // First tray: at least two Z or J pieces, the third any 4-cell piece, no piece (same id)
    // more than twice. Each piece must clear lines on the board, so each is placeable.
    final fours = [
      for (final p in PieceCatalog.all)
        if (p.size == 4) p,
    ];
    final zj = [
      for (final p in fours)
        if (p.id.startsWith('z4') || p.id.startsWith('j4')) p,
    ];
    final picks = [
      zj[rng.nextInt(zj.length)],
      zj[rng.nextInt(zj.length)],
      fours[rng.nextInt(fours.length)],
    ]..shuffle(rng);
    if (picks.any((p) => picks.where((q) => q.id == p.id).length > 2)) {
      return null;
    }
    final byRows = rng.nextBool();
    final cells = List<int>.filled(size * size, 0);
    final holes = <int>{};
    final reserved = <int>{}; // cells that must stay empty
    final rowsUsed = <int>{}, colsUsed = <int>{};
    final tray = <Piece>[];
    final toFill = <int>{};

    for (var k = 0; k < 3; k++) {
      final piece = picks[k];
      final r0 = rng.nextInt(size - piece.height + 1);
      final c0 = rng.nextInt(size - piece.width + 1);
      final mine = {
        for (final (dr, dc) in piece.cells) (r0 + dr) * size + c0 + dc,
      };
      if (mine.any(holes.contains)) return null;
      final rows = {for (final i in mine) i ~/ size}.toList()..shuffle(rng);
      final cols = {for (final i in mine) i % size}.toList()..shuffle(rng);
      // One orientation for all three pieces: a row cleared by one piece would otherwise
      // break a column another piece needs.
      final cand = [
        if (byRows) ...rows.map((r) => (true, r)),
        if (!byRows) ...cols.map((c) => (false, c)),
      ];
      final chosen = <(bool, int)>[];
      for (final l in cand) {
        if (chosen.length == lines) break;
        if (l.$1 ? rowsUsed.contains(l.$2) : colsUsed.contains(l.$2)) continue;
        chosen.add(l);
      }
      if (chosen.length < lines) return null;
      for (final l in chosen) {
        (l.$1 ? rowsUsed : colsUsed).add(l.$2);
        for (var i = 0; i < size; i++) {
          final idx = l.$1 ? l.$2 * size + i : i * size + l.$2;
          if (!mine.contains(idx)) toFill.add(idx);
        }
      }
      holes.addAll(mine);
      reserved.addAll(mine);
      tray.add(piece);
    }
    if (toFill.any(holes.contains)) return null;
    for (final i in toFill) {
      cells[i] = 1 + rng.nextInt(Piece.colorCount);
    }
    final target = targetFilled - fillSpread + rng.nextInt(2 * fillSpread + 1);
    if (toFill.length > targetFilled + fillSpread) return null;

    // Filler: random cells that never complete a line.
    final order = List<int>.generate(size * size, (i) => i)..shuffle(rng);
    var count = toFill.length;
    for (final i in order) {
      if (count >= target) break;
      if (cells[i] != 0 || reserved.contains(i)) continue;
      final r = i ~/ size, c = i % size;
      var rowN = 0, colN = 0;
      for (var j = 0; j < size; j++) {
        if (cells[r * size + j] != 0) rowN++;
        if (cells[j * size + c] != 0) colN++;
      }
      if (rowN + 1 >= size || colN + 1 >= size) continue;
      cells[i] = 1 + rng.nextInt(Piece.colorCount);
      count++;
    }
    if ((count - targetFilled).abs() > fillSpread) return null;

    final board = Board.fromCells(size, cells);
    if (!_verify(board, tray, lines)) return null;
    return StartBoard(board, tray);
  }

  /// No complete line now; in every order each piece clears at least [lines] lines.
  static bool _verify(Board board, List<Piece> tray, int lines) {
    final n = board.size;
    for (var r = 0; r < n; r++) {
      if (List.generate(n, (c) => board.isFilled(r, c)).every((v) => v)) {
        return false;
      }
    }
    for (var c = 0; c < n; c++) {
      if (List.generate(n, (r) => board.isFilled(r, c)).every((v) => v)) {
        return false;
      }
    }
    const orders = [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ];
    for (final order in orders) {
      var b = board;
      for (final k in order) {
        final res = _bestPlacement(b, tray[k]);
        if (res == null || res.linesCleared < lines) return false;
        b = res.board;
      }
    }
    return true;
  }

  static PlacementResult? _bestPlacement(Board b, Piece p) {
    PlacementResult? best;
    for (var r = 0; r < b.size; r++) {
      for (var c = 0; c < b.size; c++) {
        if (!b.canPlace(p, r, c)) continue;
        final res = b.place(p, r, c);
        if (best == null || res.linesCleared > best.linesCleared) best = res;
      }
    }
    return best;
  }
}
