import 'dart:math';

import 'gap_generator.dart';
import 'spire.dart';
import 'world.dart';

enum RunPhase { ready, playing, dead }

enum RunEventType {
  flap,
  pass,
  perfect,
  orb,
  dashStart,
  dashEnd,
  shatter,
  hit,
  revive,
}

/// Something that happened during a step; the Flame view and UI turn these into feedback
/// (sounds, haptics, floating "+2" text).
class RunEvent {
  const RunEvent(this.type, {this.points = 0, this.x = 0, this.y = 0});
  final RunEventType type;
  final int points;
  final double x;
  final double y;
}

/// One run of Wingy. Pure Dart, deterministic: randomness comes from the injected [Random],
/// time only from [advance] deltas (fixed internal step of 1/120 s).
class WingyRun {
  WingyRun({
    Random? random,
    this.bestScore = 0,
    int startMeter = 0,
    this.paletteStart = 0,
  }) : _generator = GapGenerator(random ?? Random()),
       meter = startMeter.clamp(0, WingyWorld.meterMax) {
    _spawnPairs();
  }

  final GapGenerator _generator;

  RunPhase phase = RunPhase.ready;
  bool paused = false;

  double y = WingyWorld.heroStartY;
  double vy = 0;
  double time = 0;
  double _accumulator = 0;
  double _nextPairX = WingyWorld.firstPairX;

  final List<SpirePair> pairs = [];
  final List<RunEvent> _events = [];

  int score = 0;
  int bestScore;

  /// Index into [paletteOrder] of the palette this run begins with.
  final int paletteStart;
  int pairsPassed = 0;
  int perfectStreak = 0;
  int maxStreak = 0;
  int perfectPasses = 0;
  int maxBloomBonus = 0;

  /// Perfect passes that earned a Bloom bonus of +3 or more.
  int bloomHits = 0;
  int orbsCollected = 0;
  int coins = 0;
  int meter;
  int dashUses = 0;
  int dashShattered = 0;
  int revivesUsed = 0;

  double dashTimer = 0;
  double graceTimer = 0;
  double floatTimer = 0;
  bool _easing = false;
  double invulnTimer = 0;
  double deathTimer = 0;

  bool get isDashing => dashTimer > 0;
  bool get isGrace => graceTimer > 0;

  /// Recovery float after a dash: low gravity until the timer ends or a tap.
  bool get isFloating => floatTimer > 0;

  /// True during the last [WingyWorld.dashEndingCue] seconds of the dash.
  bool get dashEnding => isDashing && dashTimer <= WingyWorld.dashEndingCue;
  bool get isInvulnerable => invulnTimer > 0;
  bool get isDead => phase == RunPhase.dead;
  bool get canDash =>
      phase == RunPhase.playing &&
      meter >= WingyWorld.meterMax &&
      !isDashing &&
      !paused;

  /// A death animation is over and the game over dialog may show.
  bool get deathAnimationDone =>
      isDead && deathTimer >= WingyWorld.deathAnimation;

  bool get revived => revivesUsed > 0;
  int get revivesLeft => WingyWorld.maxRevives - revivesUsed;
  bool get canRevive => isDead && revivesLeft > 0;

  /// Coins granted at run end for score (1 per 5 points); orb coins are already in [coins].
  int get scoreCoins => score ~/ 5;

  Medal get medal => medalForScore(score);
  Palette get palette => paletteForScore(score, start: paletteStart);

  double get scrollSpeed => min(
    WingyWorld.maxSpeed,
    WingyWorld.startSpeed + WingyWorld.speedPerPass * pairsPassed,
  );

  double get _effectiveSpeed =>
      scrollSpeed * (isDashing ? WingyWorld.dashSpeedFactor : 1);

  /// Events since the last call.
  List<RunEvent> drainEvents() {
    final out = List<RunEvent>.of(_events);
    _events.clear();
    return out;
  }

  // ---- autosave -----------------------------------------------------------

  /// The running run as JSON for the autosave. Not meaningful before the first flap or once dead.
  Map<String, Object?> toJson() => {
    'y': y,
    'vy': vy,
    'time': time,
    'nextPairX': _nextPairX,
    'pairs': [for (final p in pairs) p.toJson()],
    'generator': _generator.toJson(),
    'paletteStart': paletteStart,
    'score': score,
    'pairsPassed': pairsPassed,
    'perfectStreak': perfectStreak,
    'maxStreak': maxStreak,
    'perfectPasses': perfectPasses,
    'maxBloomBonus': maxBloomBonus,
    'bloomHits': bloomHits,
    'orbsCollected': orbsCollected,
    'coins': coins,
    'meter': meter,
    'dashUses': dashUses,
    'dashShattered': dashShattered,
    'revivesUsed': revivesUsed,
    'dashTimer': dashTimer,
    'graceTimer': graceTimer,
    'floatTimer': floatTimer,
    'easing': _easing,
    'invulnTimer': invulnTimer,
  };

  /// Rebuilds a run saved by [toJson], paused and playing. Null when [j] is unusable.
  static WingyRun? restore(Map<String, Object?> j, {required int bestScore}) {
    try {
      double d(String k) => (j[k]! as num).toDouble();
      int i(String k) => (j[k]! as num).toInt();
      final run = WingyRun(
        bestScore: bestScore,
        startMeter: i('meter'),
        paletteStart: i('paletteStart'),
      );
      run.pairs
        ..clear()
        ..addAll([
          for (final p in j['pairs']! as List) SpirePair.fromJson(p as Map),
        ]);
      run._generator.restoreState(j['generator']! as Map);
      run
        ..phase = RunPhase.playing
        ..paused = true
        ..y = d('y')
        ..vy = d('vy')
        ..time = d('time')
        .._nextPairX = d('nextPairX')
        ..score = i('score')
        ..pairsPassed = i('pairsPassed')
        ..perfectStreak = i('perfectStreak')
        ..maxStreak = i('maxStreak')
        ..perfectPasses = i('perfectPasses')
        ..maxBloomBonus = i('maxBloomBonus')
        ..bloomHits = i('bloomHits')
        ..orbsCollected = i('orbsCollected')
        ..coins = i('coins')
        ..dashUses = i('dashUses')
        ..dashShattered = i('dashShattered')
        ..revivesUsed = i('revivesUsed')
        ..dashTimer = d('dashTimer')
        ..graceTimer = d('graceTimer')
        ..floatTimer = d('floatTimer')
        .._easing = j['easing']! as bool
        ..invulnTimer = d('invulnTimer');
      if (run.score > run.bestScore) run.bestScore = run.score;
      run._events.clear();
      return run;
    } on Object {
      return null;
    }
  }

  // ---- input --------------------------------------------------------------

  /// Starts the run without flapping (tests, reviving into play).
  void start() {
    if (phase == RunPhase.ready) phase = RunPhase.playing;
  }

  /// Tap. Starts the run from `ready`. Sets (does not add to) vertical velocity.
  /// Ignored when paused, dead or dashing.
  void flap() {
    if (paused || isDead) return;
    if (phase == RunPhase.ready) phase = RunPhase.playing;
    if (isDashing) return;
    floatTimer = 0;
    vy = WingyWorld.flapVelocity;
    _events.add(RunEvent(RunEventType.flap, x: WingyWorld.heroX, y: y));
  }

  /// Starts Glow Dash if the meter is full. Returns whether it started.
  bool dash() {
    if (!canDash) return false;
    meter = 0;
    dashTimer = WingyWorld.dashDuration;
    graceTimer = 0;
    floatTimer = 0;
    vy = 0;
    y = y.clamp(WingyWorld.dashMinY, WingyWorld.dashMaxY);
    _easing = y < WingyWorld.dashEaseMinY || y > WingyWorld.dashEaseMaxY;
    dashUses++;
    _events.add(RunEvent(RunEventType.dashStart, x: WingyWorld.heroX, y: y));
    return true;
  }

  /// Revives up to [WingyWorld.maxRevives] times per run: hero to the center of the next gap, spires within 300 u ahead
  /// removed, 2 s of invulnerability. Score, streak and meter are unchanged.
  bool revive() {
    if (!canRevive) return false;
    revivesUsed++;
    final next = pairs.where((p) => !p.passed).firstOrNull;
    if (next != null) {
      y = next.centerY;
    } else {
      y = WingyWorld.heroStartY;
    }
    y = y.clamp(
      WingyWorld.heroRadius + 1,
      WingyWorld.groundY - WingyWorld.heroRadius - 1,
    );
    vy = 0;
    final limit = WingyWorld.heroX + WingyWorld.reviveClearDistance;
    pairs.removeWhere((p) => !p.passed && p.left <= limit);
    invulnTimer = WingyWorld.reviveInvulnerability;
    dashTimer = 0;
    graceTimer = 0;
    floatTimer = 0;
    deathTimer = 0;
    phase = RunPhase.playing;
    _events.add(RunEvent(RunEventType.revive, x: WingyWorld.heroX, y: y));
    return true;
  }

  // ---- simulation ---------------------------------------------------------

  /// Advances by [dt] seconds in fixed steps. Does nothing while [paused].
  void advance(double dt) {
    if (paused) return;
    _accumulator += dt;
    while (_accumulator >= WingyWorld.step) {
      _accumulator -= WingyWorld.step;
      _step(WingyWorld.step);
    }
  }

  void _step(double dt) {
    time += dt;
    switch (phase) {
      case RunPhase.ready:
        // Hover.
        y = WingyWorld.heroStartY + 8 * sin(time * 3);
      case RunPhase.dead:
        deathTimer += dt;
        vy = min(vy + WingyWorld.gravity * dt, WingyWorld.terminalVelocity);
        y = min(y + vy * dt, WingyWorld.groundY - WingyWorld.heroRadius);
      case RunPhase.playing:
        _playStep(dt);
    }
  }

  void _playStep(double dt) {
    invulnTimer = max(0, invulnTimer - dt);
    final wasDashing = isDashing;
    if (wasDashing) {
      dashTimer = max(0, dashTimer - dt);
      if (dashTimer == 0) {
        graceTimer = WingyWorld.dashGrace;
        floatTimer = WingyWorld.recoveryFloatDuration;
        vy = 0;
        _applyDashExitGap(dt);
        _events.add(RunEvent(RunEventType.dashEnd, x: WingyWorld.heroX, y: y));
      }
    } else if (graceTimer > 0) {
      graceTimer = max(0, graceTimer - dt);
    }

    if (isDashing) {
      vy = 0;
      _easeToBand(dt);
    } else {
      if (isFloating) {
        floatTimer = max(0, floatTimer - dt);
        vy = min(
          vy + WingyWorld.gravity * WingyWorld.recoveryGravityFactor * dt,
          WingyWorld.recoveryMaxFall,
        );
      } else {
        vy = min(vy + WingyWorld.gravity * dt, WingyWorld.terminalVelocity);
      }
      y += vy * dt;
    }

    final dx = _effectiveSpeed * dt;
    _nextPairX -= dx;
    for (final p in pairs) {
      p.x -= dx;
      p.age += dt;
    }
    pairs.removeWhere((p) => p.right < -WingyWorld.spireWidth);
    _spawnPairs();

    // World bounds.
    final r = WingyWorld.heroRadius;
    if (y + r >= WingyWorld.groundY || y - r <= WingyWorld.ceilingY) {
      if (isInvulnerable) {
        y = y.clamp(r + 1, WingyWorld.groundY - r - 1);
        if (vy > 0 && y >= WingyWorld.groundY - r - 1) vy = 0;
      } else {
        _die();
        return;
      }
    }

    // Spires.
    final spiresHarmless = isDashing || isGrace || isInvulnerable;
    for (final p in pairs) {
      if (p.passed) continue;
      if (!_overlapsColumn(p)) continue;
      if (isDashing) {
        p.shattered = true;
      } else if (!spiresHarmless && _hitsSpire(p)) {
        _die();
        return;
      }
    }

    // Orbs.
    for (final p in pairs) {
      if (!p.hasOrb || p.orbCollected) continue;
      final ox = p.x;
      final oy = p.centerY;
      final d = sqrt(
        (ox - WingyWorld.heroX) * (ox - WingyWorld.heroX) + (oy - y) * (oy - y),
      );
      if (d <= WingyWorld.orbRadius + r) {
        p.orbCollected = true;
        orbsCollected++;
        score += 1;
        meter = min(WingyWorld.meterMax, meter + 1);
        if (coins < WingyWorld.runCoinCap) coins++;
        _bumpBest();
        _events.add(RunEvent(RunEventType.orb, points: 1, x: ox, y: oy));
      }
    }

    // Passing.
    for (final p in pairs) {
      if (p.passed || WingyWorld.heroX <= p.right) continue;
      p.passed = true;
      pairsPassed++;
      _onPass(p);
    }
  }

  /// Eases Wingy toward the mid-screen band, slowing near its edge, at most
  /// [WingyWorld.dashEaseRate] u/s. The dashMinY..dashMaxY clamp stays as a safety bound.
  void _easeToBand(double dt) {
    if (!_easing) return;
    // Aim slightly inside the band so the dash ends clearly within it.
    final target = y < WingyWorld.dashEaseMinY
        ? WingyWorld.dashEaseMinY + WingyWorld.dashEaseInset
        : WingyWorld.dashEaseMaxY - WingyWorld.dashEaseInset;
    final dist = target - y;
    final speed = min(WingyWorld.dashEaseRate, max(dist.abs() * 4, 20.0));
    final move = min(speed * dt, dist.abs());
    y += dist.sign * move;
    if (y == target) _easing = false;
    y = y.clamp(WingyWorld.dashMinY, WingyWorld.dashMaxY);
  }

  bool _overlapsColumn(SpirePair p) {
    final r = WingyWorld.heroRadius;
    return WingyWorld.heroX + r > p.left && WingyWorld.heroX - r < p.right;
  }

  bool _hitsSpire(SpirePair p) {
    final top = p.gapTop;
    final bottom = p.gapBottom;
    return _circleHitsRect(p.left, 0, p.right, top) ||
        _circleHitsRect(p.left, bottom, p.right, WingyWorld.groundY);
  }

  bool _circleHitsRect(double l, double t, double rr, double b) {
    final cx = WingyWorld.heroX.clamp(l, rr);
    final cy = y.clamp(t, b);
    final dx = WingyWorld.heroX - cx;
    final dy = y - cy;
    final r = WingyWorld.heroRadius;
    return dx * dx + dy * dy < r * r;
  }

  void _onPass(SpirePair p) {
    int gained;
    if (p.shattered) {
      gained = WingyWorld.dashPairPoints;
      dashShattered++;
      _events.add(
        RunEvent(RunEventType.shatter, points: gained, x: p.x, y: p.centerY),
      );
    } else {
      final perfect =
          (y - p.centerY).abs() <= p.gapHeight * WingyWorld.perfectFraction / 2;
      if (perfect) {
        perfectStreak++;
        perfectPasses++;
        maxStreak = max(maxStreak, perfectStreak);
        gained = 2;
        if (perfectStreak >= 3) {
          final bloom = min(perfectStreak - 2, WingyWorld.bloomMax);
          gained += bloom;
          maxBloomBonus = max(maxBloomBonus, bloom);
          if (bloom >= 3) bloomHits++;
        }
        _events.add(
          RunEvent(RunEventType.perfect, points: gained, x: p.x, y: y),
        );
      } else {
        perfectStreak = 0;
        gained = 1;
        _events.add(RunEvent(RunEventType.pass, points: 1, x: p.x, y: y));
      }
    }
    score += gained;
    _bumpBest();
  }

  void _bumpBest() {
    if (score > bestScore) bestScore = score;
  }

  void _die() {
    phase = RunPhase.dead;
    deathTimer = 0;
    dashTimer = 0;
    graceTimer = 0;
    floatTimer = 0;
    vy = 0;
    _events.add(RunEvent(RunEventType.hit, x: WingyWorld.heroX, y: y));
  }

  /// Pushes every pair that has not reached Wingy yet (and the spawn cursor) to the right so
  /// the next obstacle is at least [WingyWorld.dashExitBuffer] seconds of normal-speed travel away.
  void _applyDashExitGap(double dt) {
    final minLeft =
        WingyWorld.heroX +
        WingyWorld.heroRadius +
        scrollSpeed * (WingyWorld.dashExitBuffer + dt);
    final ahead = pairs.where((p) => !p.passed && p.left > WingyWorld.heroX);
    if (ahead.isEmpty) return;
    final first = ahead.reduce((a, b) => a.left < b.left ? a : b);
    final shift = minLeft - first.left;
    if (shift <= 0) return;
    for (final p in ahead) {
      p.x += shift;
    }
    _nextPairX += shift;
  }

  void _spawnPairs() {
    while (_nextPairX - WingyWorld.spireWidth / 2 <= WingyWorld.width + 60) {
      pairs.add(_generator.next(x: _nextPairX, score: score));
      _nextPairX += WingyWorld.pairSpacing;
    }
  }
}
