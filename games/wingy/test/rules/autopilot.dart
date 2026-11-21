import 'package:game_wingy/src/game/rules/spire.dart';
import 'package:game_wingy/src/game/rules/wingy_run.dart';
import 'package:game_wingy/src/game/rules/world.dart';

/// Reference autopilot: flap when the hero falls below the next gap center (plus a margin).
/// Used by the reachability and determinism tests.
class Autopilot {
  Autopilot({this.margin = 30});
  final double margin;

  SpirePair? target(WingyRun run) {
    for (final p in run.pairs) {
      if (WingyWorld.heroX <= p.right + WingyWorld.heroRadius) return p;
    }
    return null;
  }

  /// Decides and applies a tap for the current step. Returns true if it flapped.
  bool act(WingyRun run) {
    final p = target(run);
    if (p == null) return false;
    final eta = (p.x - WingyWorld.heroX).clamp(0, 400) / run.scrollSpeed;
    var goal = p.centerAt(p.age + eta);
    final inside = WingyWorld.heroX + WingyWorld.heroRadius > p.left;
    final i = run.pairs.indexOf(p);
    if (inside && i + 1 < run.pairs.length) {
      final n = run.pairs[i + 1];
      if (n.baseCenterY > goal + 40 && WingyWorld.heroX > p.x) {
        // Next gap is clearly lower: stop flapping and let gravity do the work, unless the
        // free fall would still hit the bottom spire before leaving this column.
        final t =
            (p.right + WingyWorld.heroRadius - WingyWorld.heroX) /
            run.scrollSpeed;
        final yExit = run.y + run.vy * t + 0.5 * WingyWorld.gravity * t * t;
        final bottomExit = p.centerAt(p.age + t) + p.gapHeight / 2;
        if (yExit + WingyWorld.heroRadius > bottomExit - 8) {
          run.flap();
          return true;
        }
        return false;
      }
      if (!p.drifting) {
        // Lean toward the next gap, but stay well inside this one.
        final lim = p.gapHeight / 2 - 50;
        goal = n.baseCenterY.clamp(goal - lim, goal + lim);
      }
    }
    if (run.y > goal + margin) {
      run.flap();
      return true;
    }
    return false;
  }
}

/// Runs [run] with the autopilot until [pairs] pairs are passed, the hero dies, or [maxSeconds].
void fly(
  WingyRun run,
  Autopilot pilot, {
  int pairs = 1 << 30,
  double maxSeconds = 1e9,
}) {
  var t = 0.0;
  while (!run.isDead && run.pairsPassed < pairs && t < maxSeconds) {
    pilot.act(run);
    run.advance(WingyWorld.step);
    t += WingyWorld.step;
  }
}
