import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/dash_rules.dart';
import 'ui/wind_up_art.dart';
import 'wind_up_dash_ids.dart';
import 'wind_up_dash_progress.dart';

const String windUpDashId = 'wind_up_dash';
const String windUpDashTitle = 'Wind-up dash';

/// How to play, as shown by the How to play button (the catalogue and web text say the same).
const String windUpDashHowTo =
    'Space or tap to jump. Collect stars. Do not fall in gaps or hit bricks. '
    'P or Esc pauses.';

/// Wind-up dash: a toy wind-up car rolls by itself on a playroom floor; one key hops it over toy bricks and floor
/// gaps while it picks up paper stars (rewrite of Runner, G-12). Five courses with checkpoints and a flag, and the
/// free run (the old endless game: one life, best score). The free run feeds the Games tab (`onScore`); courses keep
/// their own stars. No title bar: the host shows the name. Spec: `docs/SPEC.md`.
class WindUpDashScreen extends StatefulWidget {
  const WindUpDashScreen({
    super.key,
    this.onScore,
    this.seedFor,
    this.prefs,
    this.onSound,
    this.gameBuilder,
  });

  /// Called once at the end of a free run with its score (courses do not call it).
  final void Function(int score)? onScore;

  /// The track seed of each free run; default a random one. Injected in tests.
  final int Function()? seedFor;
  final SharedPreferences? prefs;

  /// The sound hooks (`jump`, `land`, `star`, `spring_full`, `bounce`, `crash`, `checkpoint`, `finish`,
  /// `wind_click`, `ui_tap`). No sound files here; a container may play them.
  final void Function(String name)? onSound;

  /// Tests only: builds the round's game (a course or null for the free run, and the crashes so far).
  @visibleForTesting
  final DashGame Function(DashCourse? course, int crashes)? gameBuilder;

  @override
  State<WindUpDashScreen> createState() => _WindUpDashScreenState();
}

enum _View { menu, play, results }

enum _Beat { ready, run, crash, arrive }

class _WindUpDashScreenState extends State<WindUpDashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _readySeconds = 0.8;
  static const double _crashSeconds = 1.0;
  static const double _arriveSeconds = 1.0;

  late final Ticker _ticker = createTicker(_tick);
  final FixedStepper _stepper = FixedStepper(dt: dashStep);
  Duration _last = Duration.zero;
  double _time = 0;
  final FocusNode _focus = FocusNode(debugLabel: 'WindUpDash');

  DashProgress? _progress;
  _View _view = _View.menu;
  _Beat _beat = _Beat.ready;
  double _beatT = 0;
  bool _paused = false;
  bool _reduce = false;

  /// -1 is the free run, 0 to 4 the courses.
  int _course = -1;
  int _sel = 0;
  DashGame? _game;
  int _crashes = 0;
  final List<DashFx> _fx = [];
  final Random _fxRandom = Random(7);
  double _shakeT = 0;
  double _squash = 0;
  double _tumble = 0;
  double _coast = 0;
  double _pulse = 0;
  int _niceAt = 0;
  bool _hintUsed = false;
  double? _hintX;
  double? _hintEnd;
  String _banner = '';
  double _bannerT = 0;
  String _live = '';
  String _menuMessage = '';
  double _speedLineT = 0;

  // results
  double _resultT = 0;
  int _resSel = 0;
  int _rScore = 0;
  int _rStars = 0;
  int _rCoins = 0;
  int _rPicked = 0;
  int _rTotal = 0;
  bool _rFinished = false;
  bool _rNewBest = false;
  String _rNote = '';

  bool get _free => _course < 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _ticker.start();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    await DashProgress.migrate(p);
    if (!mounted) return;
    final prog = DashProgress(p);
    setState(() {
      _progress = prog;
      _sel = _playTarget(prog.stars);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotionOf(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _view == _View.play &&
        !_paused &&
        _beat != _Beat.arrive) {
      setState(() => _paused = true);
    }
  }

  void _sound(String n) => widget.onSound?.call(n);
  void _say(String t) => _live = t;

  List<int> get _stars => _progress?.stars ?? List.filled(dashCourseCount, 0);

  /// The course Play starts: the first open course with no star, else the last open one.
  int _playTarget(List<int> s) {
    for (var k = 0; k < dashCourseCount; k++) {
      if (dashCourseOpen(k, s) && s[k] == 0) return k;
    }
    return dashCourseCount - 1;
  }

  // ---- flow ----------------------------------------------------------------------------------

  void _startCourse(int i, {bool fresh = true}) {
    if (!dashCourseOpen(i, _stars)) {
      setState(() => _menuMessage = 'Finish course $i first');
      return;
    }
    _course = i;
    _sel = i;
    if (fresh) {
      _crashes = 0;
      _hintUsed = false;
    }
    _begin(_make(dashCourses[i]));
    _say('Course ${i + 1}, ${dashCourses[i].name}, start');
  }

  void _startFree() {
    _course = -1;
    _crashes = 0;
    _begin(_make(null));
    _say('Free run, start');
  }

  void _begin(DashGame g) {
    _game = g;
    _fx.clear();
    _shakeT = 0;
    _squash = 0;
    _tumble = 0;
    _coast = 0;
    _niceAt = (g.best / 250).floor();
    _banner = '';
    _hintX = null;
    _hintEnd = null;
    _beat = _Beat.ready;
    _beatT = _readySeconds;
    _clicks = 0;
    _paused = false;
    _menuMessage = '';
    _view = _View.play;
    _stepper.reset();
    _sound('wind_click');
  }

  int _clicks = 0;

  void _toMenu() => setState(() {
    _view = _View.menu;
    _paused = false;
    _game = null;
    _menuMessage = '';
    _sel = _playTarget(_stars);
  });

  void _leave() => Navigator.of(context).maybePop();

  void _pause() {
    if (_view != _View.play || _beat == _Beat.arrive) return;
    setState(() => _paused = !_paused);
  }

  Future<void> _showHowTo() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: DashIds.howToDialog,
        title: const Text('How to play'),
        content: const Text(windUpDashHowTo),
        actions: [
          FilledButton(
            key: DashIds.howToClose,
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it  ${_key(GameAction.action)} / Esc'),
          ),
        ],
      ),
    );
    if (mounted) _focus.requestFocus();
  }

  // ---- the tick ------------------------------------------------------------------------------

  void _tick(Duration t) {
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = t;
    _time += dt;
    _updateFx(dt);
    if (_bannerT > 0) _bannerT -= dt;
    if (_shakeT > 0) _shakeT -= dt;
    _squash *= pow(0.0001, dt).toDouble();
    _pulse = (sin(_time * 6) + 1) / 2;
    if (_view == _View.play && !_paused) _stepPlay(dt);
    if (_view == _View.results) _resultT += dt;
    if (mounted) setState(() {});
  }

  void _stepPlay(double dt) {
    final g = _game;
    if (g == null) return;
    switch (_beat) {
      case _Beat.ready:
        final before = _beatT;
        _beatT -= dt;
        final c = ((1 - _beatT / _readySeconds) * 3).floor().clamp(0, 3);
        while (_clicks < c) {
          _clicks++;
          _sound('wind_click');
        }
        if (before > 0 && _beatT <= 0) _beat = _Beat.run;
      case _Beat.crash:
        _beatT -= dt;
        _tumble = _reduce ? 0 : (1 - _beatT / _crashSeconds).clamp(0.0, 1.0);
        if (_beatT <= 0) _afterCrash();
      case _Beat.arrive:
        _beatT -= dt;
        _coast =
            6 *
            (1 -
                pow(
                  1 - (1 - _beatT / _arriveSeconds).clamp(0.0, 1.0),
                  2,
                ).toDouble());
        if (_beatT <= 0) _finishCourse();
      case _Beat.run:
        var n = _stepper.advance(dt);
        while (n-- > 0 && !g.over) {
          g.step();
          _handle(g, g.drainEvents());
        }
        _afterRun(g, dt);
    }
  }

  void _afterRun(DashGame g, double dt) {
    if (g.x / 250 >= _niceAt + 1) {
      _niceAt = (g.best / 250).floor();
      if (g.best > 0 && !g.over) _showBanner('Nice!');
    }
    final he = _hintEnd;
    if (he != null && g.x > he) {
      _hintX = null;
      _hintEnd = null;
    }
    final speed = dashSpeed(g.x, start: g.course?.startSpeed ?? 32);
    if (speed > 50 && !_reduce && !g.over) {
      _speedLineT -= dt;
      if (_speedLineT <= 0) {
        _speedLineT = 0.07;
        _fx.add(
          DashFx(
            DashFxKind.speedLine,
            g.x + 20 + _fxRandom.nextDouble() * 10,
            4 + _fxRandom.nextDouble() * 14,
            -speed,
            0,
            0.25,
            Colors.white,
          ),
        );
      }
    }
    if (g.finished) {
      _beat = _Beat.arrive;
      _beatT = _arriveSeconds;
      _confetti(g);
      _say('Flag reached');
    } else if (g.over) {
      _crashed(g);
    }
  }

  void _handle(DashGame g, List<DashEvent> events) {
    for (final e in events) {
      switch (e) {
        case DashEvent.jump:
          _sound('jump');
          _squash = 1;
        case DashEvent.land:
          _sound('land');
          _squash = -1;
          if (!_reduce) _dust(g);
        case DashEvent.star:
          _sound('star');
          _spark(g.x + 2, g.y + 2, dashGold);
          _say('Star ${g.starCount}');
        case DashEvent.springFull:
          _sound('spring_full');
          _showBanner('Bounce ready');
          _say('Spring ready, one bounce stored');
        case DashEvent.bounce:
          _sound('bounce');
          _shakeT = 0.15;
          _ring(g.x, g.y + 2);
          _showBanner('Boing!');
          _say('Bounced off a brick');
        case DashEvent.crash:
          _sound('crash');
        case DashEvent.checkpoint:
          _sound('checkpoint');
          _showBanner('Checkpoint ${g.checkpoint}');
          _say('Checkpoint ${g.checkpoint} reached');
        case DashEvent.finish:
          _sound('finish');
        case DashEvent.closeCall:
          _showBanner('Close!');
      }
    }
  }

  void _crashed(DashGame g) {
    _shakeT = 0.25;
    _beat = _Beat.crash;
    _beatT = _crashSeconds;
    _tumble = 0;
    final fell = g.end == DashEnd.fell;
    _crashes = g.crashes;
    _parts(g);
    _say(
      g.isCourse
          ? 'Crashed${fell ? ' in a gap' : ''}. Back at ${g.checkpoint == 0 ? 'the start' : 'checkpoint ${g.checkpoint}'}'
          : 'Crashed${fell ? ' in a gap' : ''}. Round over',
    );
  }

  void _afterCrash() {
    final g = _game!;
    if (!g.isCourse) {
      _finishFree();
      return;
    }
    g.restartAtCheckpoint();
    _fx.removeWhere((f) => f.kind == DashFxKind.part);
    _tumble = 0;
    _stepper.reset();
    if (g.crashesHere >= 3 && !_hintUsed) {
      final x = g.hintJumpAt;
      final h = g.track.nextFrom(g.x - dashWidth);
      if (x != null && h != null) {
        _hintUsed = true;
        _hintX = x;
        _hintEnd = h.end;
        _say('Hint: jump at the dotted line');
      }
    }
    _beat = _Beat.ready;
    _beatT = _readySeconds;
    _clicks = 0;
    _sound('wind_click');
  }

  void _skipBeat() {
    if (_beat == _Beat.crash) {
      _afterCrash();
    } else if (_beat == _Beat.ready) {
      _beat = _Beat.run;
    }
  }

  DashGame _make(DashCourse? c) =>
      widget.gameBuilder?.call(c, _crashes) ??
      DashGame(
        seed: c?.seed ?? widget.seedFor?.call() ?? Random().nextInt(1 << 30),
        course: c,
      );

  // ---- results -------------------------------------------------------------------------------

  void _finishCourse() {
    final g = _game!;
    final i = _course;
    final prog = _progress;
    final prevBest = prog?.courseBest[i] ?? 0;
    final prevStars = prog?.stars[i] ?? 0;
    final score = g.score;
    final stars = g.courseStars;
    final coins = max(0, dashCoins(score) - dashCoins(prevBest));
    if (coins > 0) GameHostScope.of(context).addCoins(context, coins);
    prog?.recordCourse(i, stars, score);
    _rScore = score;
    _rStars = stars;
    _rCoins = coins;
    _rPicked = g.starCount;
    _rTotal = g.totalStars;
    _rFinished = true;
    _rNewBest = score > prevBest;
    _rNote = (prevStars == 0 && stars >= 1 && i < dashCourseCount - 1)
        ? 'Course ${i + 2} is open'
        : '';
    _resSel = i < dashCourseCount - 1 ? 0 : 1;
    _resultT = 0;
    _view = _View.results;
    _say('Finished. $stars stars. ${_pct(_rPicked, _rTotal)} percent of stars');
  }

  int _pct(int a, int b) => b == 0 ? 100 : (100 * a / b).round();

  void _finishFree() {
    final g = _game!;
    final prog = _progress;
    final score = g.score;
    final coins = dashCoins(score);
    if (coins > 0) GameHostScope.of(context).addCoins(context, coins);
    final best = prog?.best ?? 0;
    _rNewBest = score > 0 && score > best;
    if (score > best) prog?.setBest(score);
    RunReportScope.finished(context, score, const RunExtras());
    widget.onScore?.call(score);
    _rScore = score;
    _rStars = arcadeStars(score, dashStarScores);
    _rCoins = coins;
    _rPicked = g.starCount;
    _rTotal = 0;
    _rFinished = false;
    _rNote = '';
    _resSel = 0;
    _resultT = 0;
    _view = _View.results;
    _say('Round over. Score $score');
  }

  void _resultsAction() {
    if (_free) {
      _startFree();
      return;
    }
    final last = _course >= dashCourseCount - 1;
    if (_resSel == 0 && !last) {
      _startCourse(_course + 1);
    } else {
      _startCourse(_course);
    }
  }

  // ---- effects -------------------------------------------------------------------------------

  void _updateFx(double dt) {
    for (final f in _fx) {
      f.life -= dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.rot += f.vr * dt;
      if (f.kind == DashFxKind.confetti) f.vy -= 14 * dt;
      if (f.kind == DashFxKind.part) {
        f.vy -= 60 * dt;
        if (f.y < 0) {
          f.y = 0;
          f.vy = -f.vy * 0.45;
        }
      }
    }
    _fx.removeWhere((f) => f.life <= 0);
  }

  void _dust(DashGame g) {
    for (var i = -1; i <= 1; i += 2) {
      _fx.add(
        DashFx(
          DashFxKind.dust,
          g.x + i * 1.2,
          0.4,
          i * 6.0 - 4,
          2,
          0.35,
          Colors.white,
          size: 0.7,
        ),
      );
    }
  }

  void _spark(double x, double y, Color c) {
    _fx.add(DashFx(DashFxKind.spark, x, y, 0, 0, 0.4, c, size: 0.6));
  }

  void _ring(double x, double y) {
    _fx.add(DashFx(DashFxKind.ring, x, y, 0, 0, 0.4, dashGold, size: 0.8));
  }

  void _parts(DashGame g) {
    for (var k = 0; k < 4; k++) {
      _fx.add(
        DashFx(
          DashFxKind.part,
          g.x,
          g.y + 1.5,
          -10 + _fxRandom.nextDouble() * 28,
          14 + _fxRandom.nextDouble() * 14,
          1.6,
          dashRed,
          part: k,
          vr: (_fxRandom.nextDouble() - 0.5) * 14,
        ),
      );
    }
  }

  void _confetti(DashGame g) {
    if (_reduce) return;
    const cols = [
      dashRed,
      Color(0xFF3B82F6),
      Color(0xFF2FB36B),
      Color(0xFF8B5CF6),
      dashGold,
    ];
    for (var i = 0; i < 50; i++) {
      _fx.add(
        DashFx(
          DashFxKind.confetti,
          g.x + 4 + (_fxRandom.nextDouble() - 0.5) * 8,
          10 + _fxRandom.nextDouble() * 6,
          (_fxRandom.nextDouble() - 0.5) * 18,
          4 + _fxRandom.nextDouble() * 10,
          1.8,
          cols[i % cols.length],
          vr: (_fxRandom.nextDouble() - 0.5) * 10,
        ),
      );
    }
  }

  void _showBanner(String t) {
    _banner = t;
    _bannerT = 1.0;
  }

  // ---- keys ----------------------------------------------------------------------------------

  String _key(GameAction a) => keyLabel(
    GameKeysScope.read(context).primaryOf(KeySlot(a, a.shared ? 0 : 1)),
  );

  /// The label of the jump key as the child sees it: the shared pause slot's key (Space by default).
  String get _spaceKey => keyLabel(
    GameKeysScope.read(context).primaryOf(const KeySlot(GameAction.pause, 0)),
  );

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final repeat = event is KeyRepeatEvent;
    final k = event.logicalKey;
    // The screen's own letters come first (F is also the left hand's action key in the shared map).
    if (!repeat) {
      if (_view == _View.menu) {
        if (k == LogicalKeyboardKey.keyF) {
          _startFree();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.keyH) {
          _showHowTo();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.digit5 || k == LogicalKeyboardKey.numpad5) {
          _startCourse(4);
          return KeyEventResult.handled;
        }
      } else if (_view == _View.results) {
        if (k == LogicalKeyboardKey.keyR) {
          _free ? _startFree() : _startCourse(_course);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.keyF && !_free) {
          _startFree();
          return KeyEventResult.handled;
        }
      } else if (_view == _View.play) {
        if (k == LogicalKeyboardKey.keyP) {
          _pause();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.keyL) {
          if (_paused || true) _toMenu();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.keyF) return KeyEventResult.handled;
      }
    }
    final input = GameKeysScope.read(context).resolve(k, repeat: repeat);
    if (input == null) return KeyEventResult.ignored;
    _onInput(input);
    return KeyEventResult.handled;
  }

  void _onInput(GameInput i) {
    final a = i.action;
    switch (_view) {
      case _View.menu:
        if (i.repeat) return;
        if (a == GameAction.action || a == GameAction.pause) {
          _startCourse(_sel);
        } else if (a == GameAction.exit) {
          _leave();
        } else if (a.pickNumber != null) {
          _startCourse(a.pickNumber! - 1);
        } else if (a == GameAction.left || a == GameAction.right) {
          final d = a == GameAction.left ? -1 : 1;
          var n = _sel;
          for (var k = 0; k < dashCourseCount; k++) {
            n = (n + d + dashCourseCount) % dashCourseCount;
            if (dashCourseOpen(n, _stars)) break;
          }
          setState(() => _sel = n);
        }
      case _View.results:
        if (i.repeat) return;
        if (a == GameAction.action || a == GameAction.pause) {
          _resultsAction();
        } else if (a == GameAction.exit) {
          _toMenu();
        } else if ((a == GameAction.left || a == GameAction.right) && !_free) {
          final last = _course >= dashCourseCount - 1;
          if (!last) setState(() => _resSel = a == GameAction.left ? 0 : 1);
        }
      case _View.play:
        if (_paused) {
          if (i.repeat) return;
          if (a == GameAction.pause ||
              a == GameAction.exit ||
              a == GameAction.action) {
            setState(() => _paused = false);
          }
          return;
        }
        switch (a) {
          case GameAction.pause || GameAction.action || GameAction.up:
            // Space, Enter, the up arrow and W jump (Space never pauses here)
            if (!i.repeat) _jump();
          case GameAction.exit:
            if (!i.repeat) _pause();
          case GameAction.question:
            if (!i.repeat) _readHazard();
          default:
        }
    }
  }

  void _jump() {
    final g = _game;
    if (g == null || _view != _View.play || _paused) return;
    if (_beat == _Beat.ready || _beat == _Beat.crash) {
      _skipBeat();
      return;
    }
    if (_beat != _Beat.run) return;
    g.jump();
  }

  void _readHazard() {
    final g = _game;
    final h = g?.track.nextFrom(g.x);
    if (g == null || h == null) return;
    final d = max(0, (h.x - g.x - dashWidth / 2).round());
    setState(
      () =>
          _say('${h.kind == HazardKind.gap ? 'Gap' : 'Brick'} ahead, $d units'),
    );
  }

  // ---- build ---------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final b = DashBackdrop.of(
      _view == _View.menu ? 1 : (_course < 0 ? 1 : _course + 1),
    );
    return Material(
      key: DashIds.screen,
      color: b.skyTop,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) {
          if (mounted && ModalRoute.of(context)?.isCurrent != false) {
            _focus.requestFocus();
          }
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) => switch (_view) {
                    _View.menu => _menu(context, box, b),
                    _ => _playView(context, box, b),
                  },
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Semantics(
                  key: DashIds.live,
                  liveRegion: true,
                  label: _live,
                  child: const SizedBox(width: 1, height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- shared bits ----

  static const Color _ink = dashInk;

  BoxDecoration _chipBox({Color? color}) => BoxDecoration(
    color: color ?? Colors.white.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _ink, width: 2),
  );

  Widget _btn({
    required Key key,
    required String label,
    required String keyText,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          TextSpan(
            text: '  $keyText',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: (primary ? Colors.white : _ink).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(64, primary ? 56 : 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _ink, width: 2),
        ),
      ),
    );
    final child = Semantics(
      label: '$label, key $keyText',
      excludeSemantics: true,
      button: true,
      child: text,
    );
    return FilledButton(
      key: key,
      onPressed: () {
        _sound('ui_tap');
        onPressed();
      },
      style: style.merge(
        ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            primary ? dashRed : Colors.white,
          ),
          foregroundColor: WidgetStatePropertyAll(
            primary ? Colors.white : _ink,
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
              fontSize: primary ? 18 : 15,
            ),
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _iconKeyButton({
    required Key key,
    required IconData icon,
    required String keyText,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      label: '$tooltip, key $keyText',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _ink, width: 2),
        ),
        child: InkWell(
          key: key,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          canRequestFocus: false,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: _ink),
                  const SizedBox(width: 2),
                  Text(
                    keyText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _starRow(int n, {double size = 18, int of = 3}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < of; i++)
        Icon(
          i < n ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < n ? const Color(0xFFE08A00) : _ink.withValues(alpha: 0.4),
        ),
    ],
  );

  // ---- menu ----------------------------------------------------------------------------------

  Widget _menu(BuildContext context, BoxConstraints box, DashBackdrop b) {
    final short = box.maxHeight < 460;
    final s = _stars;
    final best = _progress?.best ?? 0;
    final car = SizedBox(
      height: short ? 96 : 140,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: DashMenuPainter(_time),
          size: Size.infinite,
        ),
      ),
    );
    final playBtn = _btn(
      key: DashIds.play,
      label: 'Play',
      keyText: '${_key(GameAction.action)} / $_spaceKey',
      primary: true,
      onPressed: () => _startCourse(_sel),
    );
    final freeBtn = _btn(
      key: DashIds.free,
      label: 'Free run',
      keyText: 'F',
      onPressed: _startFree,
    );
    final howBtn = _btn(
      key: DashIds.howTo,
      label: 'How to play',
      keyText: 'H',
      onPressed: _showHowTo,
    );
    final bestText = Semantics(
      label:
          'Free run best $best, ${arcadeStars(best, dashStarScores)} of 3 stars',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: _chipBox(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Best $best',
                  key: DashIds.best,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                _starRow(arcadeStars(best, dashStarScores)),
              ],
            ),
          ),
        ),
      ),
    );
    final chips = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [for (var i = 0; i < dashCourseCount; i++) _courseChip(i, s)],
    );
    final message = SizedBox(
      height: 20,
      child: Text(
        _menuMessage,
        key: DashIds.menuMessage,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
    final exit = Padding(
      padding: const EdgeInsets.all(8),
      child: _iconKeyButton(
        key: DashIds.exit,
        icon: Icons.close,
        keyText: 'Esc',
        tooltip: 'Leave',
        onPressed: _leave,
      ),
    );
    final hint = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Space or tap: jump.  Left / Right and 1 to 5 pick a course.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _ink.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
    final Widget body;
    if (short) {
      body = Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [car, const SizedBox(height: 6), playBtn],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                chips,
                message,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [freeBtn, howBtn, bestText],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          car,
          const SizedBox(height: 8),
          playBtn,
          const SizedBox(height: 12),
          chips,
          message,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [freeBtn, howBtn],
          ),
          const SizedBox(height: 10),
          bestText,
          hint,
        ],
      );
    }
    return Stack(
      key: DashIds.menu,
      children: [
        Positioned.fill(child: CustomPaint(painter: DashSkyPainter(b, _time))),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: short ? 8 : 56,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: short ? 800 : 560),
                  child: body,
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 0, top: 0, child: SafeArea(child: exit)),
      ],
    );
  }

  Widget _courseChip(int i, List<int> stars) {
    final open = dashCourseOpen(i, stars);
    final c = dashCourses[i];
    final n = stars[i];
    final selected = open && _sel == i;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: open
          ? 'Course ${i + 1}, ${c.name}, $n of 3 stars, key ${i + 1}'
          : 'Course ${i + 1}, ${c.name}, locked. Finish course $i first',
      child: Material(
        color: open
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? dashRed
                : (open ? _ink : _ink.withValues(alpha: 0.4)),
            width: selected ? 3 : 2,
          ),
        ),
        child: InkWell(
          key: DashIds.course(i),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: () => _startCourse(i),
          child: SizedBox(
            width: 108,
            height: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            c.name,
                            maxLines: 1,
                            style: TextStyle(
                              color: _ink.withValues(alpha: open ? 1 : 0.55),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  open
                      ? KeyedSubtree(
                          key: DashIds.courseStars(i),
                          child: _starRow(n, size: 20),
                        )
                      : Icon(
                          Icons.lock,
                          size: 20,
                          color: _ink.withValues(alpha: 0.55),
                          key: DashIds.courseStars(i),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- play ----------------------------------------------------------------------------------

  Widget _playView(BuildContext context, BoxConstraints box, DashBackdrop b) {
    final g = _game;
    if (g == null) return const SizedBox();
    final w = box.maxWidth, h = box.maxHeight;
    final compact = h < 460 || w < 420;
    final hints = w >= 600 && h >= 520;
    Offset shake = Offset.zero;
    if (_shakeT > 0 && !_reduce) {
      final k = sin(_time * 90) * 4;
      shake = Offset(k, k * 0.4);
    }
    final scene = DashScene(
      game: g,
      time: _time,
      backdrop: b,
      fx: _fx,
      shake: shake,
      squash: _reduce ? 0 : _squash,
      tumble: _beat == _Beat.crash ? _tumble : 0,
      carHidden: _beat == _Beat.crash && !_reduce && _tumble > 0.05,
      reduce: _reduce,
      coast: _beat == _Beat.arrive || _view == _View.results
          ? (_beat == _Beat.arrive ? _coast : 6)
          : 0,
      hintX: _hintX,
      windUp: _beat == _Beat.ready
          ? (1 - _beatT / _readySeconds).clamp(0.0, 1.0)
          : -1,
      glowPulse: _pulse,
    );
    final field = GestureDetector(
      key: DashIds.field,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _jump(),
      child: Semantics(
        label: _fieldLabel(g),
        child: CustomPaint(
          painter: DashWorldPainter(scene),
          size: Size.infinite,
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: field),
        Positioned.fill(
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  top: 8,
                  child: _iconKeyButton(
                    key: DashIds.exit,
                    icon: Icons.close,
                    keyText: 'L',
                    tooltip: 'Leave',
                    onPressed: _toMenu,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _iconKeyButton(
                    key: DashIds.pause,
                    icon: _paused ? Icons.play_arrow : Icons.pause,
                    keyText: 'P',
                    tooltip: _paused ? 'Resume' : 'Pause',
                    onPressed: _pause,
                  ),
                ),
                Positioned(
                  left: 68,
                  right: 68,
                  top: 8,
                  child: Center(child: _hud(g, compact)),
                ),
                Positioned(right: 12, bottom: 12, child: _jumpButton()),
                if (hints) Positioned(left: 12, bottom: 12, child: _hints()),
                ..._overlays(g),
              ],
            ),
          ),
        ),
        if (_view == _View.results)
          Positioned.fill(child: _resultsCard(context)),
        if (_paused) Positioned.fill(child: _pauseOverlay()),
      ],
    );
  }

  String _fieldLabel(DashGame g) {
    final where = g.isCourse
        ? 'Course ${g.course!.number}, ${g.course!.name}'
        : 'Free run';
    final state = switch (_beat) {
      _Beat.ready => 'winding up',
      _Beat.crash => 'crashed',
      _Beat.arrive => 'at the flag',
      _Beat.run => 'running',
    };
    return 'Toy car, $state, $where, ${g.starCount} stars, score ${g.score}, jump with Space';
  }

  Widget _hints() {
    Widget hint(List<String> caps, String word) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in caps) ...[KeyCap(label: c), const SizedBox(width: 4)],
        Text(
          word,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return Container(
      key: DashIds.keys,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: _chipBox(color: Colors.white.withValues(alpha: 0.88)),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          hint([_spaceKey, 'or tap'], 'jump'),
          hint(['P', 'Esc'], 'pause'),
          hint(['L'], 'menu'),
        ],
      ),
    );
  }

  Widget _jumpButton() {
    return Semantics(
      label: 'Jump, key $_spaceKey',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: dashRed,
        shape: const CircleBorder(side: BorderSide(color: _ink, width: 3)),
        child: InkWell(
          key: DashIds.jump,
          customBorder: const CircleBorder(),
          canRequestFocus: false,
          onTapDown: (_) => _jump(),
          child: SizedBox(
            width: 76,
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const Text(
                  'Jump',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _spaceKey,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud(DashGame g, bool compact) {
    Widget chip(Widget child, {Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: _chipBox(),
      child: child,
    );
    const ts = TextStyle(
      color: _ink,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    final items = <Widget>[
      chip(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: StarIconPainter()),
            ),
            const SizedBox(width: 4),
            Text('${g.starCount}', style: ts),
          ],
        ),
        key: DashIds.starsCount,
      ),
      chip(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 74,
              height: 18,
              child: CustomPaint(
                painter: SpringIconPainter(
                  g.meter.bulbs,
                  g.meter.full,
                  pulse: _pulse,
                ),
              ),
            ),
            if (g.meter.full && !compact) ...[
              const SizedBox(width: 6),
              const Text(
                'Bounce ready',
                style: TextStyle(
                  color: dashGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        key: DashIds.spring,
      ),
      chip(
        Text(compact ? '${g.score}' : 'Score ${g.score}', style: ts),
        key: DashIds.score,
      ),
    ];
    final len = g.length;
    final pct = len == null ? 0.0 : (g.x / len).clamp(0.0, 1.0);
    final bar = len == null
        ? null
        : SizedBox(
            key: DashIds.progress,
            width: 220,
            height: 14,
            child: CustomPaint(
              painter: _ProgressPainter(
                pct,
                g.course!.flags.map((f) => f / len).toList(),
                g.checkpoint,
              ),
            ),
          );
    final label = g.isCourse
        ? 'Stars ${g.starCount}, spring ${g.meter.full ? 'full, bounce ready' : '${g.meter.stars} of 10'}, score ${g.score}, ${(pct * 100).round()} percent of the course'
        : 'Stars ${g.starCount}, spring ${g.meter.full ? 'full, bounce ready' : '${g.meter.stars} of 10'}, score ${g.score}';
    return Semantics(
      key: DashIds.hud,
      label: label,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: items,
              ),
              if (bar != null) ...[const SizedBox(height: 6), bar],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _overlays(DashGame g) {
    Widget big(Key key, String text, {Color color = Colors.white}) =>
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                key: key,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _ink, width: 2),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
        );
    final readyWord = _beatT > _readySeconds * 0.45 ? 'Ready' : 'Go!';
    return [
      if (_beat == _Beat.ready && !_paused) big(DashIds.ready, readyWord),
      if (_beat == _Beat.crash && g.isCourse)
        big(
          DashIds.tryAgain,
          'Try again  ${_key(GameAction.action)}',
          color: const Color(0xFFFFD6D6),
        ),
      if (_hintX != null && _beat == _Beat.run)
        Positioned(
          left: 0,
          right: 0,
          bottom: 100,
          child: IgnorePointer(
            child: Center(
              child: Container(
                key: DashIds.hint,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: _chipBox(color: dashGold),
                child: const Text(
                  'Jump at the dotted line',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      if (_bannerT > 0 && _beat == _Beat.run)
        Positioned(
          left: 0,
          right: 0,
          top: 96,
          child: IgnorePointer(
            child: Center(
              child: Container(
                key: DashIds.banner,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: dashGold,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _ink, width: 2),
                ),
                child: Text(
                  _banner,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _pauseOverlay() {
    return ColoredBox(
      key: DashIds.paused,
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _btn(
              key: DashIds.resume,
              label: 'Resume',
              keyText: 'P / Esc / ${_key(GameAction.action)}',
              primary: true,
              onPressed: () => setState(() => _paused = false),
            ),
            const SizedBox(height: 10),
            _btn(
              key: DashIds.leave,
              label: 'Leave',
              keyText: 'L',
              onPressed: _toMenu,
            ),
          ],
        ),
      ),
    );
  }

  // ---- results -------------------------------------------------------------------------------

  Widget _resultsCard(BuildContext context) {
    final shown = min(_rStars, (_resultT / 0.35).floor());
    final last = !_free && _course >= dashCourseCount - 1;
    final title = _rFinished
        ? 'Flag reached!'
        : (_rNewBest ? 'New best!' : 'Crashed');
    final buttons = <Widget>[
      if (_free)
        _btn(
          key: DashIds.again,
          label: 'Play again',
          keyText: '${_key(GameAction.action)} / $_spaceKey',
          primary: true,
          onPressed: _startFree,
        )
      else ...[
        if (!last)
          _selectable(
            _resSel == 0,
            _btn(
              key: DashIds.next,
              label: 'Next course',
              keyText: '${_key(GameAction.action)} / $_spaceKey',
              primary: _resSel == 0,
              onPressed: () => _startCourse(_course + 1),
            ),
          ),
        _selectable(
          _resSel == 1 || last,
          _btn(
            key: DashIds.replay,
            label: 'Replay',
            keyText: 'R',
            primary: _resSel == 1 || last,
            onPressed: () => _startCourse(_course),
          ),
        ),
      ],
      _btn(
        key: DashIds.done,
        label: 'Menu',
        keyText: 'Esc',
        onPressed: _toMenu,
      ),
    ];
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            key: DashIds.results,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _ink, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  container: true,
                  label: '$_rStars of 3 stars',
                  child: ExcludeSemantics(
                    child: KeyedSubtree(
                      key: DashIds.resultStars,
                      child: _starRow(shown, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Score $_rScore',
                  key: DashIds.resultScore,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                if (_rFinished)
                  Text(
                    '${_pct(_rPicked, _rTotal)} percent of the stars',
                    style: const TextStyle(color: _ink, fontSize: 15),
                  )
                else
                  Text(
                    '$_rPicked stars picked up',
                    style: const TextStyle(color: _ink, fontSize: 15),
                  ),
                Text(
                  '$_rCoins coins',
                  key: DashIds.resultCoins,
                  style: const TextStyle(color: _ink, fontSize: 15),
                ),
                if (_rNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _rNote,
                      style: const TextStyle(
                        color: dashGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: buttons,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectable(bool selected, Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? dashGold : Colors.transparent,
        width: 3,
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(2), child: child),
  );
}

/// The course progress bar with a tick for each checkpoint flag and a dot for the car.
class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.pct, this.flags, this.reached);
  final double pct;
  final List<double> flags;
  final int reached;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * pct, size.height),
      Paint()..color = dashGold,
    );
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dashInk,
    );
    for (var i = 0; i < flags.length; i++) {
      final x = size.width * flags[i];
      canvas.drawLine(
        Offset(x, 1),
        Offset(x, size.height - 1),
        Paint()
          ..color = i < reached ? dashGreen : dashInk
          ..strokeWidth = 2.5,
      );
    }
    canvas.drawCircle(
      Offset(size.width * pct, size.height / 2),
      5,
      Paint()..color = dashRed,
    );
    canvas.drawCircle(
      Offset(size.width * pct, size.height / 2),
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dashInk,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) => true;
}
