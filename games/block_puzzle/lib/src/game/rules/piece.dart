/// Special kind of one cell. Drawn as an overlay on top of every theme skin. Pure Dart.
enum CellKind { normal, gem, boom, gold }

/// A block shape: a set of (row, col) offsets with min row/col = 0. Pure Dart.
class Piece {
  const Piece(this.id, this.cells, this.colorIndex, [this.kinds]);

  /// Kind per cell (parallel to [cells]); null = all normal.
  final List<CellKind>? kinds;

  CellKind kindAt(int i) => kinds == null ? CellKind.normal : kinds![i];

  bool get hasSpecial =>
      kinds != null && kinds!.any((k) => k != CellKind.normal);

  /// The same piece with cell [i] set to [kind].
  Piece withKind(int i, CellKind kind) {
    final k = List<CellKind>.of(
      kinds ?? List.filled(cells.length, CellKind.normal),
    );
    k[i] = kind;
    return Piece(id, cells, colorIndex, List.unmodifiable(k));
  }

  final String id;
  final List<(int, int)> cells;

  /// Index into the current theme's palette (0..colorCount-1). Dealt pieces get a random one.
  final int colorIndex;

  /// The same shape with another colour.
  Piece withColor(int index) => Piece(id, cells, index % colorCount, kinds);

  int get height => cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b) + 1;
  int get width => cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b) + 1;
  int get size => cells.length;

  static const int colorCount = 8;
}

/// All shapes (with rotations) the generator can offer.
abstract final class PieceCatalog {
  static List<(int, int)> _normalize(Iterable<(int, int)> cells) {
    final minR = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final minC = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final out = [for (final c in cells) (c.$1 - minR, c.$2 - minC)]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return out;
  }

  static List<(int, int)> _rotate(List<(int, int)> cells) =>
      _normalize([for (final c in cells) (c.$2, -c.$1)]);

  static String _key(List<(int, int)> cells) =>
      cells.map((c) => '${c.$1},${c.$2}').join(';');

  /// Base shapes; rotations are generated. [weight] biases how often a shape is offered.
  static const List<({String name, List<(int, int)> cells, int weight})>
  _bases = [
    (name: 'dot', cells: [(0, 0)], weight: 2),
    (name: 'bar2', cells: [(0, 0), (0, 1)], weight: 4),
    (name: 'bar3', cells: [(0, 0), (0, 1), (0, 2)], weight: 4),
    (name: 'bar4', cells: [(0, 0), (0, 1), (0, 2), (0, 3)], weight: 2),
    (name: 'bar5', cells: [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], weight: 1),
    (name: 'square2', cells: [(0, 0), (0, 1), (1, 0), (1, 1)], weight: 4),
    (
      name: 'square3',
      cells: [
        (0, 0),
        (0, 1),
        (0, 2),
        (1, 0),
        (1, 1),
        (1, 2),
        (2, 0),
        (2, 1),
        (2, 2),
      ],
      weight: 3,
    ),
    (name: 'corner3', cells: [(0, 0), (1, 0), (1, 1)], weight: 4),
    (
      name: 'corner5',
      cells: [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)],
      weight: 1,
    ),
    (name: 'l4', cells: [(0, 0), (1, 0), (2, 0), (2, 1)], weight: 3),
    (name: 't4', cells: [(0, 0), (0, 1), (0, 2), (1, 1)], weight: 3),
    (name: 's4', cells: [(0, 1), (0, 2), (1, 0), (1, 1)], weight: 2),
    (name: 'z4', cells: [(0, 0), (0, 1), (1, 1), (1, 2)], weight: 3),
    (name: 'j4', cells: [(0, 1), (1, 1), (2, 0), (2, 1)], weight: 4),
    (name: 'plus5', cells: [(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)], weight: 1),
    // Diagonal pieces: cells touch only at corners (not edge-connected).
    (name: 'diag2', cells: [(0, 0), (1, 1)], weight: 1),
    (name: 'diag3', cells: [(0, 0), (1, 1), (2, 2)], weight: 1),
    // 2x3 rectangle (6 cells): two orientations, 2 rows by 3 columns and 3 rows by 2.
    (
      name: 'rect23',
      cells: [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
      weight: 3,
    ),
  ];

  static final List<({Piece piece, int weight})> weighted = _build();

  static List<Piece> get all => [for (final w in weighted) w.piece];

  static List<({Piece piece, int weight})> _build() {
    final out = <({Piece piece, int weight})>[];
    var color = 0;
    for (final b in _bases) {
      final seen = <String>{};
      var cells = _normalize(b.cells);
      for (var r = 0; r < 4; r++) {
        if (seen.add(_key(cells))) {
          out.add((
            piece: Piece(
              '${b.name}_${seen.length - 1}',
              List.unmodifiable(cells),
              color % Piece.colorCount,
            ),
            weight: b.weight,
          ));
        }
        cells = _rotate(cells);
      }
      color++;
    }
    return out;
  }

  /// Catalogue base weight of [p] (per orientation).
  static int baseWeightOf(Piece p) {
    for (final w in weighted) {
      if (w.piece.id == p.id) return w.weight;
    }
    return 1;
  }

  static Piece byId(String id) => all.firstWhere((p) => p.id == id);

  static final Piece dot = byId('dot_0');
}
