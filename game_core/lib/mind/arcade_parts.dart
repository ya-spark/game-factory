import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/minigames/fixed_step/fixed_step.dart';
import '../engine/stats/game_stats.dart';
import '../host/game_host.dart';
import '../kit/game_parts.dart';
import '../kit/keys/keys.dart';
import '../kit/layout/game_chrome.dart';
import '../kit/layout/window_class.dart';
import 'mind_ids.dart';
import 'run_report.dart';

/// The frame shared by the arcade games (Brick breaker, Stack tower, Runner): a menu, the
/// play view, and a results screen. Banners show on the menu and the results only, never in
/// play. The Continue is a rewarded ad, at most once per game over. Instant restart: Play again
/// builds the next round at once. The views are here; the rules are pure Dart under
/// `lib/engine/minigames/`.

/// The game's side of the frame: a game calls [end] when the round is over and registers
/// [onContinue] to be told when the player earned a Continue.
class ArcadeRun {
  ArcadeRun({required this.end, required this.canContinue});

  /// Reports the round's score. [canContinue] says whether the round may offer a Continue.
  final void Function(int score, {bool canContinue}) end;

  /// Whether this game has a Continue at all.
  final bool canContinue;

  /// Set by the game's state; called after the Continue ad is earned. Resumes the round.
  VoidCallback? onContinue;

  /// Set by the game's state: a key press while the round is running (not paused). The frame keeps
  /// Enter (start, play again), Space (pause) and Esc (pause, leave) for itself.
  void Function(GameInput input)? onInput;

  /// Set by the game's state: a key came up (for games where a held key means a held direction).
  void Function(GameInput input)? onRelease;
}

enum _Phase { menu, play, over }

class ArcadeFrame extends StatefulWidget {
  const ArcadeFrame({
    super.key,
    required this.id,
    required this.title,
    required this.howTo,
    required this.starScores,
    required this.coinsPerPoints,
    required this.buildPlay,
    this.onScore,
    this.hasContinue = false,
    this.menuExtras,
    this.prefs,
    this.scoreLabel = 'Score',
    this.hintActions = const [],
    this.hintWords = const {},
  });

  /// Replaces the short word of a play hint (Runner says "jump" for up).
  final Map<GameAction, String> hintWords;

  /// The keys the play view uses, shown under the game on windows 600 dp and wider.
  final List<GameAction> hintActions;

  final String id;
  final String title;
  final String howTo;
  final List<int> starScores;

  /// One coin per this many points, at most 20 a round.
  final int coinsPerPoints;
  final bool hasContinue;
  final String scoreLabel;
  final void Function(int score)? onScore;

  /// Builds the play view. [round] counts up from 1 and changes on each new round, so the game
  /// can start fresh state on it.
  final Widget Function(BuildContext context, ArcadeRun run, int round)
  buildPlay;

  /// Settings under the Play button on the menu.
  final Widget Function(BuildContext context, VoidCallback changed)? menuExtras;
  final SharedPreferences? prefs;

  @override
  State<ArcadeFrame> createState() => _ArcadeFrameState();
}

class _ArcadeFrameState extends State<ArcadeFrame> {
  SharedPreferences? _prefs;
  _Phase _phase = _Phase.menu;
  int _round = 0;
  int _best = 0;
  int _score = 0;
  int _coins = 0;
  bool _offerContinue = false;
  bool _continueUsed = false;
  bool _busy = false;
  bool _paused = false;
  late ArcadeRun _run = _newRun();

  String get _bestKey => 'arcade.${widget.id}.best';

  ArcadeRun _newRun() =>
      ArcadeRun(end: _ended, canContinue: widget.hasContinue);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _best = p.getInt(_bestKey) ?? 0;
    });
  }

  void _start() {
    setState(() {
      _round++;
      _run = _newRun();
      _continueUsed = false;
      _offerContinue = false;
      _paused = false;
      _phase = _Phase.play;
    });
  }

  void _ended(int score, {bool canContinue = false}) {
    if (_phase != _Phase.play) return;
    final coins = arcadeCoins(score, perCoins: widget.coinsPerPoints);
    // A Continue that was used pays only the difference: coins are paid for the final score.
    final already = _continueUsed ? _coins : 0;
    final pay = coins - already;
    if (pay > 0) GameHostScope.of(context).addCoins(context, pay);
    if (score > _best) {
      _best = score;
      _prefs?.setInt(_bestKey, score);
    }
    // One report per run: a run continued with a rewarded ad was already reported at its first end.
    if (!_continueUsed) {
      RunReportScope.finished(context, score, const RunExtras());
    }
    widget.onScore?.call(score);
    setState(() {
      _score = score;
      _coins = coins;
      _offerContinue = widget.hasContinue && canContinue && !_continueUsed;
      _paused = false;
      _phase = _Phase.over;
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    _busy = true;
    final ok = await GameHostScope.of(context).rewardedContinue(context);
    _busy = false;
    if (!mounted || !ok) return;
    setState(() {
      _continueUsed = true;
      _offerContinue = false;
      _phase = _Phase.play;
    });
    _run.onContinue?.call();
  }

  // ---- keyboard (docs/KEYBOARD.md): Enter starts or plays again, Space and Esc pause, the rest is the game's ----

  void _toMenu() => setState(() {
    _paused = false;
    _phase = _Phase.menu;
  });

  void _togglePause() {
    if (_phase != _Phase.play) return;
    setState(() => _paused = !_paused);
  }

  void _onInput(GameInput i) {
    final once = i.action == GameAction.pause || i.action == GameAction.exit;
    if (i.repeat && once) return;
    switch (_phase) {
      case _Phase.menu:
        if (i.repeat) return;
        if (i.action == GameAction.action || i.action == GameAction.pause) {
          _start();
        } else if (i.action == GameAction.exit) {
          Navigator.of(context).maybePop();
        }
      case _Phase.over:
        if (i.repeat) return;
        if (i.action == GameAction.action || i.action == GameAction.pause) {
          _start();
        } else if (i.action == GameAction.exit) {
          _toMenu();
        }
      case _Phase.play:
        if (once) {
          _togglePause();
        } else if (_paused) {
          if (!i.repeat && i.action == GameAction.action) _togglePause();
        } else {
          _run.onInput?.call(i);
        }
    }
  }

  void _onRelease(GameInput i) {
    if (_phase == _Phase.play && !_paused) _run.onRelease?.call(i);
  }

  List<GameAction> get _hints => switch (_phase) {
    _Phase.menu => const [GameAction.action, GameAction.exit],
    _Phase.over => const [GameAction.action, GameAction.exit],
    _Phase.play => [...widget.hintActions, GameAction.pause],
  };

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(
          key: MindIds.arcade(widget.id, 'back'),
          onPressed: () {
            if (_phase == _Phase.play) {
              _toMenu();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: GameKeyboard(
          onInput: _onInput,
          onRelease: _onRelease,
          // L leaves the round to the menu (the pause screen's Leave shows it); C is Continue on the results.
          shortcuts: {
            LogicalKeyboardKey.keyL: () {
              if (_phase == _Phase.play) _toMenu();
            },
            LogicalKeyboardKey.keyC: () {
              if (_phase == _Phase.over && _offerContinue) _continue();
            },
          },
          child: Column(
            children: [
              Expanded(
                child: switch (_phase) {
                  _Phase.menu => _menu(context),
                  // The play view stays mounted (hidden, ticker muted) while the results show, so a
                  // Continue resumes the same round.
                  _ => Stack(
                    fit: StackFit.expand,
                    children: [
                      Offstage(
                        offstage: _phase != _Phase.play,
                        child: TickerMode(
                          enabled: _phase == _Phase.play && !_paused,
                          child: widget.buildPlay(context, _run, _round),
                        ),
                      ),
                      if (_phase == _Phase.over) _over(context),
                      if (_phase == _Phase.play && _paused)
                        PauseOverlay(
                          overlayKey: MindIds.arcade(widget.id, 'paused'),
                          resumeKey: MindIds.arcade(widget.id, 'resume'),
                          onResume: _togglePause,
                          onLeave: _toMenu,
                          leaveKey: MindIds.arcade(widget.id, 'leave'),
                        ),
                    ],
                  ),
                },
              ),
              if (wide)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KeyHints(
                    actions: _hints,
                    words: widget.hintWords,
                    spaceGoesOn: _phase != _Phase.play,
                    extra: [
                      if (_phase == _Phase.play && _paused) ('L', 'leave'),
                      if (_phase == _Phase.over && _offerContinue)
                        ('C', 'continue'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(GameBannerSlot p) {
    return KeyedSubtree(
      key: MindIds.arcadeBanner(
        widget.id,
        p == GameBannerSlot.menu ? 'menu' : 'results',
      ),
      child: GameHostScope.of(context).banner(context, p),
    );
  }

  Widget _menu(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.howTo, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Semantics(
                label: 'Best ${widget.scoreLabel.toLowerCase()} $_best',
                child: ExcludeSemantics(
                  child: Text(
                    'Best $_best',
                    key: MindIds.arcade(widget.id, 'best'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: MindIds.arcade(widget.id, 'play'),
                  onPressed: _start,
                  child: const KeyedText(
                    'Play',
                    GameAction.action,
                    alsoSpace: true,
                  ),
                ),
              ),
              if (widget.menuExtras != null) ...[
                const SizedBox(height: 16),
                widget.menuExtras!(context, () => setState(() {})),
              ],
            ],
          ),
        ),
        _banner(GameBannerSlot.menu),
      ],
    );
  }

  Widget _over(BuildContext context) {
    final theme = Theme.of(context);
    final stars = arcadeStars(_score, widget.starScores);
    final isBest = _score > 0 && _score >= _best;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isBest ? 'New best!' : 'Game over',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    container: true,
                    label:
                        '${widget.scoreLabel} $_score. $stars of 3 stars. '
                        '$_coins coins earned.',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(
                            '${widget.scoreLabel} $_score',
                            key: MindIds.arcade(widget.id, 'result.score'),
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            '$stars of 3 stars',
                            key: MindIds.arcade(widget.id, 'result.stars'),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '$_coins coins',
                            key: MindIds.arcade(widget.id, 'result.coins'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GameHostScope.of(context)
                      .leaderboardEntry(context, widget.id),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      if (_offerContinue)
                        FilledButton.tonal(
                          key: MindIds.arcade(widget.id, 'continue'),
                          onPressed: _continue,
                          child: Text(withKey('Continue', 'C')),
                        ),
                      FilledButton(
                        key: MindIds.arcade(widget.id, 'again'),
                        onPressed: _start,
                        child: const KeyedText(
                          'Play again',
                          GameAction.action,
                          alsoSpace: true,
                        ),
                      ),
                      OutlinedButton(
                        key: MindIds.arcade(widget.id, 'done'),
                        onPressed: () => setState(() => _phase = _Phase.menu),
                        child: Text(
                          keyedLabel(context, 'Done', GameAction.exit),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(GameBannerSlot.postGame),
      ],
    );
  }
}

/// A switch row for a game setting on the menu.
class ArcadeSwitch extends StatelessWidget {
  const ArcadeSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(label),
    value: value,
    onChanged: onChanged,
    contentPadding: EdgeInsets.zero,
  );
}

/// The score line above the play field.
class ArcadeHud extends StatelessWidget {
  const ArcadeHud({super.key, required this.game, required this.text});
  final String game;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Semantics(
      liveRegion: false,
      label: text,
      child: ExcludeSemantics(
        child: Text(
          text,
          key: MindIds.arcade(game, 'hud'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ),
  );
}

/// Colours of the arcade playfields, from the theme, so contrast follows the app.
class ArcadePalette {
  ArcadePalette(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    background = c.surfaceContainerHighest;
    line = c.outline;
    primary = c.primary;
    accent = c.tertiary;
    danger = c.error;
    onPrimary = c.onPrimary;
  }
  late final Color background;
  late final Color line;
  late final Color primary;
  late final Color accent;
  late final Color danger;
  late final Color onPrimary;
}

/// True when the system or the theme asks for less motion.
bool arcadeReduceMotion(BuildContext context) => reduceMotionOf(context);
