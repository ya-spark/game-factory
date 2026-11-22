import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parcel_train_ids.dart';
import 'parcel_train_progress.dart';
import 'rules/parcel_train_rules.dart';
import 'ui/parcel_train_art.dart';

const String parcelTrainId = 'parcel_train';
const String parcelTrainTitle = 'Parcel train';

/// How to play, as shown by the How to play button (the catalogue and web text say the same).
const String parcelTrainHowTo =
    'Steer with the arrow keys or swipe. Pick up parcels, then drive into the station. '
    'Do not hit walls or your own wagons. Space or P pauses.';

/// Parcel train: a toy train picks up parcels on a play mat (rewrite of Snake, G-15). Five courses with a station,
/// a golden parcel and three bumpers, and Free ride (the old endless game: one life, best score). Free ride feeds
/// the Games tab (`onScore`); courses keep their own stars. No title bar: the host shows the name. Spec:
/// `docs/SPEC.md`.
class ParcelTrainScreen extends StatefulWidget {
  const ParcelTrainScreen({
    super.key,
    this.onScore,
    this.random,
    this.prefs,
    this.onSound,
    this.gameBuilder,
  });

  /// Called once at the end of a Free ride round with its score (courses do not call it).
  final void Function(int score)? onScore;

  /// The random source of Free ride's parcels; default a fresh `Random`. Injected in tests.
  final Random? random;
  final SharedPreferences? prefs;

  /// The sound hooks (`chug`, `toot`, `parcel`, `couple`, `golden`, `bump`, `derail`, `gate_open`, `arrive`,
  /// `unload`, `finish`, `ui_tap`). No sound files here; a container may play them.
  final void Function(String name)? onSound;

  /// Tests only: builds the round's game (a course or null for Free ride, and the derails so far).
  @visibleForTesting
  final TrainGame Function(TrainCourse? course, int derails)? gameBuilder;

  @override
  State<ParcelTrainScreen> createState() => _ParcelTrainScreenState();
}

enum _View { menu, play, results }

enum _Beat { ready, run, derail }

class _ParcelTrainScreenState extends State<ParcelTrainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _readySeconds = 1.0;
  static const double _derailSeconds = 1.0;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _time = 0;
  final FocusNode _focus = FocusNode(debugLabel: 'ParcelTrain');

  TrainProgress? _progress;
  _View _view = _View.menu;
  _Beat _beat = _Beat.ready;
  double _beatT = 0;
  bool _paused = false;
  bool _reduce = false;
  bool _wrap = false;

  /// -1 is Free ride, 0 to 4 the courses.
  int _course = -1;
  int _lastCourse = 0;
  TrainGame? _game;
  int _derails = 0;
  final Map<TrainCell, int> _rails = {};
  final List<TrainFx> _fx = [];
  final Random _fxRandom = Random(5);
  int _steps = 0;
  double _shakeT = 0, _shakeAmp = 0;
  double _tumble = 0;
  double _coupleT = 1;
  (Offset, Offset, double)? _fly;
  String _banner = '';
  double _bannerT = 0;
  String _live = '';
  String _menuMessage = '';

  // results
  bool _arriving = false;
  double _arriveT = 0;
  int _unloaded = 0;
  double _resultT = 0;
  int _resSel = 0;
  int _rScore = 0;
  int _rStars = 0;
  int _rCoins = 0;
  bool _rArrived = false;
  bool _rNewBest = false;
  String _rNote = '';
  TrainCell? _parcelWas;

  bool get _free => _course < 0;
  TrainCourse? get _courseDef => _free ? null : trainCourses[_course];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _ticker.start();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    await TrainProgress.migrate(p);
    if (!mounted) return;
    final prog = TrainProgress(p);
    setState(() {
      _progress = prog;
      _wrap = prog.wrap;
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
        !_arriving) {
      setState(() => _paused = true);
    }
  }

  void _sound(String n) => widget.onSound?.call(n);
  void _say(String t) => _live = t;

  List<int> get _stars => _progress?.stars ?? List.filled(trainCourseCount, 0);

  // ---- flow ----------------------------------------------------------------------------------

  void _startCourse(int i, {bool fresh = true}) {
    if (!trainCourseOpen(i, _stars)) {
      setState(() => _menuMessage = 'Finish course $i first');
      return;
    }
    _course = i;
    _lastCourse = i;
    if (fresh) _derails = 0;
    _begin(_make(trainCourses[i]));
    _say('Course ${i + 1}, ${trainCourses[i].name}, start');
  }

  void _startFree() {
    _course = -1;
    _derails = 0;
    _begin(_make(null));
    _say('Free ride, start');
  }

  void _begin(TrainGame g) {
    _game = g;
    _rails.clear();
    for (final c in g.body) {
      _rails[c] = railBit(TrainDir.left) | railBit(TrainDir.right);
    }
    _fx.clear();
    _steps = 0;
    _shakeT = 0;
    _tumble = 0;
    _coupleT = 1;
    _fly = null;
    _banner = '';
    _arriving = false;
    _arriveT = 0;
    _unloaded = 0;
    _parcelWas = g.parcel;
    _beat = _Beat.ready;
    _beatT = _readySeconds;
    _paused = false;
    _menuMessage = '';
    _view = _View.play;
    _sound('toot');
  }

  void _toMenu() => setState(() {
    _view = _View.menu;
    _paused = false;
    _game = null;
    _menuMessage = '';
  });

  void _leave() => Navigator.of(context).maybePop();

  void _pause() {
    if (_view != _View.play || _arriving) return;
    setState(() => _paused = !_paused);
  }

  Future<void> _showHowTo() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: ParcelTrainIds.howToDialog,
        title: const Text('How to play'),
        content: const Text(parcelTrainHowTo),
        actions: [
          FilledButton(
            key: ParcelTrainIds.howToClose,
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it  ${_key(GameAction.action)}'),
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
    if (_coupleT < 1) _coupleT = min(1, _coupleT + dt / 0.35);
    final f = _fly;
    if (f != null) {
      final p = f.$3 + dt / 0.15;
      _fly = p >= 1 ? null : (f.$1, f.$2, p);
    }
    if (_shakeT > 0) _shakeT -= dt;
    if (_view == _View.play && !_paused) _stepPlay(dt);
    if (_view == _View.results) _resultT += dt;
    if (mounted) setState(() {});
  }

  void _stepPlay(double dt) {
    final g = _game;
    if (g == null) return;
    if (_arriving) {
      _arriveT += dt;
      final n = g.body.length - 1;
      final per = 0.22;
      final u = min(n, (_arriveT / per).floor());
      while (_unloaded < u) {
        _unloaded++;
        _sound('unload');
      }
      if (_arriveT >= n * per + 0.5) _finishCourse();
      return;
    }
    switch (_beat) {
      case _Beat.ready:
        _beatT -= dt;
        if (_beatT <= 0) _beat = _Beat.run;
      case _Beat.derail:
        _beatT -= dt;
        _tumble = _reduce ? 0 : (1 - _beatT / _derailSeconds).clamp(0.0, 1.0);
        if (_beatT <= 0) _restartAfterDerail();
      case _Beat.run:
        _parcelWas = g.parcel;
        final moves = g.update(dt);
        if (moves > 0) _recordRails(g);
        _handle(g, g.drainEvents());
        if (g.over && g.end != TrainEnd.derail && !_arriving) {
          if (g.end == TrainEnd.arrived) {
            _arriving = true;
            _arriveT = 0;
            _unloaded = 0;
            _confetti(g);
          } else {
            _finishFree();
          }
        }
    }
  }

  void _recordRails(TrainGame g) {
    final from = g.prevBody.first;
    final to = g.head;
    if (from == to) return;
    final dx = to.x - from.x, dy = to.y - from.y;
    final adj = dx.abs() + dy.abs() == 1;
    if (adj) {
      final d = TrainDir.values.firstWhere((d) => d.dx == dx && d.dy == dy);
      _rails[from] = (_rails[from] ?? 0) | railBit(d);
      _rails[to] = (_rails[to] ?? 0) | railBit(d.opposite);
    } else {
      _rails[to] = (_rails[to] ?? 0) | railBit(g.dir.opposite);
      _rails[from] = (_rails[from] ?? 0) | railBit(g.dir);
    }
  }

  void _handle(TrainGame g, List<TrainEvent> events) {
    for (final e in events) {
      switch (e) {
        case TrainEvent.step:
        case TrainEvent.tunnel:
          _steps++;
          if (_steps.isEven) _sound('chug');
          if (_steps % 4 == 0 && !_reduce) _puff(g);
          if (e == TrainEvent.tunnel) _say('Tunnel');
        case TrainEvent.parcel:
          _sound('parcel');
          _sound('couple');
          _coupleT = 0;
          final was = _parcelWas;
          if (was != null) {
            final tail = g.body.last;
            _fly = (
              Offset(was.x.toDouble(), was.y.toDouble()),
              Offset(tail.x.toDouble(), tail.y.toDouble()),
              0,
            );
            _spark(
              was.x + 0.5,
              was.y + 0.5,
              trainParcelColors[g.colors.last.clamp(0, 3)],
            );
          }
          _say(
            g.isCourse ? 'Parcel ${g.eaten} of ${g.goal}' : 'Parcel ${g.eaten}',
          );
          if (g.eaten % 5 == 0) _showBanner('Nice!');
        case TrainEvent.golden:
          _sound('golden');
          _spark(g.head.x + 0.5, g.head.y + 0.5, trainGold);
          _showBanner('Golden parcel!');
          _say('Golden parcel taken');
        case TrainEvent.gateOpen:
          _sound('gate_open');
          _sound('toot');
          _showBanner('Station open');
          _say('Station open');
        case TrainEvent.bump:
          _sound('bump');
          _shakeT = 0.12;
          _shakeAmp = 3;
          _steam(g);
          _say('Bumped, ${g.bumpers} bumpers left');
        case TrainEvent.derail:
          _sound('derail');
          _shakeT = 0.25;
          _shakeAmp = 4;
          _beat = _Beat.derail;
          _beatT = _derailSeconds;
          _derails++;
          _steam(g);
          _say('Derailed. Starting again');
        case TrainEvent.arrive:
          _sound('arrive');
          _say('Arrived');
      }
    }
  }

  void _restartAfterDerail() {
    final i = _course;
    if (i < 0) return;
    _begin(_make(trainCourses[i]));
  }

  TrainGame _make(TrainCourse? c) =>
      widget.gameBuilder?.call(c, _derails) ??
      (c == null
          ? TrainGame(wrap: _wrap, random: widget.random ?? Random())
          : TrainGame(
              course: c,
              derailsBefore: _derails,
              random: c.newRandom(),
            ));

  void _skipBeat() {
    if (_beat == _Beat.derail) {
      _restartAfterDerail();
    }
  }

  // ---- results -------------------------------------------------------------------------------

  void _finishCourse() {
    final g = _game!;
    final i = _course;
    final prog = _progress;
    final prevBest = prog?.courseBest[i] ?? 0;
    final prevStars = prog?.stars[i] ?? 0;
    final score = g.score;
    final stars = g.stars;
    final coins = max(0, trainCoins(score) - trainCoins(prevBest));
    if (coins > 0) GameHostScope.of(context).addCoins(context, coins);
    prog?.recordCourse(i, stars, score);
    _rScore = score;
    _rStars = stars;
    _rCoins = coins;
    _rArrived = true;
    _rNewBest = score > prevBest;
    _rNote = (prevStars == 0 && stars >= 1 && i < trainCourseCount - 1)
        ? 'Course ${i + 2} is open'
        : '';
    _resSel = i < trainCourseCount - 1 ? 0 : 1;
    _resultT = 0;
    _view = _View.results;
    _arriving = false;
    _sound('finish');
    _say('Arrived. $stars stars');
  }

  void _finishFree() {
    final g = _game!;
    final prog = _progress;
    final score = g.score;
    final coins = trainCoins(score);
    if (coins > 0) GameHostScope.of(context).addCoins(context, coins);
    final best = prog?.best ?? 0;
    _rNewBest = score > 0 && score > best;
    if (score > best) prog?.setBest(score);
    RunReportScope.finished(context, score, const RunExtras());
    widget.onScore?.call(score);
    _rScore = score;
    _rStars = arcadeStars(score, trainStarScores);
    _rCoins = coins;
    _rArrived = false;
    _rNote = '';
    _resSel = 0;
    _resultT = 0;
    _view = _View.results;
    _sound('finish');
    _say('Round over. Score $score');
  }

  void _resultsAction() {
    if (_free) {
      _startFree();
      return;
    }
    final last = _course >= trainCourseCount - 1;
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
      if (_reduce && f.kind != TrainFxKind.spark) continue;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      if (f.kind == TrainFxKind.confetti) f.vy += 3 * dt;
    }
    _fx.removeWhere((f) => f.life <= 0);
  }

  void _puff(TrainGame g) {
    final h = g.head;
    _fx.add(
      TrainFx(
        TrainFxKind.smoke,
        h.x + 0.5,
        h.y + 0.4,
        -g.dir.dx * 0.2,
        -0.5,
        0.8,
        Colors.white,
        0.12,
      ),
    );
  }

  void _steam(TrainGame g) {
    for (var i = 0; i < 4; i++) {
      _fx.add(
        TrainFx(
          TrainFxKind.steam,
          g.head.x + 0.5,
          g.head.y + 0.5,
          (_fxRandom.nextDouble() - 0.5) * 1.2,
          -0.8 - _fxRandom.nextDouble() * 0.5,
          0.6,
          Colors.white,
          0.14,
        ),
      );
    }
  }

  void _spark(double x, double y, Color c) {
    _fx.add(TrainFx(TrainFxKind.spark, x, y, 0, 0, 0.45, c, 0.35));
  }

  void _confetti(TrainGame g) {
    if (_reduce) return;
    final c = g.head;
    const cols = [
      Color(0xFFE5484D),
      Color(0xFF3B82F6),
      Color(0xFF2FB36B),
      Color(0xFF8B5CF6),
      trainGold,
    ];
    for (var i = 0; i < 40; i++) {
      _fx.add(
        TrainFx(
          TrainFxKind.confetti,
          c.x + 0.5,
          c.y + 0.5,
          (_fxRandom.nextDouble() - 0.5) * 6,
          -2 - _fxRandom.nextDouble() * 3,
          1.6,
          cols[i % cols.length],
          0.3,
        ),
      );
    }
  }

  void _showBanner(String t) {
    _banner = t;
    _bannerT = 1.2;
  }

  // ---- keys ----------------------------------------------------------------------------------

  String _key(GameAction a, {int player = 1}) => keyLabel(
    GameKeysScope.read(context).primaryOf(KeySlot(a, a.shared ? 0 : player)),
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
        if (k == LogicalKeyboardKey.keyT) {
          _setWrap(!_wrap);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.digit5 || k == LogicalKeyboardKey.numpad5) {
          _startCourse(4);
          return KeyEventResult.handled;
        }
      } else if (_view == _View.results) {
        if (k == LogicalKeyboardKey.keyR) {
          _startCourse(_course < 0 ? 0 : _course);
          if (_free) _startFree();
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
          _playButton();
        } else if (a == GameAction.exit) {
          _leave();
        } else if (a.pickNumber != null) {
          _startCourse(a.pickNumber! - 1);
        }
      case _View.results:
        if (i.repeat) return;
        if (a == GameAction.action || a == GameAction.pause) {
          _resultsAction();
        } else if (a == GameAction.exit) {
          _toMenu();
        } else if ((a == GameAction.left || a == GameAction.right) && !_free) {
          final last = _course >= trainCourseCount - 1;
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
          case GameAction.left:
            _turn(TrainDir.left);
          case GameAction.right:
            _turn(TrainDir.right);
          case GameAction.up:
            _turn(TrainDir.up);
          case GameAction.down:
            _turn(TrainDir.down);
          case GameAction.pause || GameAction.exit:
            if (!i.repeat) _pause();
          case GameAction.action:
            if (!i.repeat) _skipBeat();
          case GameAction.question:
            if (!i.repeat) _readParcel();
          default:
        }
    }
  }

  void _turn(TrainDir d) {
    final g = _game;
    if (g == null || _view != _View.play || _paused) return;
    g.turn(d);
  }

  void _readParcel() {
    final g = _game;
    final p = g?.parcel;
    if (g == null || p == null) return;
    final dx = p.x - g.head.x, dy = p.y - g.head.y;
    final parts = <String>[
      if (dx != 0)
        '${dx.abs()} cell${dx.abs() == 1 ? '' : 's'} ${dx > 0 ? 'right' : 'left'}',
      if (dy != 0)
        '${dy.abs()} cell${dy.abs() == 1 ? '' : 's'} ${dy > 0 ? 'down' : 'up'}',
    ];
    setState(() => _say('Parcel: ${parts.join(', ')}'));
  }

  void _setWrap(bool v) {
    setState(() => _wrap = v);
    _progress?.setWrap(v);
  }

  void _playButton() {
    final s = _stars;
    var i = 0;
    for (var k = 0; k < trainCourseCount; k++) {
      if (trainCourseOpen(k, s) && s[k] == 0) {
        i = k;
        break;
      }
      if (trainCourseOpen(k, s)) i = _lastCourse == k ? k : i;
    }
    if (s.every((v) => v >= 1)) i = _lastCourse;
    _startCourse(i);
  }

  // ---- build ---------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mat = TrainMat.of(
      _view == _View.menu ? 0 : (_courseDef?.number ?? 0),
    );
    return Material(
      key: ParcelTrainIds.screen,
      color: mat.base,
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
              Positioned.fill(child: CustomPaint(painter: MatPainter(mat))),
              Positioned.fill(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, box) => switch (_view) {
                      _View.menu => _menu(context, box),
                      _ => _playView(context, box),
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Semantics(
                  key: ParcelTrainIds.live,
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

  static const Color _ink = trainInk;

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
    return primary
        ? FilledButton(
            key: key,
            onPressed: onPressed,
            style: style.merge(
              ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll(
                  Color(0xFFE5484D),
                ),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
            child: child,
          )
        : FilledButton(
            key: key,
            onPressed: onPressed,
            style: style.merge(
              ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll(Colors.white),
                foregroundColor: const WidgetStatePropertyAll(_ink),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

  Widget _menu(BuildContext context, BoxConstraints box) {
    final short = box.maxHeight < 460;
    final s = _stars;
    final best = _progress?.best ?? 0;
    final engine = SizedBox(
      height: short ? 84 : 120,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: MenuTrainPainter(_time),
          size: Size.infinite,
        ),
      ),
    );
    final playBtn = _btn(
      key: ParcelTrainIds.play,
      label: 'Play',
      keyText: _key(GameAction.action),
      primary: true,
      onPressed: _playButton,
    );
    final freeBtn = _btn(
      key: ParcelTrainIds.free,
      label: 'Free ride',
      keyText: 'F',
      onPressed: _startFree,
    );
    final howBtn = _btn(
      key: ParcelTrainIds.howTo,
      label: 'How to play',
      keyText: 'H',
      onPressed: _showHowTo,
    );
    final bestText = Semantics(
      label:
          'Free ride best $best, ${arcadeStars(best, trainStarScores)} of 3 stars',
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
                  key: ParcelTrainIds.best,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                _starRow(arcadeStars(best, trainStarScores)),
              ],
            ),
          ),
        ),
      ),
    );
    final wrapRow = DecoratedBox(
      decoration: _chipBox(),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Tunnel edges  T',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(key: ParcelTrainIds.wrap, value: _wrap, onChanged: _setWrap),
          ],
        ),
      ),
    );
    final chips = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [for (var i = 0; i < trainCourseCount; i++) _courseChip(i, s)],
    );
    final message = SizedBox(
      height: 20,
      child: Text(
        _menuMessage,
        key: ParcelTrainIds.menuMessage,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
    final exit = Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: _iconKeyButton(
          key: ParcelTrainIds.exit,
          icon: Icons.close,
          keyText: _key(GameAction.exit),
          tooltip: 'Leave',
          onPressed: _leave,
        ),
      ),
    );
    Widget body;
    if (short) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                engine,
                const SizedBox(height: 8),
                playBtn,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [freeBtn, howBtn],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                chips,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [bestText, wrapRow],
                ),
                message,
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          engine,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [bestText, wrapRow],
          ),
        ],
      );
    }
    return Stack(
      key: ParcelTrainIds.menu,
      children: [
        Positioned.fill(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: short ? 760 : 560),
                child: body,
              ),
            ),
          ),
        ),
        Positioned(left: 0, top: 0, child: exit),
      ],
    );
  }

  Widget _courseChip(int i, List<int> stars) {
    final open = trainCourseOpen(i, stars);
    final c = trainCourses[i];
    final n = stars[i];
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
            color: open ? _ink : _ink.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: InkWell(
          key: ParcelTrainIds.course(i),
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
                          key: ParcelTrainIds.courseStars(i),
                          child: _starRow(n, size: 20),
                        )
                      : Icon(
                          Icons.lock,
                          size: 20,
                          color: _ink.withValues(alpha: 0.55),
                          key: ParcelTrainIds.courseStars(i),
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

  Widget _playView(BuildContext context, BoxConstraints box) {
    final g = _game;
    if (g == null) return const SizedBox();
    final w = box.maxWidth, h = box.maxHeight;
    final short = h < 460 && w >= 600;
    final phone = w < 600;
    const frame = 6.0;
    // the pieces around the field
    final padH = phone ? 72.0 : 0.0;
    final hudH = short ? 0.0 : 52.0;
    final hintsH = (!phone && !short) ? 44.0 : 0.0;
    final sideLeft = short ? 170.0 : 0.0;
    final sideRight = short ? 200.0 : 0.0;
    final areaW = w - sideLeft - sideRight - 16;
    final areaH = h - padH - hudH - hintsH - 8;
    var cs = min((areaW - frame * 2) / g.cols, (areaH - frame * 2) / g.rows);
    cs = cs.floorToDouble();
    final fw = cs * g.cols, fh = cs * g.rows;
    final field = _field(g, cs, fw, fh, frame);
    final hud = _hud(g, compact: short || phone, vertical: short);
    final pause = _paused ? _pauseOverlay() : null;
    Widget layout;
    if (short) {
      layout = Row(
        children: [
          SizedBox(
            width: sideLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _topButtons(vertical: true),
                  const SizedBox(height: 8),
                  hud,
                ],
              ),
            ),
          ),
          Expanded(child: Center(child: field)),
          SizedBox(
            width: sideRight,
            child: Center(child: _pad(cross: true)),
          ),
        ],
      );
    } else {
      layout = Column(
        children: [
          SizedBox(
            height: hudH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _topLeft(),
                  Expanded(child: Center(child: hud)),
                  _topRight(),
                ],
              ),
            ),
          ),
          Expanded(child: Center(child: field)),
          if (phone)
            SizedBox(
              height: padH,
              child: Center(child: _pad(cross: false)),
            ),
          if (hintsH > 0)
            SizedBox(
              height: hintsH,
              child: Center(child: _hints()),
            ),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: layout),
        if (_view == _View.results)
          Positioned.fill(child: _resultsCard(context)),
        if (pause != null) Positioned.fill(child: pause),
      ],
    );
  }

  Widget _topLeft() => _iconKeyButton(
    key: ParcelTrainIds.exit,
    icon: Icons.close,
    keyText: _key(GameAction.exit),
    tooltip: 'Leave',
    onPressed: _toMenu,
  );

  Widget _topRight() => _iconKeyButton(
    key: ParcelTrainIds.pause,
    icon: _paused ? Icons.play_arrow : Icons.pause,
    keyText: 'P',
    tooltip: _paused ? 'Resume' : 'Pause',
    onPressed: _pause,
  );

  Widget _topButtons({required bool vertical}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [_topLeft(), _topRight()],
  );

  /// The keys of play, shown on windows 600 dp wide and 460 tall or more (the pad takes their place on a phone).
  Widget _hints() {
    final map = GameKeysScope.of(context);
    String k(GameAction a, [int p = 1]) =>
        keyLabel(map.primaryOf(KeySlot(a, a.shared ? 0 : p)));
    final steer =
        '${k(GameAction.left)} ${k(GameAction.up)} ${k(GameAction.down)} ${k(GameAction.right)}';
    final wasd =
        '${k(GameAction.up, 2)} ${k(GameAction.left, 2)} ${k(GameAction.down, 2)} ${k(GameAction.right, 2)}';
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
      key: ParcelTrainIds.keys,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: _chipBox(color: Colors.white.withValues(alpha: 0.88)),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          hint([steer, wasd], 'steer'),
          hint([k(GameAction.pause), 'P'], 'pause'),
          hint([k(GameAction.exit)], 'menu'),
        ],
      ),
    );
  }

  Widget _hud(TrainGame g, {required bool compact, bool vertical = false}) {
    final items = <Widget>[];
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
    if (g.isCourse) {
      items.add(
        chip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.house_rounded, size: 18, color: _ink),
              const SizedBox(width: 4),
              Text('${g.eaten} / ${g.goal}', style: ts),
            ],
          ),
          key: ParcelTrainIds.parcels,
        ),
      );
      items.add(
        chip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < trainBumpers; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: BumperIconPainter(i < g.bumpers, _ink),
                    ),
                  ),
                ),
              Text('${g.bumpers}', style: ts),
            ],
          ),
          key: ParcelTrainIds.bumpers,
        ),
      );
      items.add(
        chip(
          SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(
              painter: ParcelIconPainter(5, grey: !g.goldenTaken),
            ),
          ),
          key: ParcelTrainIds.goldenIcon,
        ),
      );
      if (g.gateOpen) {
        items.add(
          chip(
            Text(
              compact ? 'Open' : 'Station open',
              style: ts.copyWith(color: const Color(0xFF1E7A48)),
            ),
            key: ParcelTrainIds.stationOpen,
          ),
        );
      }
    } else {
      items.add(
        chip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: ParcelIconPainter(0)),
              ),
              const SizedBox(width: 4),
              Text('${g.eaten}', style: ts),
            ],
          ),
          key: ParcelTrainIds.parcels,
        ),
      );
    }
    items.add(
      chip(
        Text(compact ? '${g.score}' : 'Score ${g.score}', style: ts),
        key: ParcelTrainIds.score,
      ),
    );
    final label = g.isCourse
        ? 'Parcels ${g.eaten} of ${g.goal}, ${g.bumpers} bumpers left, score ${g.score}'
        : 'Parcels ${g.eaten}, score ${g.score}';
    return Semantics(
      key: ParcelTrainIds.hud,
      label: label,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: items,
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: items,
                ),
        ),
      ),
    );
  }

  Widget _pad({required bool cross}) {
    final map = GameKeysScope.read(context);
    String wasd(GameAction a) => keyLabel(map.primaryOf(KeySlot(a, 2)));
    Widget b(String name, IconData icon, GameAction a, TrainDir d) => Semantics(
      label:
          'Turn $name, key ${keyLabel(map.primaryOf(KeySlot(a, 1)))} or ${wasd(a)}',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _ink, width: 2),
        ),
        child: InkWell(
          key: ParcelTrainIds.padKey(name),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: () {
            _sound('ui_tap');
            _turn(d);
          },
          child: SizedBox(
            width: 56,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: _ink),
                Text(
                  wasd(a),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final left = b('left', Icons.arrow_back, GameAction.left, TrainDir.left);
    final up = b('up', Icons.arrow_upward, GameAction.up, TrainDir.up);
    final down = b(
      'down',
      Icons.arrow_downward,
      GameAction.down,
      TrainDir.down,
    );
    final right = b(
      'right',
      Icons.arrow_forward,
      GameAction.right,
      TrainDir.right,
    );
    if (cross) {
      return Column(
        key: ParcelTrainIds.pad,
        mainAxisSize: MainAxisSize.min,
        children: [
          up,
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              left,
              const SizedBox(width: 6),
              down,
              const SizedBox(width: 6),
              right,
            ],
          ),
        ],
      );
    }
    return Row(
      key: ParcelTrainIds.pad,
      mainAxisSize: MainAxisSize.min,
      children: [
        left,
        const SizedBox(width: 8),
        up,
        const SizedBox(width: 8),
        down,
        const SizedBox(width: 8),
        right,
      ],
    );
  }

  double _dragX = 0, _dragY = 0;

  void _onPan(DragUpdateDetails d) {
    _dragX += d.delta.dx;
    _dragY += d.delta.dy;
    if (sqrt(_dragX * _dragX + _dragY * _dragY) < 24) return;
    if (_dragX.abs() > _dragY.abs()) {
      _turn(_dragX > 0 ? TrainDir.right : TrainDir.left);
    } else {
      _turn(_dragY > 0 ? TrainDir.down : TrainDir.up);
    }
    _dragX = 0;
    _dragY = 0;
  }

  Widget _field(TrainGame g, double cs, double fw, double fh, double frame) {
    Offset shake = Offset.zero;
    if (_shakeT > 0 && !_reduce) {
      final k = sin(_time * 90) * _shakeAmp;
      shake = Offset(k, k * 0.4);
    }
    final scene = TrainScene(
      game: g,
      prev: g.prevBody,
      progress: g.stepProgress,
      rails: _rails,
      fx: _fx,
      time: _time,
      shake: shake,
      tumble: _beat == _Beat.derail ? _tumble : 0,
      fly: _fly,
      coupleT: _coupleT,
      arrive: _arriving
          ? (_unloaded / max(1, g.body.length - 1))
          : (_view == _View.results && _rArrived ? 1.0 : 0.0),
      reduce: _reduce,
    );
    final mat = TrainMat.of(g.course?.number ?? 0);
    final label = _fieldLabel(g);
    final canvas = ClipRect(
      child: SizedBox(
        width: fw,
        height: fh,
        child: CustomPaint(
          painter: TrainFieldPainter(scene, mat),
          size: Size(fw, fh),
        ),
      ),
    );
    return Container(
      width: fw + frame * 2,
      height: fh + frame * 2,
      decoration: BoxDecoration(
        color: const Color(0xFF8A5A2B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ink, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(frame - 2),
        child: Stack(
          children: [
            GestureDetector(
              key: ParcelTrainIds.field,
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                _dragX = 0;
                _dragY = 0;
              },
              onPanUpdate: _onPan,
              child: Semantics(label: label, child: canvas),
            ),
            if (_view == _View.play) ..._overlays(g, fw, fh),
          ],
        ),
      ),
    );
  }

  String _fieldLabel(TrainGame g) {
    final where = g.isCourse
        ? 'Course ${g.course!.number}, ${g.course!.name}'
        : 'Free ride';
    if (g.isCourse) {
      return 'Parcel train, $where, ${g.eaten} of ${g.goal} parcels, ${g.bumpers} bumpers left, '
          '${g.gateOpen ? 'station open, ' : ''}steer with the arrow keys';
    }
    return 'Parcel train, $where, ${g.eaten} parcels, steer with the arrow keys';
  }

  List<Widget> _overlays(TrainGame g, double fw, double fh) {
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
    return [
      if (_beat == _Beat.ready && !_paused)
        big(ParcelTrainIds.ready, 'All aboard!'),
      if (_beat == _Beat.derail)
        big(
          ParcelTrainIds.derail,
          'Derailed!\nTry again  ${_key(GameAction.action)}',
          color: const Color(0xFFFFD6D6),
        ),
      if (_bannerT > 0 && _beat == _Beat.run)
        Positioned(
          left: 0,
          right: 0,
          top: 8,
          child: IgnorePointer(
            child: Center(
              child: Container(
                key: ParcelTrainIds.banner,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: trainGold,
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
      key: ParcelTrainIds.paused,
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
              key: ParcelTrainIds.resume,
              label: 'Resume',
              keyText: _key(GameAction.pause),
              primary: true,
              onPressed: () => setState(() => _paused = false),
            ),
            const SizedBox(height: 10),
            _btn(
              key: ParcelTrainIds.leave,
              label: 'Leave',
              keyText: _key(GameAction.exit),
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
    final last = !_free && _course >= trainCourseCount - 1;
    final title = _rArrived
        ? 'Station reached!'
        : (_rNewBest ? 'New best!' : 'Parcel train over');
    final buttons = <Widget>[
      if (_free)
        _btn(
          key: ParcelTrainIds.again,
          label: 'Play again',
          keyText: _key(GameAction.action),
          primary: true,
          onPressed: _startFree,
        )
      else ...[
        if (!last)
          _selectable(
            _resSel == 0,
            _btn(
              key: ParcelTrainIds.next,
              label: 'Next course',
              keyText: _key(GameAction.action),
              primary: _resSel == 0,
              onPressed: () => _startCourse(_course + 1),
            ),
          ),
        _selectable(
          _resSel == 1 || last,
          _btn(
            key: ParcelTrainIds.replay,
            label: 'Replay',
            keyText: 'R',
            primary: _resSel == 1 || last,
            onPressed: () => _startCourse(_course),
          ),
        ),
      ],
      _btn(
        key: ParcelTrainIds.done,
        label: 'Menu',
        keyText: _key(GameAction.exit),
        onPressed: _toMenu,
      ),
    ];
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            key: ParcelTrainIds.results,
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
                      key: ParcelTrainIds.resultStars,
                      child: _starRow(shown, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Score $_rScore',
                  key: ParcelTrainIds.resultScore,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '$_rCoins coins',
                  key: ParcelTrainIds.resultCoins,
                  style: const TextStyle(color: _ink, fontSize: 15),
                ),
                if (_rNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _rNote,
                      style: const TextStyle(
                        color: Color(0xFF1E7A48),
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
        color: selected ? trainGold : Colors.transparent,
        width: 3,
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(2), child: child),
  );
}
