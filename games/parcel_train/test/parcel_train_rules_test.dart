import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_parcel_train/parcel_train.dart';

TrainGame _free({bool wrap = false, int seed = 1}) =>
    TrainGame(wrap: wrap, random: Random(seed));

TrainGame _course(int n, {int? bumpers, int derails = 0, int? seed}) {
  final c = trainCourses[n - 1];
  return TrainGame(
    course: c,
    bumpers: bumpers,
    derailsBefore: derails,
    random: seed == null ? c.newRandom() : Random(seed),
  );
}

/// A bot that never hits: breadth-first to the golden parcel, the next parcel, then the open gate, and it only
/// takes a step that leaves the train room to move.
class _Bot {
  _Bot(this.g);
  final TrainGame g;
  final Map<TrainCell, int> _visits = {};

  Set<TrainCell> _blockedBody(List<TrainCell> body) =>
      body.sublist(0, body.length - 1).toSet();

  /// Steps from [from] to [to] (cells), or null. [leaves] says after how many moves a wagon cell is free.
  int? _dist(
    TrainCell from,
    TrainCell to,
    Set<TrainCell> wagons, {
    Map<TrainCell, int>? leaves,
  }) {
    final seen = <TrainCell, int>{from: 0};
    final q = [from];
    for (var i = 0; i < q.length; i++) {
      final c = q[i];
      if (c == to) return seen[c];
      for (final d in TrainDir.values) {
        final n = g.landing(c, d);
        if (n == null || seen.containsKey(n)) continue;
        final t = seen[c]! + 1;
        if (leaves != null) {
          final l = leaves[n];
          if (l != null && t < l) continue;
        } else if (wagons.contains(n)) {
          continue;
        }
        seen[n] = t;
        q.add(n);
      }
    }
    return null;
  }

  int _reach(TrainCell from, Set<TrainCell> wagons) {
    final seen = {from};
    final q = [from];
    for (var i = 0; i < q.length; i++) {
      for (final d in TrainDir.values) {
        final n = g.landing(q[i], d);
        if (n == null || seen.contains(n) || wagons.contains(n)) continue;
        seen.add(n);
        q.add(n);
      }
    }
    return seen.length;
  }

  TrainCell? get target {
    if (g.golden != null) return g.golden;
    if (!g.gateOpen) return g.parcel;
    return g.course?.gate;
  }

  TrainDir? choose() {
    final t = target;
    TrainDir? best;
    var bestScore = -1 << 30;
    for (final d in TrainDir.values) {
      if (d == g.dir.opposite || g.blocked(d)) continue;
      final to = g.landing(g.head, d)!;
      final grows = to == g.parcel;
      final nb = [to, ...g.body];
      if (!grows) nb.removeLast();
      final wagons = _blockedBody(nb);
      final reach = _reach(to, wagons);
      // the wagon at index k of the new train leaves its cell after (length - k - 1) more moves
      final leaves = <TrainCell, int>{
        for (var k = 1; k < nb.length; k++) nb[k]: nb.length - k,
      };
      final tailDist = _dist(to, nb.last, wagons, leaves: leaves);
      final dist = t == null
          ? null
          : (to == t ? 0 : _dist(to, t, wagons, leaves: leaves));
      final onward = [
        for (final d2 in TrainDir.values)
          if (d2 != d.opposite)
            if (g.landing(to, d2) case final n? when !wagons.contains(n)) n,
      ];
      final safe =
          reach >= nb.length + 4 && tailDist != null && onward.isNotEmpty;
      var score = reach;
      if (tailDist != null) score += 20000 - tailDist;
      if (safe) score += 100000;
      if (safe && dist != null) score += 50000 - dist * 100;
      score -= (_visits[to] ?? 0) * 60;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  /// Plays until the round ends; returns the number of moves.
  int play({int limit = 4000}) {
    var moves = 0;
    while (!g.over && moves < limit) {
      final d = choose();
      if (d == null) break;
      if (d != g.dir) g.turn(d);
      g.move();
      _visits[g.head] = (_visits[g.head] ?? 0) + 1;
      moves++;
    }
    return moves;
  }
}

void main() {
  group('Free ride (the old rules, renamed)', () {
    test('starts with three segments heading right, parcel 4 cells ahead', () {
      final g = _free();
      expect(g.length, trainStartLength);
      expect(g.dir, TrainDir.right);
      expect(g.body.contains(g.parcel), isFalse);
      expect(g.parcel, TrainCell(g.head.x + 4, g.head.y));
    });

    test('a turn straight back or a repeat is ignored; two turns queue', () {
      final g = _free();
      g.turn(TrainDir.left);
      g.move();
      expect(g.dir, TrainDir.right);
      g.turn(TrainDir.up);
      g.turn(TrainDir.left);
      g.turn(TrainDir.down); // third is dropped
      g.move();
      expect(g.dir, TrainDir.up);
      g.move();
      expect(g.dir, TrainDir.left);
      g.move();
      expect(g.dir, TrainDir.left);
    });

    test('a parcel adds a wagon and ten points', () {
      final g = _free();
      final h = g.head;
      g.parcel = TrainCell(h.x + 1, h.y);
      g.move();
      expect(g.length, 4);
      expect(g.score, trainPointsPerParcel);
      expect(g.body.contains(g.parcel), isFalse);
      expect(g.colors.length, g.body.length);
    });

    test('a wall ends Free ride, or wraps when the edges wrap', () {
      final g = _free();
      for (var i = 0; i < 20 && !g.over; i++) {
        g.move();
      }
      expect(g.end, TrainEnd.wall);
      final w = _free(wrap: true);
      for (var i = 0; i < 40; i++) {
        w.move();
      }
      expect(w.over, isFalse);
    });

    test('hitting the train ends it; the moving tail cell is free', () {
      final g = _free();
      g.body
        ..clear()
        ..addAll(const [
          TrainCell(5, 5),
          TrainCell(5, 6),
          TrainCell(6, 6),
          TrainCell(6, 5),
        ]);
      g.dir = TrainDir.up;
      g.parcel = const TrainCell(0, 0);
      g.turn(TrainDir.right);
      g.move();
      expect(g.over, isFalse);
      final h = _free();
      h.body
        ..clear()
        ..addAll(const [
          TrainCell(5, 5),
          TrainCell(5, 6),
          TrainCell(6, 6),
          TrainCell(6, 5),
          TrainCell(6, 4),
          TrainCell(5, 4),
        ]);
      h.dir = TrainDir.up;
      h.parcel = const TrainCell(0, 0);
      h.turn(TrainDir.right);
      h.move();
      expect(h.end, TrainEnd.self);
    });

    test('speed curve and caps (Free ride and courses)', () {
      expect(trainInterval(3), closeTo(0.20, 1e-9));
      expect(trainInterval(13), lessThan(trainInterval(3)));
      expect(trainInterval(500), 0.08);
      final c = _course(1);
      expect(c.interval, closeTo(0.26, 1e-9));
      c.body.addAll(List.filled(10, const TrainCell(0, 0)));
      expect(c.interval, closeTo(0.26 - 0.004 * 10, 1e-9));
      for (final course in trainCourses) {
        final g = TrainGame(course: course, random: Random(1));
        g.body.addAll(List.filled(500, const TrainCell(0, 0)));
        expect(g.interval, 0.12);
      }
    });

    test('update moves by the interval and is deterministic by seed', () {
      final a = _free();
      final b = _free();
      expect(a.update(0.19), 0);
      expect(a.update(0.02), 1);
      expect(a.head.x, b.head.x + 1);
      expect(a.parcel, b.parcel);
    });

    test('a full board ends the round as filled', () {
      final g = TrainGame(cols: 4, rows: 1, random: Random(1));
      expect(g.length, 3);
      g.parcel = const TrainCell(3, 0);
      g.move();
      expect(g.end, TrainEnd.filled);
    });

    test('fixed stepper, coins and stars', () {
      final s = FixedStepper(dt: 0.125);
      expect(s.advance(0.25), 2);
      expect(arcadeCoins(95, perCoins: 20), 4);
      expect(trainCoins(95), 4);
      expect(trainCoins(5000), 20);
      expect(arcadeStars(150, trainStarScores), 2);
    });
  });

  group('courses', () {
    test('five layouts parse, none bigger than 15, start and gate set', () {
      expect(trainCourses.length, trainCourseCount);
      expect([for (final c in trainCourses) c.goal], [5, 8, 10, 12, 15]);
      for (final c in trainCourses) {
        expect(c.cols, lessThanOrEqualTo(15), reason: c.name);
        expect(c.rows, lessThanOrEqualTo(15), reason: c.name);
        expect(c.tile(c.gate.x, c.gate.y), TrainTile.gate);
        // two free cells behind the engine, four free cells ahead
        for (var i = -2; i <= 4; i++) {
          expect(c.solid(c.start.x + i, c.start.y), isFalse, reason: c.name);
        }
      }
      expect(trainCourses[0].obstacleCount, 0);
      expect(trainCourses[2].tunnelPairs.length, 4);
      expect(trainCourses[3].tiles.contains(TrainTile.pond), isTrue);
    });

    test('every free cell and the gate are reachable', () {
      for (final c in trainCourses) {
        final g = TrainGame(course: c, random: Random(1));
        g.gateOpen = true;
        final seen = {c.start};
        final q = [c.start];
        for (var i = 0; i < q.length; i++) {
          for (final d in TrainDir.values) {
            final n = g.landing(q[i], d);
            if (n != null && seen.add(n)) q.add(n);
          }
        }
        expect(seen.contains(c.gate), isTrue, reason: c.name);
        for (var y = 0; y < c.rows; y++) {
          for (var x = 0; x < c.cols; x++) {
            if (c.tile(x, y) == TrainTile.free) {
              expect(
                seen.contains(TrainCell(x, y)),
                isTrue,
                reason: '${c.name} $x,$y',
              );
            }
          }
        }
      }
    });

    test(
      'parcels: first 4 ahead, never 2 ahead, never a nook, golden in a corner',
      () {
        for (final c in trainCourses) {
          for (var seed = 0; seed < 40; seed++) {
            final g = TrainGame(course: c, random: Random(seed));
            expect(
              g.parcel,
              TrainCell(c.start.x + 4, c.start.y),
              reason: c.name,
            );
            final gold = g.golden!;
            expect(g.isNook(gold.x, gold.y), isFalse);
            expect(c.tile(gold.x, gold.y), TrainTile.free);
            expect(gold == g.parcel, isFalse);
            // later parcels
            final bot = _Bot(g);
            for (var k = 0; k < 4 && !g.over; k++) {
              final before = g.eaten;
              for (var s = 0; s < 400 && g.eaten == before && !g.over; s++) {
                final d = bot.choose();
                if (d == null) break;
                if (d != g.dir) g.turn(d);
                g.move();
              }
              final p = g.parcel;
              if (p == null) break;
              expect(g.isNook(p.x, p.y), isFalse, reason: '${c.name} $p');
              expect(g.body.contains(p), isFalse);
              expect(p == g.golden, isFalse);
              expect(c.tile(p.x, p.y), TrainTile.free);
              final a1 = TrainCell(g.head.x + g.dir.dx, g.head.y + g.dir.dy);
              final a2 = TrainCell(
                g.head.x + 2 * g.dir.dx,
                g.head.y + 2 * g.dir.dy,
              );
              expect(p == a1 || p == a2, isFalse, reason: '${c.name} ahead');
            }
          }
        }
      },
    );

    test('free ride parcels are never in a nook', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = _free(seed: seed);
        for (var i = 0; i < 20; i++) {
          final p = g.parcel!;
          expect(g.isNook(p.x, p.y), isFalse);
          g.parcel = p;
          g.body.insert(0, TrainCell((p.x + 14) % 15, p.y));
          g.body.removeLast();
          g.move();
          if (g.over) break;
        }
      }
    });

    test('parcel colours cycle in a fixed order and wagons keep theirs', () {
      final g = _free();
      final seen = <int>[];
      for (var i = 0; i < 5; i++) {
        seen.add(g.parcelColor);
        final p = g.parcel!;
        g.body
          ..clear()
          ..addAll([
            TrainCell(p.x - 1, p.y),
            TrainCell(p.x - 2, p.y),
            TrainCell(p.x - 3, p.y),
          ]);
        g.colors.removeRange(3, g.colors.length);
        g.dir = TrainDir.right;
        g.move();
      }
      expect(seen, [0, 1, 2, 3, 0]);
      expect(g.colors.sublist(3), [0, 1, 2, 3, 0].sublist(4));
    });
  });

  group('station gate', () {
    test(
      'closed gate is a wall; opens at the goal; arrival ends the round',
      () {
        final c = trainCourses[0];
        final g = _course(1, bumpers: 0);
        expect(g.gateOpen, isFalse);
        expect(
          g.landing(TrainCell(c.gate.x - 1, c.gate.y), TrainDir.right),
          isNull,
        );
        for (var i = 0; i < c.goal; i++) {
          final p = g.parcel!;
          g.body
            ..clear()
            ..addAll([
              TrainCell(p.x - 1, p.y),
              TrainCell(p.x - 2, p.y),
              TrainCell(p.x - 3, p.y),
            ]);
          g.dir = TrainDir.right;
          g.move();
        }
        expect(g.gateOpen, isTrue);
        expect(g.drainEvents(), contains(TrainEvent.gateOpen));
        g.body
          ..clear()
          ..addAll([
            TrainCell(c.gate.x - 1, c.gate.y),
            TrainCell(c.gate.x - 2, c.gate.y),
            TrainCell(c.gate.x - 3, c.gate.y),
          ]);
        g.dir = TrainDir.right;
        g.move();
        expect(g.end, TrainEnd.arrived);
        expect(g.head, c.gate);
        expect(g.drainEvents(), contains(TrainEvent.arrive));
      },
    );

    test('a closed gate costs a bumper like a wall', () {
      final c = trainCourses[0];
      final g = _course(1);
      g.body
        ..clear()
        ..addAll([
          TrainCell(c.gate.x - 1, c.gate.y),
          TrainCell(c.gate.x - 2, c.gate.y),
          TrainCell(c.gate.x - 3, c.gate.y),
        ]);
      g.dir = TrainDir.right;
      g.move();
      expect(g.waiting, isTrue);
      expect(g.bumpers, 2);
      expect(g.over, isFalse);
    });
  });

  group('bumpers', () {
    test('a hit uses one, the train waits, blocked turns are ignored', () {
      final g = _course(2);
      // drive left into the block stack? use the top edge instead
      g.body
        ..clear()
        ..addAll(const [TrainCell(6, 0), TrainCell(5, 0), TrainCell(4, 0)]);
      g.dir = TrainDir.right;
      g.turn(TrainDir.up);
      g.move();
      expect(g.waiting, isTrue);
      expect(g.bumpers, 2);
      expect(g.bumpersUsed, 1);
      expect(g.head, const TrainCell(6, 0));
      expect(g.update(5), 0, reason: 'the clock does not run while it waits');
      g.turn(TrainDir.up); // blocked by the edge
      g.turn(TrainDir.left); // straight back into the wagons
      expect(g.waiting, isTrue);
      g.turn(TrainDir.right);
      expect(g.waiting, isFalse);
      expect(g.update(0.01), 1);
      expect(g.head, const TrainCell(7, 0));
    });

    test('the fourth hit derails', () {
      final g = _course(1);
      g.body
        ..clear()
        ..addAll(const [TrainCell(6, 0), TrainCell(5, 0), TrainCell(4, 0)]);
      g.dir = TrainDir.up;
      for (var i = 0; i < 3; i++) {
        g.move();
        expect(g.over, isFalse);
        expect(g.waiting, isTrue);
        g.turn(TrainDir.up); // still blocked: ignored
        expect(g.waiting, isTrue);
        g.waiting = false; // (a turn to a free cell would free it)
      }
      expect(g.bumpers, 0);
      g.move();
      expect(g.end, TrainEnd.derail);
      expect(g.drainEvents(), contains(TrainEvent.derail));
    });

    test('a wagon and an obstacle are bumps too', () {
      final g = _course(2);
      g.body
        ..clear()
        ..addAll(const [TrainCell(2, 2), TrainCell(2, 3), TrainCell(2, 4)]);
      g.dir = TrainDir.right; // (3,2) is a block
      g.move();
      expect(g.waiting, isTrue);
    });
  });

  group('tunnels', () {
    test('the head comes out of the partner mouth, the wagons follow', () {
      final c = trainCourses[2];
      final a = TrainCell(5, 3);
      final b = c.tunnelPairs[a]!;
      expect(b, const TrainCell(9, 9));
      final g = _course(3);
      g.body
        ..clear()
        ..addAll(const [TrainCell(4, 3), TrainCell(3, 3), TrainCell(2, 3)]);
      g.colors
        ..clear()
        ..addAll([4, 4, 4]);
      g.dir = TrainDir.right;
      g.parcel = const TrainCell(14, 12);
      g.move();
      expect(g.head, b);
      expect(g.drainEvents(), contains(TrainEvent.tunnel));
      g.move();
      expect(g.head, const TrainCell(10, 9));
      expect(g.body[1], b);
      expect(g.body[2], const TrainCell(4, 3));
      expect(g.over, isFalse);
    });

    test('a mouth with a wagon in it is occupied: entering the pair bumps', () {
      final g = _course(3);
      g.body
        ..clear()
        ..addAll(const [TrainCell(4, 3), TrainCell(9, 9), TrainCell(10, 9)]);
      g.dir = TrainDir.right;
      g.parcel = const TrainCell(14, 12);
      g.move(); // wants (5,3) -> (9,9), a wagon sits there
      expect(g.waiting, isTrue);
    });
  });

  group('stars, score, unlock', () {
    test('stars: deliver, golden, no bumper and no derail', () {
      int s(bool a, bool gd, int b, int d) =>
          trainCourseStars(arrived: a, golden: gd, bumpersUsed: b, derails: d);
      expect(s(false, true, 0, 0), 0);
      expect(s(true, false, 0, 0), 1);
      expect(s(true, true, 1, 0), 2);
      expect(s(true, true, 0, 1), 2);
      expect(s(true, true, 0, 0), 3);
    });

    test('unlock chain: a course opens with one star on the one before', () {
      expect(trainCourseOpen(0, const [0, 0, 0, 0, 0]), isTrue);
      expect(trainCourseOpen(1, const [0, 0, 0, 0, 0]), isFalse);
      expect(trainCourseOpen(1, const [1, 0, 0, 0, 0]), isTrue);
      expect(trainCourseOpen(2, const [1, 0, 0, 0, 0]), isFalse);
      expect(trainCourseOpen(4, const [3, 3, 3, 1, 0]), isTrue);
    });

    test(
      'course score: 10 per parcel, 30 golden, 5 per bumper left on arrival',
      () {
        final g = _course(1);
        g.eaten = 5;
        g.goldenTaken = true;
        expect(g.score, 80);
        g.end = TrainEnd.arrived;
        expect(g.score, 95);
        g.bumpers = 0;
        expect(g.score, 80);
      },
    );
  });

  group('fairness: the bot clears every course', () {
    for (final bumpers in [3, 0]) {
      for (final c in trainCourses) {
        test('${c.name}, $bumpers bumpers, 20 seeds, golden and 3 stars', () {
          for (var seed = 1; seed <= 20; seed++) {
            final g = TrainGame(
              course: c,
              bumpers: bumpers,
              random: Random(seed * 7919),
            );
            final moves = _Bot(g).play();
            expect(
              g.end,
              TrainEnd.arrived,
              reason:
                  'seed $seed after $moves moves, ${g.eaten} parcels, head ${g.head} parcel ${g.parcel} golden ${g.golden} gate open ${g.gateOpen}',
            );
            expect(g.bumpersUsed, 0, reason: 'seed $seed');
            expect(g.stars, 3, reason: 'seed $seed');
            expect(g.eaten, greaterThanOrEqualTo(c.goal));
          }
        });
        test('${c.name} with the course seed', () {
          final g = TrainGame(
            course: c,
            bumpers: bumpers,
            random: c.newRandom(),
          );
          _Bot(g).play();
          expect(g.stars, 3);
        });
      }
    }
  });

  group('purity and ids', () {
    test('lib/src/rules has no Flutter or platform imports', () {
      for (final f in Directory('lib/src/rules').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final text = f.readAsStringSync();
        expect(
          text.contains("import 'package:flutter"),
          isFalse,
          reason: f.path,
        );
        expect(text.contains('dart:ui'), isFalse, reason: f.path);
        expect(text.contains('dart:io'), isFalse, reason: f.path);
      }
    });

    test('a renamed id keeps its saved best (game_core)', () {
      expect(renamedGameIds['snake'], 'parcel_train');
    });
  });
}
