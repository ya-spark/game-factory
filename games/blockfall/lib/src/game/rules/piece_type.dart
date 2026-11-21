/// The 7 four-cell shapes (original names) with their fixed 4-state rotation tables.
///
/// Pure Dart: no Flutter, Flame or Android imports.
enum PieceType {
  bar(1, 'Bar'),
  cube(2, 'Cube'),
  prong(3, 'Prong'),
  zig(4, 'Zig'),
  zag(5, 'Zag'),
  hook(6, 'Hook'),
  boot(7, 'Boot');

  const PieceType(this.colorId, this.displayName);

  /// Gem color id stored in the well (1..7).
  final int colorId;
  final String displayName;

  /// The 4 rotation states; each is 4 cells `(col, row)` inside the piece box.
  /// Cell order is the same in every state, so a prism cell index stays valid.
  List<List<(int, int)>> get states => _tables[this]!;

  /// Box origin row at spawn: every piece starts inside the two hidden rows.
  int get spawnRow => 0;

  /// Origin column at spawn: Bar at columns 3-6, Cube at 4-5, others at 3-5.
  int get spawnCol => 3;
}

const Map<PieceType, List<(int, int)>> _base = {
  // 4x4 box, horizontal on box row 1.
  PieceType.bar: [(0, 1), (1, 1), (2, 1), (3, 1)],
  // Cube never changes: box columns 1-2 -> well columns 4-5 at spawn.
  PieceType.cube: [(1, 0), (2, 0), (1, 1), (2, 1)],
  PieceType.prong: [(1, 0), (0, 1), (1, 1), (2, 1)],
  PieceType.zig: [(1, 0), (2, 0), (0, 1), (1, 1)],
  PieceType.zag: [(0, 0), (1, 0), (1, 1), (2, 1)],
  PieceType.hook: [(0, 0), (0, 1), (1, 1), (2, 1)],
  PieceType.boot: [(2, 0), (0, 1), (1, 1), (2, 1)],
};

final Map<PieceType, List<List<(int, int)>>> _tables = {
  for (final t in PieceType.values) t: _buildStates(t),
};

List<List<(int, int)>> _buildStates(PieceType t) {
  final first = _base[t]!;
  if (t == PieceType.cube) return List.filled(4, first);
  final n = t == PieceType.bar ? 4 : 3;
  final states = <List<(int, int)>>[first];
  for (var i = 1; i < 4; i++) {
    // Clockwise quarter turn inside an n x n box: (c, r) -> (n - 1 - r, c).
    states.add([for (final (c, r) in states.last) (n - 1 - r, c)]);
  }
  return states;
}
