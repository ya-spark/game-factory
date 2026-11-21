import 'package:game_core/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

RunReport _r(
  int score, {
  bool? won,
  int seconds = 60,
  String? variant,
  String id = 'sudoku',
}) => RunReport(
  gameId: id,
  score: score,
  won: won,
  seconds: seconds,
  variant: variant,
);

void main() {
  group('aggregation', () {
    test('plays, wins, win rate, best, average, time and last day', () {
      var b = const GameStats();
      b = b.record(_r(100, won: true, seconds: 120), 10).book;
      b = b.record(_r(50, won: false, seconds: 30), 11).book;
      b = b.record(_r(150, won: true, seconds: 90), 11).book;
      final e = b.entry('sudoku');
      expect(e.plays, 3);
      expect(e.wins, 2);
      expect(e.winRatePercent, 67);
      expect(e.bestScore, 150);
      expect(e.averageScore, 100);
      expect(e.totalSeconds, 240);
      expect(e.lastDay, 11);
      expect(b.daysPlayed, 2);
      expect(b.totalSeconds, 240);
    });

    test('a game without wins has no win rate', () {
      final b = const GameStats().record(_r(5), 1).book;
      expect(b.entry('sudoku').winRatePercent, isNull);
      expect(b.entry('sudoku').hasWins, isFalse);
    });

    test('this week counts the last seven days only', () {
      var b = const GameStats();
      b = b.record(_r(1, seconds: 100), 1).book;
      b = b.record(_r(1, seconds: 40), 10).book;
      b = b.record(_r(1, seconds: 20), 14).book;
      expect(b.secondsThisWeek(14), 60);
      expect(b.secondsThisWeek(21), 0);
    });
  });

  group('20-run window', () {
    test('keeps the last 20 runs; average uses them, totals use all', () {
      var b = const GameStats();
      for (var i = 1; i <= 25; i++) {
        b = b.record(_r(i * 10), 5).book;
      }
      final e = b.entry('sudoku');
      expect(e.runs.length, statsRunWindow);
      expect(e.runs.first.score, 60);
      expect(e.runs.last.score, 250);
      expect(e.plays, 25);
      expect(e.averageScore, 155);
    });
  });

  group('fastest solve per variant', () {
    test('only won runs with a variant count, one record per variant', () {
      var b = const GameStats();
      b = b.record(_r(1, won: true, seconds: 100, variant: 'Hard'), 1).book;
      b = b.record(_r(1, won: false, seconds: 10, variant: 'Hard'), 1).book;
      b = b.record(_r(1, won: true, seconds: 50, variant: 'Easy'), 1).book;
      b = b.record(_r(1, won: true, seconds: 90, variant: 'Hard'), 1).book;
      expect(b.entry('sudoku').fastest, {'Hard': 90, 'Easy': 50});
    });
  });

  group('new best', () {
    test('the first run sets the baseline, a higher score is a new best', () {
      var o = const GameStats().record(_r(100), 1);
      expect(o.isNewBest, isFalse);
      o = o.book.record(_r(90), 1);
      expect(o.isNewBest, isFalse);
      o = o.book.record(_r(120), 1);
      expect(o.newBestScore, isTrue);
    });

    test('the tile best counts as the baseline', () {
      final o = const GameStats().record(_r(100), 1, priorBest: 300);
      expect(o.isNewBest, isFalse);
      expect(o.book.entry('sudoku').bestScore, 300);
    });

    test(
      'a faster solve of a known variant is a new best; the first is not',
      () {
        var o = const GameStats().record(
          _r(1, won: true, seconds: 100, variant: 'Hard'),
          1,
        );
        expect(o.isNewBest, isFalse);
        o = o.book.record(_r(1, won: true, seconds: 80, variant: 'Hard'), 1);
        expect(o.newFastestVariant, 'Hard');
        o = o.book.record(_r(1, won: true, seconds: 85, variant: 'Hard'), 1);
        expect(o.isNewBest, isFalse);
      },
    );
  });

  group('reset scope', () {
    test('clears history, averages, times and days; keeps best scores', () {
      var b = const GameStats();
      b = b.record(_r(100, won: true, seconds: 30, variant: 'Hard'), 3).book;
      b = b.record(_r(0, id: 'solitaire'), 3).book;
      final r = b.reset();
      final e = r.entry('sudoku');
      expect(e.bestScore, 100);
      expect(e.plays, 0);
      expect(e.runs, isEmpty);
      expect(e.fastest, isEmpty);
      expect(e.totalSeconds, 0);
      expect(r.daysPlayed, 0);
      expect(r.totalSeconds, 0);
      expect(r.games.containsKey('solitaire'), isFalse);
    });
  });

  group('timer rule', () {
    test('background time is not counted', () {
      var now = DateTime(2026, 1, 1, 12);
      final t = ActiveTimer(() => now)..start();
      now = now.add(const Duration(seconds: 30));
      t.pause();
      now = now.add(const Duration(minutes: 10));
      t.resume();
      now = now.add(const Duration(seconds: 15));
      expect(t.seconds, 45);
    });

    test('a clock moved back counts zero, never negative', () {
      var now = DateTime(2026, 1, 1, 12);
      final t = ActiveTimer(() => now)..start();
      now = now.subtract(const Duration(minutes: 5));
      expect(t.seconds, 0);
      t.pause();
      expect(t.seconds, 0);
    });

    test('lap returns the run and restarts from zero', () {
      var now = DateTime(2026, 1, 1, 12);
      final t = ActiveTimer(() => now)..start();
      now = now.add(const Duration(seconds: 40));
      expect(t.lap(), 40);
      now = now.add(const Duration(seconds: 5));
      expect(t.lap(), 5);
    });

    test('negative reported seconds are stored as zero', () {
      final b = const GameStats().record(_r(1, seconds: -9), 1).book;
      expect(b.totalSeconds, 0);
    });
  });

  group('trend text', () {
    RunRecord rec(int s) => RunRecord(day: 1, score: s, seconds: 1);
    test('needs two runs', () {
      expect(trendText([rec(1)]), isNull);
    });
    test('up, down and steady with the last five', () {
      final up = [
        for (final s in [10, 10, 10, 10, 10, 20, 30, 40, 50, 60]) rec(s),
      ];
      expect(trendText(up), 'Scores trending up, last 5: 20, 30, 40, 50, 60');
      final down = [
        for (final s in [60, 50, 40, 30, 20, 10, 10, 10, 10, 10]) rec(s),
      ];
      expect(trendText(down), startsWith('Scores trending down'));
      final flat = [for (var i = 0; i < 6; i++) rec(10)];
      expect(trendText(flat), startsWith('Scores steady'));
    });
  });

  test('JSON round trip and tolerance of missing fields', () {
    final b = const GameStats()
        .record(_r(7, won: true, seconds: 9, variant: 'A'), 4)
        .book;
    final back = GameStats.fromJson(b.toJson());
    expect(back.toJson(), b.toJson());
    expect(GameStats.fromJson(null).isEmpty, isTrue);
    expect(GameStats.fromJson(<String, Object?>{}).daysPlayed, 0);
  });
}
