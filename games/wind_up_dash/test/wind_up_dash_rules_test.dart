import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_wind_up_dash/wind_up_dash.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A bot that jumps once per hazard, timed so the top of the arc is over the middle of it.
/// It is the fairness test: if a fair track needs this and nothing else, it never dies.
DashGame _runBot(DashGame g, double distance, {double lateBy = 0}) {
  final start = g.course?.startSpeed ?? 32;
  while (!g.over && g.best < distance) {
    final h = g.track.nextFrom(g.x - dashWidth);
    if (h != null && g.grounded) {
      final reach = dashSpeed(g.x, start: start) * dashAirTime;
      if (g.x >= h.mid - reach / 2 + lateBy && g.x < h.end) g.jump();
    }
    g.step();
  }
  return g;
}

DashGame _course(int i, {int seed = 0}) =>
    DashGame(seed: seed, course: dashCourses[i]);

void main() {
  group('Track (kept from Runner)', () {
    test('the same seed is the same track; different seeds differ', () {
      List<double> xs(int seed) {
        final t = DashTrack(seed)..extendTo(3000);
        return [for (final h in t.hazards) h.x];
      }

      expect(xs(5), xs(5));
      expect(xs(5), isNot(xs(6)));
    });

    test('fair by construction: gap size, block size and spacing', () {
      for (var seed = 1; seed <= 40; seed++) {
        final t = DashTrack(seed)..extendTo(8000);
        expect(t.hazards.first.x, firstHazardAt);
        for (var i = 0; i < t.hazards.length; i++) {
          final h = t.hazards[i];
          final v = dashSpeed(h.x);
          if (h.kind == HazardKind.gap) {
            expect(
              h.width,
              lessThanOrEqualTo(v * dashAirTime * maxGapShare + 1e-9),
            );
            expect(h.height, 0);
          } else {
            expect(h.width, inInclusiveRange(blockMinWidth, blockMaxWidth));
            expect(h.height, inInclusiveRange(blockMinHeight, blockMaxHeight));
            expect(
              h.height,
              lessThan(dashJumpSpeed * dashJumpSpeed / (2 * dashGravity)),
            );
          }
          if (i > 0) {
            final prev = t.hazards[i - 1];
            expect(
              h.x - prev.end,
              greaterThanOrEqualTo(minSpacing(prev.end) - 1e-9),
            );
          }
        }
      }
    });

    test(
      'a well-timed jump always works: the bot runs 6000 units on 40 seeds',
      () {
        for (var seed = 1; seed <= 40; seed++) {
          final g = _runBot(DashGame(seed: seed), 6000);
          expect(
            g.over,
            isFalse,
            reason: 'seed $seed ended at ${g.x} ${g.end}',
          );
        }
      },
    );

    test('not jumping dies on the first hazard', () {
      final g = DashGame(seed: 3);
      for (var i = 0; i < 120 * 20 && !g.over; i++) {
        g.step();
      }
      expect(g.over, isTrue);
      expect(g.end, isIn([DashEnd.fell, DashEnd.hit]));
    });

    test('the jump is a fixed arc; no double jump in the air', () {
      final g = DashGame(seed: 1);
      expect(g.jump(), isTrue);
      expect(g.jump(), isFalse);
      var top = 0.0;
      var steps = 0;
      while (!g.grounded && steps < 1000) {
        g.step();
        top = max(top, g.y);
        steps++;
      }
      expect(
        top,
        closeTo(dashJumpSpeed * dashJumpSpeed / (2 * dashGravity), 0.3),
      );
      expect(steps * dashStep, closeTo(dashAirTime, 0.03));
    });

    test('speed rises with distance and is capped', () {
      expect(dashSpeed(0), 32);
      expect(dashSpeed(700), greaterThan(dashSpeed(0)));
      expect(dashSpeed(100000), 60);
      expect(dashSpeed(0, start: 52), 52);
      expect(dashSpeed(1000, start: 52), 60);
    });

    test('score is distance over 10 plus 5 per star; Continue keeps it', () {
      final g = DashGame(seed: 3);
      while (!g.over) {
        g.step();
      }
      final before = g.score;
      expect(before, greaterThan(0));
      g.grantContinue();
      expect(g.over, isFalse);
      expect(g.grounded, isTrue);
      expect(g.score, before);
      expect(g.x, lessThan(g.best));
      final h = g.track.nextFrom(g.x)!;
      expect(h.x - g.x, closeTo(20, 1e-9));
    });
  });

  group('Courses', () {
    test('five courses: lengths, start speeds, mixes and seeds', () {
      expect(dashCourses.length, 5);
      expect(
        [for (final c in dashCourses) c.length],
        [600, 900, 1200, 1600, 2000],
      );
      expect([for (final c in dashCourses) c.startSpeed], [32, 36, 40, 46, 52]);
      expect(
        [for (final c in dashCourses) c.seed],
        [1009, 2018, 3027, 4036, 5045],
      );
      expect(dashCourses[0].mix, DashMix.blocks);
      expect(dashCourses[1].mix, DashMix.gaps);
      expect(dashCourses[2].mix, DashMix.both);
      expect(dashCourses[3].tight, isTrue);
    });

    test('a course track is fixed, ends before the flag and keeps the mix', () {
      for (final c in dashCourses) {
        final a = c.newTrack(), b = c.newTrack();
        expect(
          [for (final h in a.hazards) h.x],
          [for (final h in b.hazards) h.x],
        );
        expect(a.hazards, isNotEmpty);
        expect(a.hazards.first.x, firstHazardAt);
        for (final h in a.hazards) {
          expect(h.end, lessThanOrEqualTo(c.length - 40 + 1e-9));
          if (c.mix == DashMix.blocks) expect(h.kind, HazardKind.block);
          if (c.mix == DashMix.gaps) expect(h.kind, HazardKind.gap);
        }
      }
      final kinds = dashCourses[2]
          .newTrack()
          .hazards
          .map((h) => h.kind)
          .toSet();
      expect(kinds, {HazardKind.gap, HazardKind.block});
    });

    test('courses are fair: gap, block and spacing limits at their speed', () {
      for (final c in dashCourses) {
        final t = c.newTrack();
        for (var i = 0; i < t.hazards.length; i++) {
          final h = t.hazards[i];
          final v = dashSpeed(h.x, start: c.startSpeed);
          if (h.kind == HazardKind.gap) {
            expect(
              h.width,
              lessThanOrEqualTo(v * dashAirTime * maxGapShare + 1e-9),
            );
          }
          if (i > 0) {
            final p = t.hazards[i - 1];
            expect(
              h.x - p.end,
              greaterThanOrEqualTo(
                minSpacing(p.end, start: c.startSpeed) - 1e-9,
              ),
            );
            final flagBetween = c.flags.any(
              (f) => f > p.end - flagClearAfter && f < h.x + flagClearBefore,
            );
            if (!c.tight && !flagBetween) {
              expect(
                h.x - p.end,
                lessThanOrEqualTo(
                  minSpacing(p.end, start: c.startSpeed) + 30 + 1e-9,
                ),
                reason: 'course ${c.number} hazard $i',
              );
            }
          }
        }
      }
    });

    test(
      'no hazard sits on a flag or right after it, so a restart has room',
      () {
        for (final c in dashCourses) {
          final t = c.newTrack();
          for (final f in c.flags) {
            for (final h in t.hazards) {
              final clash =
                  h.x < f + flagClearAfter && h.end > f - flagClearBefore;
              expect(
                clash,
                isFalse,
                reason: 'course ${c.number} flag $f ${h.x}',
              );
            }
          }
        }
        expect(dashCourses[0].flags, [300]);
        expect(dashCourses[4].flags, [300, 600, 900, 1200, 1500, 1800]);
      },
    );

    test(
      'the bot clears all five courses to the flag, with 3 course stars',
      () {
        for (var i = 0; i < 5; i++) {
          final g = _runBot(_course(i), 1e9);
          expect(g.finished, isTrue, reason: 'course ${i + 1} ${g.end} ${g.x}');
          expect(g.crashes, 0);
          expect(
            g.bounces,
            0,
            reason: 'a bot never hits, so the spring is unused',
          );
          expect(g.checkpoint, dashCourses[i].flags.length);
        }
      },
    );

    test('the bot also clears the courses with a full spring meter', () {
      for (var i = 0; i < 5; i++) {
        final g = _course(i)..meter = SpringMeter(springStars);
        _runBot(g, 1e9);
        expect(g.finished, isTrue, reason: 'course ${i + 1}');
        expect(g.bounces, 0);
      }
    });

    test('a jump up to 0.05 s late still clears (room to time it)', () {
      for (var i = 0; i < 5; i++) {
        final v = dashCourses[i].startSpeed;
        final g = _runBot(_course(i), 1e9, lateBy: v * 0.03);
        expect(g.finished, isTrue, reason: 'course ${i + 1}');
      }
    });

    test('unlock chain: course k+1 opens with 1 star on course k', () {
      expect(dashCourseOpen(0, [0, 0, 0, 0, 0]), isTrue);
      expect(dashCourseOpen(1, [0, 0, 0, 0, 0]), isFalse);
      expect(dashCourseOpen(1, [1, 0, 0, 0, 0]), isTrue);
      expect(dashCourseOpen(2, [1, 0, 0, 0, 0]), isFalse);
      expect(dashCourseOpen(4, [3, 2, 1, 1, 0]), isTrue);
      expect(dashCourseOpen(2, [3, 0, 3, 3, 3]), isFalse);
    });
  });

  group('Stars', () {
    test(
      'a star hangs over the middle of every hazard at the top of the arc',
      () {
        for (final c in dashCourses) {
          final t = c.newTrack();
          for (final h in t.hazards) {
            expect(
              t.stars.where(
                (s) =>
                    !s.ground &&
                    (s.x - h.mid).abs() < 1e-9 &&
                    s.y == hazardStarHeight,
              ),
              hasLength(1),
            );
          }
        }
      },
    );

    test('ground stars come in lines of three on free ground', () {
      final t = DashTrack(4)..extendTo(4000);
      final ground = t.stars.where((s) => s.ground).toList();
      expect(ground.length % 3, 0);
      expect(ground, isNotEmpty);
      for (final s in ground) {
        for (final h in t.hazards) {
          expect(s.x > h.x - 5 && s.x < h.end + 5, isFalse);
        }
      }
    });

    test('about one star per 25 units on the courses', () {
      for (final c in dashCourses) {
        final per = c.length / c.newTrack().stars.length;
        expect(per, inInclusiveRange(15, 40), reason: 'course ${c.number}');
      }
    });

    test('the bot collects every hazard star; each is worth 5 points', () {
      final g = _runBot(_course(2), 1e9);
      final air = g.track.stars.where((s) => !s.ground).length;
      final taken = g.taken.where((i) => !g.track.stars[i].ground).length;
      expect(taken, air);
      expect(g.score, (g.best / 10).floor() + 5 * g.starCount);
      expect(g.score, greaterThan((g.best / 10).floor() + 5 * air - 1));
    });

    test('a star is picked once; a miss leaves it', () {
      final g = _course(0);
      final s = g.track.stars.first; // ground star line at 41
      g.x = s.x - 1;
      g.step();
      g.step();
      expect(g.starCount, greaterThanOrEqualTo(1));
      final n = g.starCount;
      g.x = s.x - 1;
      g.step();
      expect(g.starCount, n + (g.starCount - n)); // no double count
      expect(g.taken.length, g.taken.toSet().length);
    });

    test('course stars: 1 for the flag, 2 at 70 percent, 3 at 90 percent', () {
      expect(dashCourseStars(finished: false, picked: 99, total: 100), 0);
      expect(dashCourseStars(finished: true, picked: 0, total: 100), 1);
      expect(dashCourseStars(finished: true, picked: 69, total: 100), 1);
      expect(dashCourseStars(finished: true, picked: 70, total: 100), 2);
      expect(dashCourseStars(finished: true, picked: 89, total: 100), 2);
      expect(dashCourseStars(finished: true, picked: 90, total: 100), 3);
      expect(dashCourseStars(finished: true, picked: 0, total: 0), 3);
      final g = _runBot(_course(0), 1e9);
      expect(g.courseStars, 3);
    });

    test(
      'stars thresholds are 150 / 350 / 700; coins 1 per 25, at most 20',
      () {
        expect(dashStarScores, [150, 350, 700]);
        expect(dashCoins(24), 0);
        expect(dashCoins(25), 1);
        expect(dashCoins(499), 19);
        expect(dashCoins(5000), 20);
        expect(arcadeStars(149, dashStarScores), 0);
        expect(arcadeStars(150, dashStarScores), 1);
        expect(arcadeStars(700, dashStarScores), 3);
      },
    );

    test('the course payout is the difference over its best', () {
      expect(max(0, dashCoins(300) - dashCoins(200)), 4);
      expect(max(0, dashCoins(200) - dashCoins(300)), 0);
    });
  });

  group('Spring meter', () {
    test('10 stars fill it; the bulbs light per 2 stars', () {
      final m = SpringMeter();
      for (var i = 1; i <= 9; i++) {
        expect(m.add(), isFalse);
        expect(m.bulbs, i ~/ 2);
        expect(m.full, isFalse);
      }
      expect(m.add(), isTrue);
      expect(m.full, isTrue);
      expect(m.bulbs, 5);
      expect(m.add(), isFalse, reason: 'already full');
      expect(m.stars, springStars);
      expect(m.absorb(), isTrue);
      expect(m.stars, 0);
      expect(m.absorb(), isFalse);
    });

    test('a full meter takes one block hit: the car bounces back and hops', () {
      final g = _course(0)..meter = SpringMeter(springStars);
      final b = g.track.hazards.first; // a block
      g.x = b.x - 10;
      var steps = 0;
      while (g.bounces == 0 && !g.over && steps++ < 600) {
        g.step();
      }
      expect(g.over, isFalse);
      expect(g.bounces, 1);
      expect(g.meter.stars, 0);
      expect(g.drainEvents(), contains(DashEvent.bounce));
      expect(g.x, lessThan(b.x - dashWidth / 2));
      // it hops over the brick and runs on
      while (g.x < b.end + 10 && !g.over && steps++ < 2000) {
        g.step();
      }
      expect(g.over, isFalse, reason: 'the hop clears the brick');
      expect(g.crashes, 0);
    });

    test('the second block hit with an empty meter crashes', () {
      final g = _course(0)..meter = SpringMeter(springStars);
      final b = g.track.hazards.first;
      g.x = b.x - 10;
      while (g.bounces == 0) {
        g.step();
      }
      // knock the car into the same brick again, flat on the ground
      g.x = b.x - 1;
      g.y = 0;
      g.step();
      expect(g.end, DashEnd.hit);
      expect(g.crashes, 1);
    });

    test('the spring never saves from a gap', () {
      final g = _course(1)..meter = SpringMeter(springStars);
      final gap = g.track.hazards.first;
      g.x = gap.x - 2;
      for (var i = 0; i < 400 && !g.over; i++) {
        g.step();
      }
      expect(g.end, DashEnd.fell);
      expect(g.meter.full, isTrue, reason: 'unused');
    });

    test('stars wind it up: ten picked, then it is full', () {
      final g = _runBot(_course(2), 1e9);
      expect(g.starCount, greaterThan(10));
      expect(g.meter.full, isTrue);
    });
  });

  group('Checkpoints', () {
    test('a crash restarts on the last flag with the stars of that flag', () {
      final g = _course(2);
      // run the bot to just past the first flag
      while (g.checkpoint < 1) {
        final h = g.track.nextFrom(g.x - dashWidth);
        if (h != null && g.grounded) {
          final reach = dashSpeed(g.x, start: 40) * dashAirTime;
          if (g.x >= h.mid - reach / 2 && g.x < h.end) g.jump();
        }
        g.step();
      }
      expect(g.checkpoint, 1);
      expect(g.checkpointX, 300);
      final starsAtFlag = g.starCount;
      final tookAtFlag = Set.of(g.taken);
      final meterAtFlag = g.meter.stars;
      expect(g.drainEvents(), contains(DashEvent.checkpoint));
      // keep running without jumping until the car crashes
      for (var i = 0; i < 120 * 30 && !g.over; i++) {
        g.step();
      }
      expect(g.over, isTrue);
      expect(g.crashes, 1);
      expect(g.crashesHere, 1);
      final bestBefore = g.best;
      g.restartAtCheckpoint();
      expect(g.over, isFalse);
      expect(g.x, 300);
      expect(g.grounded, isTrue);
      expect(g.taken, tookAtFlag);
      expect(g.starCount, starsAtFlag);
      expect(g.meter.stars, meterAtFlag);
      expect(g.crashes, 1, reason: 'the crash count stays');
      expect(g.best, bestBefore, reason: 'the furthest distance is kept');
      // and the course can still be finished from there
      _runBot(g, 1e9);
      expect(g.finished, isTrue);
    });

    test('before any flag the restart is the start', () {
      final g = _course(0);
      for (var i = 0; i < 120 * 30 && !g.over; i++) {
        g.step();
      }
      expect(g.over, isTrue);
      g.restartAtCheckpoint();
      expect(g.x, 0);
      expect(g.starCount, 0);
    });

    test(
      'crashes on one flag are counted for the hint, and reset at the next',
      () {
        final g = _course(0);
        for (var k = 0; k < 3; k++) {
          for (var i = 0; i < 120 * 30 && !g.over; i++) {
            g.step();
          }
          g.restartAtCheckpoint();
        }
        expect(g.crashes, 3);
        expect(g.crashesHere, 3);
        expect(g.hintJumpAt, isNotNull);
        expect(g.hintJumpAt!, greaterThan(g.x));
      },
    );

    test('a finished course cannot be restarted', () {
      final g = _runBot(_course(0), 1e9);
      g.restartAtCheckpoint();
      expect(g.finished, isTrue);
    });
  });

  group('Input buffer and coyote time', () {
    test('a jump pressed just before landing fires on landing', () {
      final g = DashGame(seed: 1);
      g.jump();
      g.drainEvents();
      while (g.y < 5) {
        g.step();
      }
      while (g.y > 0.6 || !_vyDown(g)) {
        g.step();
      }
      g.drainEvents();
      expect(g.jump(), isFalse, reason: 'in the air: buffered');
      final events = <DashEvent>[];
      for (var i = 0; i < 12; i++) {
        g.step();
        events.addAll(g.drainEvents());
      }
      expect(events, [DashEvent.land, DashEvent.jump]);
      expect(g.y, greaterThan(0));
    });

    test('a jump pressed earlier than the buffer is forgotten', () {
      final g = DashGame(seed: 1);
      g.jump();
      for (var i = 0; i < 20; i++) {
        g.step();
      }
      g.jump(); // high in the air: buffer 0.1 s, landing is 0.6 s away
      var steps = 0;
      while (!g.grounded && steps++ < 400) {
        g.step();
      }
      expect(g.grounded, isTrue);
      g.step();
      expect(g.y, 0, reason: 'no jump on landing');
    });

    test('coyote: a jump within 0.08 s over the gap edge still jumps', () {
      final g = _course(1);
      final gap = g.track.hazards.first;
      g.x = gap.x + 0.5 - 0.0;
      // the centre is over the gap now; 0.05 s later (6 steps) press jump
      for (var i = 0; i < 6; i++) {
        g.step();
      }
      expect(g.over, isFalse);
      expect(g.jump(), isTrue);
      for (var i = 0; i < 400 && !g.over && g.x < gap.end + 3; i++) {
        g.step();
      }
      expect(g.over, isFalse, reason: 'the late jump carries across the gap');
    });

    test('coyote ends: 0.1 s over the gap and the car falls', () {
      final g = _course(1);
      final gap = g.track.hazards.first;
      g.x = gap.x + 0.5;
      for (var i = 0; i < 12; i++) {
        g.step();
      }
      expect(g.end, DashEnd.fell);
    });

    test('they only help: the bot with no buffer behaves the same', () {
      for (var i = 0; i < 5; i++) {
        final g = _runBot(_course(i), 1e9);
        expect(g.finished, isTrue);
      }
    });
  });

  group('Events', () {
    test('jump, land, star, finish and flag events come out in order', () {
      final g = _course(0);
      final all = <DashEvent>[];
      while (!g.over) {
        final h = g.track.nextFrom(g.x - dashWidth);
        if (h != null && g.grounded) {
          final reach = dashSpeed(g.x, start: 32) * dashAirTime;
          if (g.x >= h.mid - reach / 2 && g.x < h.end) g.jump();
        }
        g.step();
        all.addAll(g.drainEvents());
      }
      expect(
        all,
        containsAll([
          DashEvent.jump,
          DashEvent.land,
          DashEvent.star,
          DashEvent.checkpoint,
          DashEvent.finish,
        ]),
      );
      expect(all.last, DashEvent.finish);
    });

    test('a clean pass within 1 unit over a block is a close call', () {
      final g = _course(0);
      final b = g.track.hazards.first;
      g.x = b.x - 30;
      // jump so the car just clears the block top: found by trying launch points
      var found = false;
      for (var x0 = b.x - 22; x0 < b.x - 8 && !found; x0 += 0.25) {
        final t = DashGame(seed: 0, course: dashCourses[0]);
        t.x = x0;
        t.jump();
        var close = false;
        while (t.x < b.end + 6 && !t.over) {
          t.step();
          if (t.drainEvents().contains(DashEvent.closeCall)) close = true;
        }
        if (!t.over && close) found = true;
      }
      expect(found, isTrue);
    });
  });

  group('Progress and migration', () {
    test(
      'the old Runner best score moves to wind_up_dash once; higher wins',
      () async {
        SharedPreferences.setMockInitialValues({'arcade.runner.best': 120});
        final p = await SharedPreferences.getInstance();
        await DashProgress.migrate(p);
        expect(DashProgress(p).best, 120);
        expect(p.containsKey('arcade.runner.best'), isFalse);
        SharedPreferences.setMockInitialValues({
          'arcade.runner.best': 50,
          'arcade.wind_up_dash.best': 200,
        });
        final q = await SharedPreferences.getInstance();
        await DashProgress.migrate(q);
        expect(DashProgress(q).best, 200);
      },
    );

    test(
      'renamedGameIds carries runner to wind_up_dash (web best score)',
      () async {
        expect(renamedGameIds['runner'], 'wind_up_dash');
        final s = MemoryProgressStorage()..data['amc.best.runner'] = '77';
        final p = BrowserProgress(s);
        await p.load();
        expect(p.bestScore('wind_up_dash'), 77);
        expect(s.data.containsKey('amc.best.runner'), isFalse);
        expect(s.data['amc.best.wind_up_dash'], '77');
      },
    );

    test('course stars and bests keep the higher value', () async {
      SharedPreferences.setMockInitialValues({});
      final p = DashProgress(await SharedPreferences.getInstance());
      expect(p.stars, [0, 0, 0, 0, 0]);
      await p.recordCourse(0, 2, 90);
      await p.recordCourse(0, 1, 120);
      expect(p.stars[0], 2);
      expect(p.courseBest[0], 120);
      expect(p.stars[1], 0);
    });

    test('the skill key is renamed and stays speed', () {
      expect(gameSkill['wind_up_dash'], CognitiveSkill.speed);
      expect(gameSkill.containsKey('runner'), isFalse);
    });
  });

  test('the rules are pure Dart: no Flutter, Flame or Android imports', () {
    for (final f in Directory('lib/src/rules').listSync().whereType<File>()) {
      final text = f.readAsStringSync();
      expect(text, isNot(contains('package:flutter')), reason: f.path);
      expect(text, isNot(contains('package:flame')), reason: f.path);
      expect(text, isNot(contains('dart:ui')), reason: f.path);
    }
  });
}

bool _vyDown(DashGame g) =>
    g.y < 8; // past the top of the arc (13.6) and falling
