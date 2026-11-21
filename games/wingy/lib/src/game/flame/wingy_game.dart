import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';

import '../../core/skins/flyer_skins.dart';
import '../rules/wingy_run.dart';
import 'wingy_painter.dart';

/// Flame view of Wingy. All rules live in [WingyRun] (pure Dart); this class advances the
/// simulation with the frame time, draws it, and reports changes to the UI.
class WingyGame extends FlameGame {
  WingyGame({required this.run, bool reduceMotion = false}) {
    _painter.reduceMotion = reduceMotion;
  }

  WingyRun run;
  final WingyPainter _painter = WingyPainter();

  /// Seconds left of the 3-2-1 countdown after resuming (0 = not counting).
  double countdown = 0;

  /// HUD values changed (score, meter, streak, dash state, phase).
  void Function()? onChanged;

  /// Every simulation event, for haptics and sounds.
  void Function(RunEvent event)? onEvent;

  /// The death animation finished: show the game over dialog.
  void Function()? onGameOver;

  bool _deathReported = false;
  Object? _lastSnapshot;

  set reduceMotion(bool v) => _painter.reduceMotion = v;

  /// Cosmetic flyer skin (looks only; rules and hitbox are unchanged).
  set skin(FlyerSkin v) => _painter.skin = v;

  @override
  Color backgroundColor() => const Color(0xFF1B1446);

  int get countdownNumber => countdown <= 0 ? 0 : countdown.ceil();

  /// Pause the run (pause button or app in background).
  void pause() {
    countdown = 0;
    run.paused = true;
    _notify(force: true);
  }

  /// Resume after a 3-2-1 countdown; taps are ignored until it ends.
  void resume() {
    if (!run.paused) return;
    countdown = 3;
    _notify(force: true);
  }

  /// Tap on the field. Ignored while paused or counting down.
  bool tap() {
    if (run.paused || countdown > 0 || run.isDead) return false;
    run.flap();
    return true;
  }

  bool dash() => run.paused || countdown > 0 ? false : run.dash();

  void newRun(WingyRun next) {
    run = next;
    _deathReported = false;
    countdown = 0;
    _painter.texts.clear();
    _painter.bursts.clear();
    _painter.resetFade();
    _notify(force: true);
  }

  /// After a revive the run continues; allow the next death to report again.
  void revived() {
    _deathReported = false;
    _notify(force: true);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final step = min(dt, 0.1);
    if (countdown > 0) {
      countdown -= step;
      if (countdown <= 0) {
        countdown = 0;
        run.paused = false;
      }
      _notify();
    }
    run.advance(step);
    final events = run.drainEvents();
    for (final e in events) {
      onEvent?.call(e);
    }
    _painter.update(run.paused ? 0 : step, run, events);
    _notify();
    if (run.deathAnimationDone && !_deathReported) {
      _deathReported = true;
      onGameOver?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _painter.paint(canvas, Size(size.x, size.y), run);
  }

  void _notify({bool force = false}) {
    final snap = (
      run.score,
      run.meter,
      run.perfectStreak,
      run.phase,
      run.isDashing,
      run.paused,
      countdownNumber,
      run.canDash,
      run.bestScore,
    );
    if (force || snap != _lastSnapshot) {
      _lastSnapshot = snap;
      onChanged?.call();
    }
  }
}
