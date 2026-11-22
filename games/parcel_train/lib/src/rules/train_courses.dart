/// The five courses of Parcel train. Pure Dart: no Flutter imports.
///
/// Map characters: `.` free, `#` toy-block stack, `f` picket fence, `~` pond, `1` and `2` the two mouths of a
/// tunnel pair, `S` the engine's start cell (heading right, two wagons to its left), `G` the station gate.
library;

import 'dart:math';

/// What a map cell is.
enum TrainTile { free, block, fence, pond, tunnel, gate }

/// A cell of the mat (column, row).
class TrainCell {
  const TrainCell(this.x, this.y);
  final int x;
  final int y;
  @override
  bool operator ==(Object other) =>
      other is TrainCell && other.x == x && other.y == y;
  @override
  int get hashCode => x * 1000 + y;
  @override
  String toString() => '($x,$y)';
}

class TrainCourse {
  TrainCourse._({
    required this.number,
    required this.name,
    required this.rows,
    required this.goal,
    required this.baseInterval,
    required this.cols,
    required this.tiles,
    required this.tunnelPairs,
    required this.start,
    required this.gate,
  });

  factory TrainCourse.parse({
    required int number,
    required String name,
    required List<String> map,
    required int goal,
    required double baseInterval,
  }) {
    final rows = map.length;
    final cols = map.first.length;
    final tiles = <TrainTile>[];
    final mouths = <String, List<TrainCell>>{};
    TrainCell? start;
    TrainCell? gate;
    for (var y = 0; y < rows; y++) {
      assert(map[y].length == cols, 'course $number row $y has a wrong width');
      for (var x = 0; x < cols; x++) {
        final c = map[y][x];
        tiles.add(switch (c) {
          '#' => TrainTile.block,
          'f' => TrainTile.fence,
          '~' => TrainTile.pond,
          '1' || '2' => TrainTile.tunnel,
          'G' => TrainTile.gate,
          _ => TrainTile.free,
        });
        if (c == '1' || c == '2') (mouths[c] ??= []).add(TrainCell(x, y));
        if (c == 'S') start = TrainCell(x, y);
        if (c == 'G') gate = TrainCell(x, y);
      }
    }
    final pairs = <TrainCell, TrainCell>{};
    for (final m in mouths.values) {
      assert(m.length == 2, 'a tunnel needs exactly two mouths');
      pairs[m[0]] = m[1];
      pairs[m[1]] = m[0];
    }
    return TrainCourse._(
      number: number,
      name: name,
      rows: rows,
      cols: cols,
      goal: goal,
      baseInterval: baseInterval,
      tiles: tiles,
      tunnelPairs: pairs,
      start: start!,
      gate: gate!,
    );
  }

  /// 1 to 5.
  final int number;
  final String name;
  final int cols;
  final int rows;

  /// Parcels the station asks for.
  final int goal;

  /// Seconds per move at the start length.
  final double baseInterval;
  final List<TrainTile> tiles;

  /// Each tunnel mouth to the other mouth of its pair.
  final Map<TrainCell, TrainCell> tunnelPairs;
  final TrainCell start;
  final TrainCell gate;

  /// The seed of this course's parcels (the same every try, so a course can be learned).
  int get seed => 2011 * number;

  Random newRandom() => Random(seed);

  TrainTile tile(int x, int y) => tiles[y * cols + x];

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

  /// A cell nothing can drive into (blocks, fences, pond; the gate is solid until it opens).
  bool solid(int x, int y) => switch (tile(x, y)) {
    TrainTile.block || TrainTile.fence || TrainTile.pond => true,
    _ => false,
  };

  /// The number of obstacle cells (blocks, fences, pond).
  int get obstacleCount =>
      tiles.where((t) => t.index >= 1 && t.index <= 3).length;
}

const int trainCourseCount = 5;

/// Every course's goal: 5, 8, 10, 12, 15 parcels.
final List<TrainCourse> trainCourses = [
  TrainCourse.parse(
    number: 1,
    name: 'Playmat',
    goal: 5,
    baseInterval: 0.26,
    map: const [
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '....S.......G',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
    ],
  ),
  TrainCourse.parse(
    number: 2,
    name: 'Block yard',
    goal: 8,
    baseInterval: 0.24,
    map: const [
      '.............',
      '.............',
      '...##...##...',
      '...##...##...',
      '.............',
      '.............',
      '....S.......G',
      '.............',
      '.............',
      '...##...##...',
      '...##...##...',
      '.............',
      '.............',
    ],
  ),
  TrainCourse.parse(
    number: 3,
    name: 'Tunnel town',
    goal: 10,
    baseInterval: 0.22,
    map: const [
      '...............',
      '.....f...f.....',
      '.....f...f.....',
      '.....1...2.....',
      '.....f...f.....',
      '.....f...f.....',
      '....S.........G',
      '...............',
      '.....f...f.....',
      '.....2...1.....',
      '.....f...f.....',
      '.....f...f.....',
      '...............',
    ],
  ),
  TrainCourse.parse(
    number: 4,
    name: 'Pond loop',
    goal: 12,
    baseInterval: 0.20,
    map: const [
      '...............',
      '....S..........',
      '...............',
      '...~~~~~~~~~...',
      '...~~~~~~~~~...',
      '...~~~~~~~~~...',
      '.#.~~~~~~~~~...',
      '.#.~~~~~~~~~..G',
      '...~~~~~~~~~...',
      '...~~~~~~~~~...',
      '...~~~~~~~~~...',
      '...~~~~~~~~~..#',
      '..............#',
      '...............',
      '...............',
    ],
  ),
  TrainCourse.parse(
    number: 5,
    name: 'Big station',
    goal: 15,
    baseInterval: 0.20,
    map: const [
      '...............',
      '...............',
      '....S..........',
      '...............',
      'ffffffffffff...',
      '...............',
      '......###......',
      '......###......',
      '......###......',
      '...............',
      '...ffffffffffff',
      '...............',
      '...............',
      '..............G',
      '...............',
    ],
  ),
];
