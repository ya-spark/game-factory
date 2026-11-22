import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';

import 'memory_match_ids.dart';
import 'rules/memory_match_rules.dart';
import 'rules/memory_match_turns.dart';

/// Memory match for two players on one device (docs/SPEC.md, "Two players"): the players take
/// turns on the same board; a match keeps the turn, a mismatch passes it. Most pairs wins a
/// board, most boards wins the round. Nothing is recorded: no stars, coins or progress, so it
/// never touches the quiz session. The active player uses their own keys (player 1 the arrows
/// and Enter, player 2 W A S D and F); touch works for the active player.
class MemoryMatchTwoPlayerScreen extends StatefulWidget {
  const MemoryMatchTwoPlayerScreen({
    super.key,
    required this.items,
    required this.level,
    required this.onExit,
    this.random,
    this.reader,
    this.mismatchDelay = const Duration(milliseconds: 900),
  });

  /// The boards, one `pairs` item each (the session's items, read only).
  final List<PoolItem> items;
  final MatchLevel level;
  final VoidCallback onExit;
  final Random? random;
  final GameReadAloud? reader;
  final Duration mismatchDelay;

  @override
  State<MemoryMatchTwoPlayerScreen> createState() =>
      _MemoryMatchTwoPlayerScreenState();
}

class _MemoryMatchTwoPlayerScreenState
    extends State<MemoryMatchTwoPlayerScreen> {
  late final Random _random = widget.random ?? Random();
  late MemoryTurnsMatch _match;
  late MemoryTurnBoard _turn;
  int _index = 0;
  bool _boardCounted = false;
  bool _showFinal = false;
  bool _paused = false;
  bool _keyboardUsed = false;
  final Map<int, int> _cursor = {1: 0, 2: 0};
  final Map<int, BuildContext> _cardContexts = {};
  Timer? _hide;
  int _firstStarter = 1;
  String _announce = '';

  @override
  void initState() {
    super.initState();
    _newMatch();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _newMatch() {
    _match = MemoryTurnsMatch(
      boardCount: widget.items.length,
      firstStarter: _firstStarter,
    );
    _index = 0;
    _beginBoard();
  }

  void _beginBoard() {
    _hide?.cancel();
    final board = MemoryMatchBoard.fromItem(
      widget.items[_index].item,
      widget.level,
      _random,
    );
    _turn = MemoryTurnBoard(board, starter: _match.starterFor(_index));
    _boardCounted = false;
    _showFinal = false;
    _cursor[1] = 0;
    _cursor[2] = 0;
    _announce = "Player ${_turn.player}'s turn";
  }

  /// The round's result screen is showing (after "See results").
  bool get _roundOver => _showFinal;
  bool get _playing => !_turn.complete && !_roundOver;

  void _flip(int i) {
    if (_paused || !_playing) return;
    final o = _turn.flip(i);
    if (o == FlipOutcome.ignored) return;
    setState(() {
      if (o == FlipOutcome.match) {
        _announce = 'Player ${_turn.player} found a pair';
        if (_turn.complete) _finishBoard();
      } else if (o == FlipOutcome.mismatch) {
        _announce = 'No match';
        _scheduleSettle();
      }
    });
  }

  void _scheduleSettle() {
    _hide?.cancel();
    _hide = Timer(widget.mismatchDelay, () {
      if (!mounted || _paused) return;
      setState(() {
        _turn.settleMismatch();
        _announce = "Player ${_turn.player}'s turn";
      });
    });
  }

  void _finishBoard() {
    if (_boardCounted) return;
    _match.record(_turn);
    _boardCounted = true;
    final w = _turn.winner;
    _announce = w == 0 ? 'The board is a draw' : 'Player $w wins the board';
  }

  void _next() {
    if (!_turn.complete || _roundOver) return;
    setState(() {
      if (_match.over) {
        _showFinal = true;
      } else {
        _index++;
        _beginBoard();
      }
    });
  }

  void _playAgain() {
    setState(() {
      _firstStarter = otherPlayer(_firstStarter);
      _newMatch();
    });
  }

  void _togglePause() {
    if (!_playing) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _hide?.cancel();
    } else if (_turn.waitingToSettle) {
      _scheduleSettle();
    }
  }

  // ---- keyboard: only the player whose turn it is can act (docs/KEYBOARD.md) ----

  void _onInput(GameInput i) {
    if (i.action == GameAction.exit) {
      if (i.repeat) return;
      if (_playing) {
        _togglePause();
      } else {
        widget.onExit();
      }
      return;
    }
    if (i.action == GameAction.pause && _playing) {
      if (!i.repeat) _togglePause();
      return;
    }
    if (_paused) return;
    if (!_playing) {
      // Enter or Space goes on (Next board, See results, play again); never pauses here (U2).
      final goOn =
          i.action == GameAction.action || i.action == GameAction.pause;
      if (goOn && !i.repeat) {
        _roundOver ? _playAgain() : _next();
      }
      return;
    }
    if (i.player != _turn.player) return;
    final p = _turn.player;
    final board = _turn.board;
    final cols = board.columns;
    final count = board.cards.length;
    final at = _cursor[p]!;
    int? to;
    switch (i.action) {
      case GameAction.left:
        to = at % cols == 0 ? at : at - 1;
      case GameAction.right:
        to = at % cols == cols - 1 || at + 1 >= count ? at : at + 1;
      case GameAction.up:
        to = at - cols >= 0 ? at - cols : at;
      case GameAction.down:
        to = at + cols < count ? at + cols : at;
      case GameAction.action:
        if (!i.repeat) {
          setState(() => _keyboardUsed = true);
          _flip(at);
        }
      default:
        break;
    }
    if (to != null) {
      setState(() {
        _keyboardUsed = true;
        _cursor[p] = to!;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _cardContexts[_cursor[p]];
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, duration: Duration.zero);
        }
      });
    }
  }

  // ---- look ----

  Color _color(ColorScheme cs, int p) => p == 1 ? cs.primary : cs.secondary;
  IconData _marker(int p) => p == 1 ? Icons.circle : Icons.square;

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      key: MemoryMatchIds.matchScreen,
      body: SafeArea(
        child: GameKeyboard(
          twoPlayer: true,
          onInput: _onInput,
          shortcuts: {LogicalKeyboardKey.keyL: widget.onExit},
          child: GameFrame(
            showAds: !_playing,
            phoneBanner: null,
            child: Column(
              children: [
                GameTopBar(
                  title: 'Memory match: 2 players',
                  onExit: widget.onExit,
                  exitKey: MemoryMatchIds.matchExit,
                  onPause: _playing ? _togglePause : null,
                  pauseKey: MemoryMatchIds.matchPause,
                  paused: _paused,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      _roundOver ? _final(context) : _boardView(context),
                      if (_paused)
                        PauseOverlay(
                          overlayKey: MemoryMatchIds.matchPaused,
                          resumeKey: MemoryMatchIds.matchResume,
                          onResume: _togglePause,
                          onLeave: widget.onExit,
                          leaveKey: MemoryMatchIds.matchLeave,
                        ),
                    ],
                  ),
                ),
                if (wide) _hints(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hints(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget row(int p) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_marker(p), size: 14, color: _color(cs, p)),
        const SizedBox(width: 6),
        Flexible(
          child: KeyHints(
            player: p,
            actions: const [
              GameAction.left,
              GameAction.right,
              GameAction.up,
              GameAction.down,
              GameAction.action,
            ],
            words: const {GameAction.action: 'turn'},
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 6,
        children: [row(1), row(2)],
      ),
    );
  }

  Widget _chip(BuildContext context, int p) {
    final cs = Theme.of(context).colorScheme;
    final active = _playing && _turn.player == p;
    final pairs = _turn.pairsOf(p);
    return Semantics(
      label:
          'Player $p, $pairs ${pairs == 1 ? 'pair' : 'pairs'}'
          '${active ? ', your turn' : ''}',
      excludeSemantics: true,
      child: Container(
        key: p == 1 ? MemoryMatchIds.matchP1Score : MemoryMatchIds.matchP2Score,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _color(cs, p).withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color(cs, p), width: active ? 3 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_marker(p), color: _color(cs, p), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Player $p: $pairs',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boardView(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = _turn.board;
    final scores = Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [_chip(context, 1), _chip(context, 2)],
    );
    final compact = WindowClass.ofContext(context) == WindowClass.compact;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Board ${_index + 1} of ${widget.items.length}',
            key: MemoryMatchIds.matchProgress,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _playing ? "Player ${_turn.player}'s turn" : _announce,
              key: MemoryMatchIds.matchTurn,
              style: theme.textTheme.titleLarge?.copyWith(
                color: _color(cs, _turn.player),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (compact) ...[scores, const SizedBox(height: 12)],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: b.cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: b.columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 96 * MediaQuery.textScalerOf(context).scale(1),
            ),
            itemBuilder: (_, i) => _card(context, i),
          ),
          if (!compact) ...[const SizedBox(height: 12), scores],
          if (_turn.complete) ..._boardResult(theme),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, int i) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = _turn.board;
    final up = b.isFaceUp(i);
    final matched = b.matched.contains(i);
    final owner = _turn.ownerOf(i);
    final card = b.cards[i];
    final onCursor = _keyboardUsed && _playing && _cursor[_turn.player] == i;
    final label = up
        ? (matched ? '${card.text}, matched by player $owner' : card.text)
        : 'Card ${i + 1}, face down';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: up ? null : () => _flip(i),
      child: Builder(
        builder: (cardContext) {
          _cardContexts[i] = cardContext;
          return AnimatedContainer(
            duration: reduceMotionOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: up ? cs.surfaceContainerHighest : cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onCursor
                    ? _color(cs, _turn.player)
                    : (owner != null ? _color(cs, owner) : cs.outline),
                width: onCursor ? 5 : (owner != null ? 3 : 1),
              ),
            ),
            child: InkWell(
              key: MemoryMatchIds.matchCard(i),
              borderRadius: BorderRadius.circular(16),
              onTap: up ? null : () => _flip(i),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: up
                          ? Text(
                              card.text,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                            )
                          : Icon(
                              Icons.help_outline,
                              color: cs.onPrimaryContainer,
                              size: 32,
                            ),
                    ),
                  ),
                  if (owner != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        _marker(owner),
                        size: 16,
                        color: _color(cs, owner),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _boardResult(ThemeData theme) {
    final w = _turn.winner;
    final text = w == 0 ? 'This board is a draw' : 'Player $w wins this board';
    return [
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        container: true,
        child: Text(
          text,
          key: MemoryMatchIds.matchBoardResult,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        key: MemoryMatchIds.matchNext,
        onPressed: _next,
        child: KeyedText(
          _match.over ? 'See results' : 'Next board',
          GameAction.action,
          alsoSpace: true,
        ),
      ),
    ];
  }

  Widget _final(BuildContext context) {
    final theme = Theme.of(context);
    final w = _match.winner;
    final headline = w == 0 ? 'A draw!' : 'Player $w wins!';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              container: true,
              child: Text(
                headline,
                key: MemoryMatchIds.matchWinner,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Player 1: ${_match.boardsWonBy(1)} boards, ${_match.pairsBy(1)} pairs',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Player 2: ${_match.boardsWonBy(2)} boards, ${_match.pairsBy(2)} pairs',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: MemoryMatchIds.matchAgain,
              onPressed: _playAgain,
              child: KeyedText(
                'Play again',
                GameAction.action,
                alsoSpace: true,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: MemoryMatchIds.matchDone,
              onPressed: widget.onExit,
              child: Text(withKey('Leave', 'Esc / L')),
            ),
          ],
        ),
      ),
    );
  }
}
