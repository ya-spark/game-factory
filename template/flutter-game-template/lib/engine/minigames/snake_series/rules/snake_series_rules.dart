/// Snake for series: the snake eats the items in the right order. Plays `series`, `word` (the
/// letters in order) and `numeric` (the digits in order). Pure Dart.
///
/// Steering mistakes are never evidence: the walls wrap, hitting yourself only shortens the
/// snake, and only eating the wrong item counts against the answer.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../minigame_level.dart';

const String snakeSeriesId = 'snake_series';

/// Longest label a tile can carry (the board is small).
const int snakeLabelMax = 8;

/// What the child must eat, in order, and the line shown above the board.
class SnakeTask {
  const SnakeTask(this.prompt, this.labels);
  final String prompt;
  final List<String> labels;
}

/// The task of an item, or null when the game cannot play it: a `series` of 3 to 8 steps of at
/// most [snakeLabelMax] characters, a `word` of 3 to 10 letters, a whole-number `numeric` answer
/// of at most 4 digits.
SnakeTask? snakeTask(ContentItem item) {
  final j = item.json;
  switch (item.type) {
    case ItemType.series:
      final steps = [for (final s in (j['steps'] as List? ?? const [])) '$s'];
      if (steps.length < 3 ||
          steps.length > 8 ||
          steps.any((s) => s.runes.length > snakeLabelMax)) {
        return null;
      }
      return SnakeTask('${j['prompt']}', steps);
    case ItemType.word:
      final a = '${j['answer']}'.trim().toUpperCase();
      if (!RegExp(r'^[A-Z]{3,10}$').hasMatch(a)) return null;
      return SnakeTask('Spell the word: ${j['hint']}', a.split(''));
    case ItemType.numeric:
      final raw = '${j['answer']}'.replaceAll(RegExp(r'[,\s]'), '');
      if (!RegExp(r'^\d{1,4}$').hasMatch(raw)) return null;
      return SnakeTask('${j['prompt']}', raw.split(''));
    case ItemType.mcq:
    case ItemType.pairs:
    case ItemType.category:
    case ItemType.cloze:
      return null;
  }
}

bool snakePlaysItem(ContentItem item) => snakeTask(item) != null;

class SnakeSettings {
  const SnakeSettings({
    required this.cols,
    required this.rows,
    required this.tickMillis,
    required this.lives,
  });
  final int cols;
  final int rows;

  /// Milliseconds per step.
  final int tickMillis;

  /// Wrong items allowed; 0 means no limit (the younger level never fails).
  final int lives;

  factory SnakeSettings.forLevel(MiniGameLevel l) => !l.older
      ? const SnakeSettings(cols: 7, rows: 9, tickMillis: 700, lives: 0)
      : SnakeSettings(
          cols: 8,
          rows: 10,
          tickMillis: l.harder ? 320 : 450,
          lives: 3,
        );
}

enum SnakeDir { up, down, left, right }

class Cell {
  const Cell(this.c, this.r);
  final int c;
  final int r;
  @override
  bool operator ==(Object other) =>
      other is Cell && other.c == c && other.r == r;
  @override
  int get hashCode => c * 1000 + r;
  @override
  String toString() => '($c,$r)';
}

/// What a step did.
enum SnakeEvent {
  none,

  /// Ate the next item in order.
  ate,

  /// Ate an item out of order; the item stays.
  mistake,

  /// Ate the last item.
  done,

  /// Out of lives.
  lost,
}

class SnakeBoard {
  SnakeBoard({
    required this.task,
    required this.settings,
    required Random random,
  }) {
    final head = Cell(settings.cols ~/ 2, settings.rows - 2);
    body = [head];
    direction = SnakeDir.up;
    final free = [
      for (var c = 0; c < settings.cols; c++)
        for (var r = 0; r < settings.rows - 3; r++) Cell(c, r),
    ]..shuffle(random);
    for (var i = 0; i < task.labels.length; i++) {
      foods[free[i]] = task.labels[i];
    }
  }

  final SnakeTask task;
  final SnakeSettings settings;

  /// The snake, head first.
  late List<Cell> body;
  late SnakeDir direction;

  /// Tiles on the board: cell to label.
  final Map<Cell, String> foods = {};

  /// Items eaten in order so far.
  int eaten = 0;

  /// Wrong items eaten.
  int mistakes = 0;

  Cell get head => body.first;
  String? get nextLabel =>
      eaten < task.labels.length ? task.labels[eaten] : null;
  bool get done => eaten >= task.labels.length;
  bool get lost => settings.lives > 0 && mistakes >= settings.lives;
  bool get over => done || lost;

  /// Right on the first go: nothing eaten out of order.
  bool get clean => done && mistakes == 0;

  /// Turns the snake. A reversal into its own neck is ignored when it has a body.
  void turn(SnakeDir d) {
    final back = switch (direction) {
      SnakeDir.up => SnakeDir.down,
      SnakeDir.down => SnakeDir.up,
      SnakeDir.left => SnakeDir.right,
      SnakeDir.right => SnakeDir.left,
    };
    if (body.length > 1 && d == back) return;
    direction = d;
  }

  /// One step. Walls wrap; hitting yourself cuts the snake there (nothing is lost but length).
  SnakeEvent step() {
    if (over) return SnakeEvent.none;
    final (dc, dr) = switch (direction) {
      SnakeDir.up => (0, -1),
      SnakeDir.down => (0, 1),
      SnakeDir.left => (-1, 0),
      SnakeDir.right => (1, 0),
    };
    final next = Cell(
      (head.c + dc + settings.cols) % settings.cols,
      (head.r + dr + settings.rows) % settings.rows,
    );
    var event = SnakeEvent.none;
    var grow = false;
    final label = foods[next];
    if (label != null) {
      if (label == nextLabel) {
        foods.remove(next);
        eaten++;
        grow = true;
        event = done ? SnakeEvent.done : SnakeEvent.ate;
      } else {
        mistakes++;
        event = lost ? SnakeEvent.lost : SnakeEvent.mistake;
      }
    }
    final hit = body.indexOf(next);
    final moved = [next, ...body];
    if (!grow) moved.removeLast();
    // Running into yourself cuts the snake at that cell: nothing is lost but length.
    body = hit > 0 && hit + 1 < moved.length
        ? moved.sublist(0, hit + 1)
        : moved;
    return event;
  }
}
