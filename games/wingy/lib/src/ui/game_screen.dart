import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../host/ad_service.dart';

import 'package:game_core/kit/audio/audio.dart' hide ambienceTracks;

import '../core/audio/wingy_audio.dart';
import '../host/profile_store.dart';
import '../host/services.dart';
import '../core/skins/flyer_skins.dart';
import '../game/flame/wingy_game.dart';
import '../game/rules/wingy_run.dart';
import '../game/rules/world.dart';
import 'game_over_panel.dart';
import '../host/routes.dart';
import 'share_card.dart';
import 'test_ids.dart';
import 'widgets.dart';

/// Player-facing label of the game over continue action (rewarded ad). Rename it here only.
const String continueLabel = 'Continue';

/// Game-over button sizes (see docs/SPEC.md, "Game over layout").
const double _kLargeFont = 22;
const EdgeInsets _kLargePadding = EdgeInsets.symmetric(
  horizontal: 28,
  vertical: 16,
);
const double _kSmallFont = 15;
const EdgeInsets _kSmallPadding = EdgeInsets.symmetric(
  horizontal: 18,
  vertical: 9,
);

const int _wingySeed = int.fromEnvironment('WINGY_SEED', defaultValue: -1);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded run).
  final WingyGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  WingyGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;
  bool _pauseOpen = false;
  bool _refillArmed = false;
  final AudioService _audio = newWingyAudio();
  bool _started = false;
  WingyServices? _services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tells Home (the tip of the day) that a run is on screen; cleared in dispose.
    _services =
        context.getInheritedWidgetOfExactType<WingyServicesScope>()?.services
          ?..inRun = true;
  }

  @override
  void dispose() {
    _services?.inRun = false;
    WidgetsBinding.instance.removeObserver(this);
    _audio.dispose();
    super.dispose();
  }

  void _syncAudio(WingyServices s) {
    final d = s.profile.data;
    _audio.apply(
      sound: d.soundOn,
      volume: d.masterVolume,
      ambience: d.ambience,
      voice: d.voiceOn,
      sfx: d.sfxOn,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _audio.pauseAmbience();
      _pause();
    } else if (!_pauseOpen) {
      _audio.startAmbience();
    }
  }

  WingyRun _newRun(WingyServices s, {int meter = 0}) => WingyRun(
    random: _wingySeed >= 0 ? Random(_wingySeed) : null,
    bestScore: s.profile.data.bestScore,
    startMeter: meter,
    paletteStart: s.profile.data.paletteStart,
  );

  WingyGame _ensureGame(WingyServices s) {
    final existing = _game;
    if (existing != null) return existing;
    // An unfinished run (autosave) comes back paused; a bad save is dropped.
    WingyRun? restored;
    final saved = widget.game == null ? s.profile.data.game : null;
    if (saved != null) {
      restored = WingyRun.restore(saved, bestScore: s.profile.data.bestScore);
      if (restored == null) {
        // Not during build: clearing notifies the profile's listeners.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => s.profile.saveGame(null),
        );
      }
    }
    final game =
        widget.game ??
        WingyGame(
          run: restored ?? _newRun(s),
          reduceMotion: s.profile.data.reduceMotion,
        );
    if (restored != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Game resumed')));
        _pause();
      });
    }
    game.onChanged = () {
      if (!mounted) return;
      setState(() {});
    };
    game.onEvent = (e) {
      _playEventAudio(s, game, e);
      _autosaveOn(s, game, e);
      if (!s.profile.data.vibrationOn) return;
      if (e.type == RunEventType.perfect) HapticFeedback.lightImpact();
      if (e.type == RunEventType.hit) HapticFeedback.mediumImpact();
    };
    game.onGameOver = () {
      _syncAudio(s);
      _audio.sfx('game_over');
      if (game.run.score > s.profile.data.bestScore) {
        _audio.voice('better_than_the_best');
      } else {
        _audio.voice('game_over', variants: 2);
      }
      _showGameOver(s);
    };
    _syncAudio(s);
    _audio.startAmbience();
    _audio.voice('get_ready');
    return _game = game;
  }

  /// Saves the run after each pass or orb (the moments that change the score) and clears the
  /// save when the run ends, so Back, a call or a kill never loses it.
  void _autosaveOn(WingyServices s, WingyGame game, RunEvent e) {
    if (widget.game != null) return;
    switch (e.type) {
      case RunEventType.hit:
        s.profile.saveGame(null);
      case RunEventType.pass ||
          RunEventType.perfect ||
          RunEventType.shatter ||
          RunEventType.orb:
        _autosave(s, game);
      default:
        break;
    }
  }

  void _autosave(WingyServices s, WingyGame game) {
    if (widget.game != null) return;
    final run = game.run;
    if (run.phase == RunPhase.playing && !run.isDead) {
      s.profile.saveGame(run.toJson());
    }
  }

  /// Perfect-pass streak lengths that earn a narrator line, highest first.
  static const _praise = <(int, String)>[
    (30, 'unbelievable'),
    (20, 'incredible'),
    (16, 'fantastic'),
    (12, 'awesome'),
    (8, 'excellent'),
    (5, 'great'),
    (3, 'nice'),
  ];

  void _playEventAudio(WingyServices s, WingyGame game, RunEvent e) {
    _syncAudio(s);
    switch (e.type) {
      case RunEventType.flap:
        _audio.sfx('flap');
        if (game.run.pairsPassed == 0 && !_started) {
          _started = true;
          _audio.voice('go');
        }
      case RunEventType.pass:
        _audio.sfx('pass');
      case RunEventType.perfect:
        final streak = game.run.perfectStreak;
        _audio.sfx('perfect_${streak.clamp(1, 7)}');
        for (final (at, name) in _praise) {
          if (streak == at) {
            _audio.voice(name);
            break;
          }
        }
      case RunEventType.orb:
        _audio.sfx('orb');
      case RunEventType.dashStart:
        _audio.sfx('dash');
      case RunEventType.dashEnd:
        break;
      case RunEventType.shatter:
        _audio.sfx('shatter');
        _audio.voice('smashed_it');
      case RunEventType.hit:
        _audio.sfx('hit');
      case RunEventType.revive:
        _audio.voice('revived');
    }
  }

  // ---- run bookkeeping ------------------------------------------------------

  Future<void> _finishGame(WingyServices s) async {
    if (_recorded) return;
    final run = _game!.run;
    if (run.phase == RunPhase.ready) return;
    _recorded = true;
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: run.score,
        pairsPassed: run.pairsPassed,
        perfectStreak: run.maxStreak,
        orbs: run.orbsCollected,
        dashUses: run.dashUses,
        dashShattered: run.dashShattered,
        bloomHits: run.bloomHits,
        coins: run.coins + run.scoreCoins,
      ),
    );
    await s.leaderboard.submitScore(s.config.leaderboardHighScore, run.score);
    for (final a in unlocked) {
      await s.leaderboard.unlockAchievement(a.id);
    }
    s.analytics.logEvent('game_over', {'score': run.score});
    if (unlocked.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')} '
            '(+${unlocked.fold<int>(0, (n, a) => n + a.reward)} coins)',
          ),
        ),
      );
    }
  }

  /// Exit from the pause dialog: an unfinished run stays saved (autosaved when paused) and
  /// is recorded when it ends; a run that never started has nothing to keep.
  Future<void> _quit(WingyServices s) async {
    final run = _game!.run;
    final keep =
        widget.game == null && run.phase == RunPhase.playing && !run.isDead;
    if (!keep) await _finishGame(s);
    if (mounted) Navigator.of(context).pop();
  }

  // ---- pause ---------------------------------------------------------------

  Future<void> _pause() async {
    final game = _game;
    if (game == null || !mounted || _pauseOpen || _dialogOpen) return;
    if (game.run.isDead) return;
    final s = WingyServicesScope.of(context);
    game.pause();
    _autosave(s, game);
    _audio.pauseAmbience();
    _pauseOpen = true;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Paused'),
        actions: [
          TextButton(
            key: TestIds.gamePauseQuit,
            onPressed: () => Navigator.pop(ctx, 'quit'),
            child: const Text('Exit'),
          ),
          FilledButton(
            key: TestIds.gamePauseResume,
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    _pauseOpen = false;
    if (!mounted) return;
    if (action == 'quit') {
      await _quit(s);
    } else {
      game.resume();
      _audio.startAmbience();
    }
  }

  // ---- game over -------------------------------------------------------------

  static String _medalName(Medal m) => switch (m) {
    Medal.none => 'No medal',
    Medal.bronze => 'Bronze',
    Medal.silver => 'Silver',
    Medal.gold => 'Gold',
    Medal.prism => 'Prism',
  };

  Future<void> _showGameOver(WingyServices s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final run = game.run;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => GameOverPanel(
          key: TestIds.gameOverDialog,
          panelKey: TestIds.gameOverPanel,
          viewKey: TestIds.gameOverView,
          title: 'Game over',
          shareButton: GameOverButton(
            key: TestIds.gameOverShare,
            kind: GameOverButtonKind.ghost,
            fontSize: _kSmallFont,
            padding: _kSmallPadding,
            icon: Icons.share,
            semanticLabel: 'Share',
            onPressed: () async {
              final png = await captureShareCard(
                ctx,
                ShareCardData(
                  gameName: s.config.displayName,
                  headline: 'Score',
                  big: '${run.score}',
                  best: run.bestScore,
                  palette: run.palette,
                  medal: _medalName(run.medal),
                ),
              );
              await s.share.shareScore(score: run.score, image: png);
            },
          ),
          details: [
            Text(
              '${run.score}',
              key: TestIds.gameOverScore,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
            ),
            Text('Best ${run.bestScore}', key: TestIds.gameOverBest),
            Text(_medalName(run.medal), key: TestIds.gameOverMedal),
            if (!s.profile.data.adsRemoved)
              RemoveAdsPill(
                key: TestIds.gameOverRemoveAds,
                onPressed: () => Navigator.of(ctx).pushNamed(WingyRoutes.shop),
              ),
          ],
          extraButton: GameOverButton(
            key: TestIds.gameOverRefill,
            fontSize: _kSmallFont,
            padding: _kSmallPadding,
            icon: Icons.bolt,
            label: _refillArmed
                ? 'Dash ready'
                : 'Dash Refill (${s.profile.dashRefills})',
            onPressed: _refillArmed
                ? null
                : () async {
                    if (s.profile.dashRefills > 0) {
                      setDialog(() => _refillArmed = true);
                      return;
                    }
                    final got = await showModalBottomSheet<bool>(
                      context: ctx,
                      builder: (_) => _RefillSheet(services: s),
                    );
                    if (got == true) setDialog(() => _refillArmed = true);
                  },
          ),
          leadButton: run.canRevive
              ? GameOverButton(
                  key: TestIds.gameOverRevive,
                  kind: GameOverButtonKind.primary,
                  icon: Icons.smart_display,
                  label: '$continueLabel · ${run.revivesLeft} left',
                  fontSize: _kLargeFont,
                  padding: _kLargePadding,
                  onPressed: () => Navigator.pop(ctx, 'revive'),
                )
              : null,
          buttons: [
            GameOverButton(
              key: TestIds.gameOverRetry,
              kind: run.canRevive
                  ? GameOverButtonKind.secondary
                  : GameOverButtonKind.primary,
              icon: Icons.replay,
              label: 'Play again',
              fontSize: run.canRevive ? _kSmallFont : _kLargeFont,
              padding: run.canRevive ? _kSmallPadding : _kLargePadding,
              onPressed: () => Navigator.pop(ctx, 'retry'),
            ),
            GameOverButton(
              key: TestIds.gameOverHome,
              kind: GameOverButtonKind.ghost,
              icon: Icons.home,
              label: 'Home',
              fontSize: _kSmallFont,
              padding: _kSmallPadding,
              onPressed: () => Navigator.pop(ctx, 'home'),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        // Remove Ads (s.rewarded grants at once) or an earned rewarded ad; never coins.
        final earned = await s.rewarded(WingyAdPlacement.revive);
        if (!mounted) return;
        if (earned && run.revive()) {
          game.revived();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ad available right now. Try again in a moment.'),
          ),
        );
        _showGameOver(s);
      case 'retry':
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        var meter = 0;
        if (_refillArmed && await s.profile.consumeDashRefill()) meter = 3;
        _refillArmed = false;
        _recorded = false;
        game.newRun(_newRun(s, meter: meter));
        _started = false;
        _audio.voice('get_ready');
      default:
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (mounted) Navigator.of(context).pop();
    }
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = WingyServicesScope.of(context);
    final game = _ensureGame(s);
    game.reduceMotion = s.profile.data.reduceMotion;
    game.skin = FlyerSkins.of(s.profile.data.equippedSkin);
    final run = game.run;
    final left = s.profile.data.leftHanded;
    final dashState = run.isDashing
        ? 'active'
        : (run.canDash ? 'ready' : 'off');
    final scaffold = Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              key: TestIds.gameField,
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => game.tap(),
              child: GameWidget<WingyGame>(key: TestIds.gameWidget, game: game),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: left ? null : 8,
                  right: left ? 8 : null,
                  child: Column(
                    crossAxisAlignment: left
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      IconButton.filledTonal(
                        key: TestIds.gameBack,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _pause,
                      ),
                      const SizedBox(height: 8),
                      _Meter(pips: run.meter),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: _ScoreArea(
                      score: run.score,
                      best: run.bestScore,
                      streak: run.perfectStreak,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: left ? 8 : null,
                  right: left ? null : 8,
                  child: IconButton.filledTonal(
                    key: TestIds.gamePause,
                    icon: const Icon(Icons.pause),
                    onPressed: _pause,
                  ),
                ),
                Positioned(
                  bottom: 28,
                  left: left ? 20 : null,
                  right: left ? null : 20,
                  child: Semantics(
                    key: TestIds.gameDashState,
                    identifier: 'game.dash.state',
                    value: dashState,
                    child: _DashButton(
                      state: dashState,
                      onPressed: run.canDash && game.countdown == 0
                          ? game.dash
                          : null,
                    ),
                  ),
                ),
                if (run.phase == RunPhase.ready)
                  Center(
                    child: GestureDetector(
                      key: TestIds.gameReady,
                      behavior: HitTestBehavior.opaque,
                      onTap: game.tap,
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'TAP TO FLAP',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 22,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (game.countdownNumber > 0)
                  Center(
                    child: IgnorePointer(
                      child: Text(
                        '${game.countdownNumber}',
                        key: TestIds.gameCountdown,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 96,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    // Back pauses (the pause dialog offers Resume or Exit) instead of ending the run.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: scaffold,
    );
  }
}

/// Score in a glowing pill with best score and Bloom streak chip.
class _ScoreArea extends StatelessWidget {
  const _ScoreArea({
    required this.score,
    required this.best,
    required this.streak,
  });
  final int score;
  final int best;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 120),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFB896FF), width: 1.5),
                color: const Color(0x22FFFFFF),
                boxShadow: const [
                  BoxShadow(color: Color(0x66B896FF), blurRadius: 22),
                ],
              ),
              child: Text(
                '$score',
                key: TestIds.gameScore,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Semantics(
              key: TestIds.gameStreak,
              identifier: 'game.streak',
              value: '$streak',
              child: streak >= 2
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        avatar: const Icon(
                          Icons.local_florist,
                          size: 16,
                          color: Color(0xFFFFE066),
                        ),
                        label: Text('x$streak'),
                      ),
                    )
                  : const SizedBox(width: 0, height: 0),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$best',
          key: TestIds.gameBest,
          style: const TextStyle(color: Color(0xFFFFE066), fontSize: 13),
        ),
      ],
    );
  }
}

/// Three-pip Glow Dash meter.
class _Meter extends StatelessWidget {
  const _Meter({required this.pips});
  final int pips;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: TestIds.gameMeter,
      identifier: 'game.meter',
      value: '$pips',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < WingyWorld.meterMax; i++)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < pips
                    ? const Color(0xFF7CF5FF)
                    : const Color(0x33FFFFFF),
                boxShadow: i < pips
                    ? const [BoxShadow(color: Color(0xAA7CF5FF), blurRadius: 8)]
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DashButton extends StatelessWidget {
  const _DashButton({required this.state, required this.onPressed});
  final String state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ready = state == 'ready';
    final active = state == 'active';
    return SizedBox(
      width: 76,
      height: 76,
      child: FilledButton(
        key: TestIds.gameDash,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: active
              ? const Color(0xFFFFE066)
              : (ready ? const Color(0xFF7CF5FF) : const Color(0x33FFFFFF)),
          foregroundColor: const Color(0xFF1B1446),
          disabledBackgroundColor: active
              ? const Color(0xFFFFE066)
              : const Color(0x33FFFFFF),
          disabledForegroundColor: active
              ? const Color(0xFF1B1446)
              : Colors.white38,
        ),
        onPressed: onPressed,
        child: const Icon(Icons.bolt, size: 40),
      ),
    );
  }
}

/// Bottom sheet offering a Dash Refill for coins or for a rewarded ad.
class _RefillSheet extends StatelessWidget {
  const _RefillSheet({required this.services});
  final WingyServices services;

  @override
  Widget build(BuildContext context) {
    final p = services.profile;
    return SafeArea(
      key: TestIds.gameRefillSheet,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              'Start the next run with a full Glow Dash',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // What the power does, readable before spending anything.
            Text(
              'Glow Dash is a short burst of speed that smashes through '
              'spires without a scratch.',
              key: TestIds.gameRefillDescription,
              textAlign: TextAlign.center,
            ),
            FilledButton.icon(
              key: TestIds.gameRefillCoins,
              icon: const CoinIcon(),
              label: Text('Use ${WingyProfileStore.dashRefillCoinCost} coins'),
              onPressed: p.data.coins >= WingyProfileStore.dashRefillCoinCost
                  ? () async {
                      final ok = await p.buyDashRefillWithCoins();
                      if (context.mounted) Navigator.pop(context, ok);
                    }
                  : null,
            ),
            OutlinedButton.icon(
              key: TestIds.gameRefillAd,
              icon: const Icon(Icons.smart_display),
              label: Text('Watch an ad (${p.adRefillsLeft} left today)'),
              onPressed: p.adRefillsLeft > 0
                  ? () async {
                      final earned = await services.rewarded(
                        WingyAdPlacement.dashRefill,
                      );
                      final ok = earned && await p.grantAdDashRefill();
                      if (context.mounted) Navigator.pop(context, ok);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
