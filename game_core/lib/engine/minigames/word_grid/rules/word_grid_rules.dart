/// Word search and crossword rules, built from the open `word` items. Pure Dart; the random
/// source is injected so a seed gives the same grid.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../minigame_level.dart';

const String wordGridId = 'word_grid';

enum GridKind { wordSearch, crossword }

class WordGridSettings {
  const WordGridSettings({
    required this.directions,
    required this.maxWords,
    required this.secondsPerRound,
  });

  /// Allowed directions as (row step, column step).
  final List<(int, int)> directions;
  final int maxWords;

  /// 0 means no timer.
  final int secondsPerRound;

  factory WordGridSettings.forLevel(MiniGameLevel l) => !l.older
      ? const WordGridSettings(
          directions: [(0, 1), (1, 0)],
          maxWords: 4,
          secondsPerRound: 0,
        )
      : l.harder
      ? const WordGridSettings(
          directions: [
            (0, 1),
            (1, 0),
            (1, 1),
            (-1, 1),
            (0, -1),
            (-1, 0),
            (-1, -1),
            (1, -1),
          ],
          maxWords: 8,
          secondsPerRound: 180,
        )
      : const WordGridSettings(
          directions: [(0, 1), (1, 0), (1, 1)],
          maxWords: 6,
          secondsPerRound: 240,
        );
}

/// A word to place: the item's listed answer, upper case, with its hint.
class GridWord {
  const GridWord(this.id, this.word, this.hint);
  final String id;
  final String word;
  final String hint;
}

/// The answer of a `word` item as a grid word: letters only, 3 to 10 long. Null otherwise.
/// The answer is matched exactly as listed (upper-cased); spelling is never changed.
GridWord? gridWordFromItem(ContentItem item) {
  if (item.type != ItemType.word) return null;
  final a = (item.json['answer'] as String).trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{3,10}$').hasMatch(a)) return null;
  return GridWord(item.id, a, item.json['hint'] as String);
}

class PlacedWord {
  const PlacedWord({
    required this.word,
    required this.row,
    required this.col,
    required this.dRow,
    required this.dCol,
    this.number = 0,
  });
  final GridWord word;
  final int row;
  final int col;
  final int dRow;
  final int dCol;

  /// Clue number in a crossword (1 up); 0 in a word search.
  final int number;

  List<(int, int)> get cells => [
    for (var i = 0; i < word.word.length; i++) (row + dRow * i, col + dCol * i),
  ];
  bool get across => dRow == 0;
}

class WordGrid {
  const WordGrid({
    required this.kind,
    required this.rows,
    required this.cols,
    required this.letters,
    required this.placed,
  });
  final GridKind kind;
  final int rows;
  final int cols;

  /// Letters by row; '' is an empty cell (crossword only).
  final List<List<String>> letters;
  final List<PlacedWord> placed;
}

List<List<String>> _empty(int n) => [
  for (var i = 0; i < n; i++) List.filled(n, ''),
];

bool _inside(int n, int r, int c) => r >= 0 && c >= 0 && r < n && c < n;

/// Whether [w] fits at the spot: every cell empty or already the same letter.
bool _fitsSearch(List<List<String>> g, String w, int r, int c, int dr, int dc) {
  final n = g.length;
  for (var i = 0; i < w.length; i++) {
    final rr = r + dr * i, cc = c + dc * i;
    if (!_inside(n, rr, cc)) return false;
    if (g[rr][cc].isNotEmpty && g[rr][cc] != w[i]) return false;
  }
  return true;
}

/// A word search hiding the words (longest first) in a square grid. Words that do not fit
/// are left out. Null when fewer than 2 words can be placed.
WordGrid? buildWordSearch(
  List<GridWord> words,
  WordGridSettings s,
  Random random,
) {
  final list = ([
    ...words,
  ]..sort((a, b) => b.word.length - a.word.length)).take(s.maxWords).toList();
  if (list.isEmpty) return null;
  final longest = list.first.word.length;
  final n = max(longest + 1, 6 + list.length);
  final g = _empty(n);
  final placed = <PlacedWord>[];
  for (final w in list) {
    PlacedWord? done;
    for (var attempt = 0; attempt < 200 && done == null; attempt++) {
      final d = s.directions[random.nextInt(s.directions.length)];
      final r = random.nextInt(n), c = random.nextInt(n);
      if (!_fitsSearch(g, w.word, r, c, d.$1, d.$2)) continue;
      done = PlacedWord(word: w, row: r, col: c, dRow: d.$1, dCol: d.$2);
    }
    if (done == null) continue;
    for (final (i, cell) in done.cells.indexed) {
      g[cell.$1][cell.$2] = w.word[i];
    }
    placed.add(done);
  }
  if (placed.length < 2) return null;
  const alphabet = 'ABCDEFGHIJKLMNOPRSTUW';
  for (final row in g) {
    for (var c = 0; c < n; c++) {
      if (row[c].isEmpty) row[c] = alphabet[random.nextInt(alphabet.length)];
    }
  }
  return WordGrid(
    kind: GridKind.wordSearch,
    rows: n,
    cols: n,
    letters: g,
    placed: placed,
  );
}

String _at(List<List<String>> g, int r, int c) =>
    _inside(g.length, r, c) ? g[r][c] : '';

/// Whether a crossword word can go at the spot: letters agree where they cross, it touches no
/// other word side by side, and the cells before and after it are empty.
bool _fitsCross(List<List<String>> g, String w, int r, int c, bool across) {
  final dr = across ? 0 : 1, dc = across ? 1 : 0;
  final n = g.length;
  if (_at(g, r - dr, c - dc).isNotEmpty) return false;
  if (_at(g, r + dr * w.length, c + dc * w.length).isNotEmpty) return false;
  var crossings = 0;
  for (var i = 0; i < w.length; i++) {
    final rr = r + dr * i, cc = c + dc * i;
    if (!_inside(n, rr, cc)) return false;
    final have = g[rr][cc];
    if (have.isNotEmpty) {
      if (have != w[i]) return false;
      crossings++;
    } else if (_at(g, rr + dc, cc + dr).isNotEmpty ||
        _at(g, rr - dc, cc - dr).isNotEmpty) {
      return false;
    }
  }
  // A word must cross one already placed, and may not lie along another word.
  return crossings >= 1 && crossings < w.length;
}

/// A small crossword: the longest word goes across, the rest cross it. Words that cannot be
/// placed are left out. Null when fewer than 2 words can be placed. Rows and columns are
/// cropped to the used area.
WordGrid? buildCrossword(
  List<GridWord> words,
  WordGridSettings s,
  Random random,
) {
  final list = ([
    ...words,
  ]..sort((a, b) => b.word.length - a.word.length)).take(s.maxWords).toList();
  if (list.length < 2) return null;
  final n = list.first.word.length + 6;
  final g = _empty(n);
  final first = list.first;
  final r0 = n ~/ 2, c0 = (n - first.word.length) ~/ 2;
  final raw = <(GridWord, int, int, bool)>[(first, r0, c0, true)];
  for (var i = 0; i < first.word.length; i++) {
    g[r0][c0 + i] = first.word[i];
  }
  for (final w in list.skip(1)) {
    final spots = <(int, int, bool)>[];
    for (final across in [true, false]) {
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (_fitsCross(g, w.word, r, c, across)) spots.add((r, c, across));
        }
      }
    }
    if (spots.isEmpty) continue;
    final (r, c, across) = spots[random.nextInt(spots.length)];
    for (var i = 0; i < w.word.length; i++) {
      g[r + (across ? 0 : i)][c + (across ? i : 0)] = w.word[i];
    }
    raw.add((w, r, c, across));
  }
  if (raw.length < 2) return null;
  var minR = n, minC = n, maxR = 0, maxC = 0;
  for (final (w, r, c, across) in raw) {
    minR = min(minR, r);
    minC = min(minC, c);
    maxR = max(maxR, r + (across ? 0 : w.word.length - 1));
    maxC = max(maxC, c + (across ? w.word.length - 1 : 0));
  }
  final rows = maxR - minR + 1, cols = maxC - minC + 1;
  final out = [
    for (var r = 0; r < rows; r++)
      [for (var c = 0; c < cols; c++) g[r + minR][c + minC]],
  ];
  // Number the words in reading order of their first cell.
  final sorted = [...raw]
    ..sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$3 - b.$3);
  final placed = <PlacedWord>[];
  final numbers = <String, int>{};
  for (final (w, r, c, across) in sorted) {
    final key = '${r - minR},${c - minC}';
    final num = numbers.putIfAbsent(key, () => numbers.length + 1);
    placed.add(
      PlacedWord(
        word: w,
        row: r - minR,
        col: c - minC,
        dRow: across ? 0 : 1,
        dCol: across ? 1 : 0,
        number: num,
      ),
    );
  }
  return WordGrid(
    kind: GridKind.crossword,
    rows: rows,
    cols: cols,
    letters: out,
    placed: placed,
  );
}

/// The placed word covered by a straight selection from [start] to [end] (either direction),
/// or null.
PlacedWord? wordForSelection(WordGrid g, (int, int) start, (int, int) end) {
  for (final p in g.placed) {
    final cells = p.cells;
    if (cells.first == start && cells.last == end) return p;
    if (cells.first == end && cells.last == start) return p;
  }
  return null;
}

/// The cells of a straight line from [a] to [b] (rows, columns or diagonals), or null when
/// they do not line up.
List<(int, int)>? lineBetween((int, int) a, (int, int) b) {
  final dr = b.$1 - a.$1, dc = b.$2 - a.$2;
  if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return null;
  final len = max(dr.abs(), dc.abs());
  final sr = dr.sign, sc = dc.sign;
  return [for (var i = 0; i <= len; i++) (a.$1 + sr * i, a.$2 + sc * i)];
}

/// True when [typed] is the crossword word's answer (any case).
bool crosswordAnswerMatches(PlacedWord p, String typed) =>
    typed.trim().toUpperCase() == p.word.word;

/// The leading words of [items] (in the round's order) that can go in a grid: stops at the
/// first item that cannot, so the placed words are always a prefix of the round.
List<GridWord> leadingGridWords(Iterable<ContentItem> items) {
  final out = <GridWord>[];
  for (final it in items) {
    final w = gridWordFromItem(it);
    if (w == null) break;
    out.add(w);
  }
  return out;
}

/// A grid of the first `k` [words], with the largest `k` (up to the level's limit, at least 2)
/// for which every one of them is placed. Null when not even 2 fit.
WordGrid? buildWordGrid(
  GridKind kind,
  List<GridWord> words,
  WordGridSettings s,
  Random random,
) {
  for (var k = min(s.maxWords, words.length); k >= 2; k--) {
    final part = words.take(k).toList();
    for (var attempt = 0; attempt < 40; attempt++) {
      final g = kind == GridKind.wordSearch
          ? buildWordSearch(part, s, random)
          : buildCrossword(part, s, random);
      if (g != null && g.placed.length == k) return g;
    }
  }
  return null;
}
