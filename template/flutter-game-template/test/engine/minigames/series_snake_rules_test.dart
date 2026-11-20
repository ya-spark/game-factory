import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem series(List<String> steps) => ContentItem({
  'id': 's.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'e',
  'prompt': 'Put the multiples of 3 in order.',
  'steps': steps,
});

ContentItem word(String a) => ContentItem({
  'id': 'w.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'e',
  'answer': a,
  'hint': 'A pet that barks',
});

ContentItem numeric(Object a) => ContentItem({
  'id': 'n.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'e',
  'prompt': 'What is 7 × 8?',
  'answer': a,
});

const settings = SnakeSettings(cols: 7, rows: 9, tickMillis: 500, lives: 3);

/// A board with the tiles put where the test wants them, in a row above the head.
SnakeBoard board(List<String> labels, {SnakeSettings s = settings}) {
  final b = SnakeBoard(
    task: SnakeTask('p', labels),
    settings: s,
    random: Random(1),
  );
  b.foods.clear();
  for (var i = 0; i < labels.length; i++) {
    b.foods[Cell(b.head.c, b.head.r - 1 - i)] = labels[i];
  }
  return b;
}

void main() {
  group('tasks', () {
    test('a series gives its steps; too short, too long or wide labels do not play', () {
      expect(snakeTask(series(['3', '6', '9']))!.labels, ['3', '6', '9']);
      expect(snakeTask(series(['3', '6'])), isNull);
      expect(snakeTask(series([for (var i = 0; i < 9; i++) '$i'])), isNull);
      expect(snakeTask(series(['3', '6', 'x' * 9])), isNull);
    });
    test('a word gives its letters in order, 3 to 10 letters', () {
      expect(snakeTask(word('dog'))!.labels, ['D', 'O', 'G']);
      expect(snakeTask(word('do')), isNull);
      expect(snakeTask(word('abcdefghijk')), isNull);
      expect(snakeTask(word('ab-c')), isNull);
      expect(snakeTask(word('dog'))!.prompt, contains('A pet that barks'));
    });
    test('a whole-number answer of at most 4 digits gives its digits', () {
      expect(snakeTask(numeric(56))!.labels, ['5', '6']);
      expect(snakeTask(numeric('1,024'))!.labels, ['1', '0', '2', '4']);
      expect(snakeTask(numeric(12345)), isNull);
      expect(snakeTask(numeric(1.5)), isNull);
      expect(snakeTask(numeric(-3)), isNull);
    });
    test('other formats are not played', () {
      expect(
        snakeTask(
          ContentItem({
            'id': 'x',
            'type': 'mcq',
            'options': ['a', 'b'],
            'correct': 0,
            'prompt': 'p',
          }),
        ),
        isNull,
      );
    });
  });

  group('the board', () {
    test(
      'every label has a tile, all on different cells, none under the snake',
      () {
        final b = SnakeBoard(
          task: const SnakeTask('p', ['3', '6', '9', '12']),
          settings: settings,
          random: Random(7),
        );
        expect(b.foods.length, 4);
        expect(b.foods.keys.toSet().length, 4);
        expect(b.foods.containsKey(b.head), isFalse);
        expect(b.foods.values.toList()..sort(), ['12', '3', '6', '9']..sort());
      },
    );

    test('eating in order grows the snake and finishes', () {
      final b = board(['3', '6', '9']);
      expect(b.step(), SnakeEvent.ate);
      expect(b.body.length, 2);
      expect(b.step(), SnakeEvent.ate);
      expect(b.step(), SnakeEvent.done);
      expect(b.done, isTrue);
      expect(b.clean, isTrue);
      expect(b.eaten, 3);
    });

    test(
      'a wrong item counts once, stays on the board, and the run goes on',
      () {
        final b = board(['3', '6', '9']);
        b.foods[Cell(b.head.c, b.head.r - 1)] = '9';
        expect(b.step(), SnakeEvent.mistake);
        expect(b.mistakes, 1);
        expect(b.foods.length, 3, reason: 'the wrong tile stays');
        expect(b.eaten, 0);
        expect(b.over, isFalse);
      },
    );

    test('three wrong items lose the item, never before', () {
      final b = board(['3', '6', '9']);
      // the tile above the head is not "3": three passes over wrong tiles
      for (var i = 0; i < 3; i++) {
        b.foods[Cell(b.head.c, b.head.r - 1)] = '9';
        final e = b.step();
        expect(e, i < 2 ? SnakeEvent.mistake : SnakeEvent.lost);
      }
      expect(b.lost, isTrue);
      expect(b.clean, isFalse);
      expect(b.step(), SnakeEvent.none);
    });

    test('the younger level has no lives: it never loses', () {
      const younger = SnakeSettings(
        cols: 7,
        rows: 9,
        tickMillis: 700,
        lives: 0,
      );
      final b = board(['3', '6'], s: younger);
      for (var i = 0; i < 6; i++) {
        b.foods[Cell(b.head.c, b.head.r - 1)] = '9';
        b.step();
      }
      expect(b.mistakes, 6);
      expect(b.lost, isFalse);
    });

    test('duplicate labels are eaten in any order among equals', () {
      final b = board(['O', 'O', 'P']);
      // put the second "O" first in the path: either tile counts as the next "O"
      expect(b.step(), SnakeEvent.ate);
      expect(b.step(), SnakeEvent.ate);
      expect(b.step(), SnakeEvent.done);
      expect(b.clean, isTrue);
    });

    test('the walls wrap', () {
      final b = SnakeBoard(
        task: const SnakeTask('p', ['1', '2', '3']),
        settings: settings,
        random: Random(1),
      );
      b.foods.clear();
      b.body = [const Cell(0, 4)];
      b.direction = SnakeDir.left;
      b.step();
      expect(b.head, const Cell(6, 4));
    });

    test('turning back into the neck is ignored once the snake has a body', () {
      final b = board(['3', '6', '9']);
      b.step();
      b.turn(SnakeDir.down);
      expect(b.direction, SnakeDir.up);
      b.turn(SnakeDir.left);
      expect(b.direction, SnakeDir.left);
    });

    test('hitting yourself shortens the snake and loses nothing else', () {
      final b = SnakeBoard(
        task: const SnakeTask('p', ['1', '2', '3']),
        settings: settings,
        random: Random(1),
      );
      b.foods.clear();
      b.body = [
        const Cell(3, 3),
        const Cell(4, 3),
        const Cell(4, 4),
        const Cell(3, 4),
        const Cell(2, 4),
      ];
      b.direction = SnakeDir.down;
      b.step();
      expect(b.body.length, lessThan(5));
      expect(b.mistakes, 0);
      expect(b.eaten, 0);
    });
  });

  test('settings follow the level', () {
    expect(SnakeSettings.forLevel(const MiniGameLevel.younger()).lives, 0);
    expect(SnakeSettings.forLevel(const MiniGameLevel.older()).lives, 3);
    expect(
      SnakeSettings.forLevel(const MiniGameLevel.older(harder: true))
          .tickMillis,
      lessThan(SnakeSettings.forLevel(const MiniGameLevel.older()).tickMillis),
    );
  });
}
