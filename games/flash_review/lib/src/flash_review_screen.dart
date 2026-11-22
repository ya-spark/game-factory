import 'package:flutter/material.dart';

import 'package:game_core/game_core.dart';

import 'rules/flash_review_rules.dart';

/// Flash review: Study mode only, always free, no timer, no coins. The app builds the session
/// from the child's mistakes and due items (the revise list); any item type works.
final MiniGame flashReviewGame = MiniGame(
  id: flashReviewId,
  title: 'Flash review',
  itemTypes: ItemType.values.toSet(),
  minPool: 4,
  modes: const {MiniGameMode.study},
  build: (ctx) => FlashReviewScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
  ),
);

enum _Phase { intro, card, results }

/// Card flips: the front asks, the back shows the answer, the child says "I knew it" (the item
/// passes) or "Not yet" (it stays on the revise list). Nothing is timed or scored against them.
class FlashReviewScreen extends StatefulWidget {
  const FlashReviewScreen({
    super.key,
    required this.session,
    required this.onExit,
    this.onAnswered,
    this.reader,
  });
  final QuizSession session;
  final VoidCallback onExit;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final GameReadAloud? reader;

  @override
  State<FlashReviewScreen> createState() => _FlashReviewScreenState();
}

class _FlashReviewScreenState extends State<FlashReviewScreen> {
  static const String _g = flashReviewId;
  final FlashReviewRun _run = FlashReviewRun();
  _Phase _phase = _Phase.intro;
  bool _flipped = false;
  GameReadAloud? _reader;

  QuizSession get _s => widget.session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader);
  }

  @override
  void dispose() {
    _reader?.stop();
    super.dispose();
  }

  void _start() =>
      setState(() => _phase = _s.finished ? _Phase.results : _Phase.card);

  // ---- keyboard (docs/SPEC.md, Keyboard): Enter starts and flips, 1 or right = I knew it, 2 or left = Not yet,
  // Esc leaves ----

  void _onKey(GameInput i) {
    if (i.repeat) return;
    final a = i.action;
    if (a == GameAction.exit) {
      widget.onExit();
      return;
    }
    switch (_phase) {
      case _Phase.intro:
        if (_goesOn(a)) _start();
      case _Phase.card:
        if (!_flipped) {
          if (_goesOn(a)) setState(() => _flipped = true);
        } else if (a == GameAction.pick1 || a == GameAction.right) {
          _mark(true);
        } else if (a == GameAction.pick2 || a == GameAction.left) {
          _mark(false);
        }
      case _Phase.results:
        if (_goesOn(a)) widget.onExit();
    }
  }

  /// Enter or Space (the shared pause key; this game has no pause) starts, flips and leaves.
  bool _goesOn(GameAction a) => a == GameAction.action || a == GameAction.pause;

  List<GameAction> get _hints => switch (_phase) {
    _Phase.card when _flipped => const [
      GameAction.pick1,
      GameAction.pick2,
      GameAction.exit,
    ],
    _ => const [GameAction.action, GameAction.exit],
  };

  void _mark(bool knew) {
    _reader?.stop();
    final r = _s.answer(correct: knew);
    // No coins in this game: the callback sees the answer without them.
    widget.onAnswered?.call(
      AnswerResult(
        correct: r.correct,
        firstPass: r.firstPass,
        stars: r.stars,
        coins: 0,
        topicCompleted: r.topicCompleted,
        explanation: r.explanation,
      ),
      _s,
    );
    setState(() {
      _run.mark(knew: knew);
      _flipped = false;
      if (_s.finished) _phase = _Phase.results;
    });
  }

  Widget _banner(GameBannerSlot slot) => KeyedSubtree(
    key: GameIds.mgBanner(_g),
    child: GameHostScope.of(context).banner(context, slot),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: GameIds.mgScreen(_g),
      appBar: AppBar(
        title: const Text('Flash review'),
        leading: IconButton(
          key: GameIds.mgExit(_g),
          tooltip: 'Leave Flash review',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: KeyedBody(
          onInput: _onKey,
          hints: _hints,
          spaceGoesOn: _phase != _Phase.card || !_flipped,
          words: const {
            GameAction.pick1: 'knew it / not yet',
            GameAction.action: 'go',
          },
          child: switch (_phase) {
            _Phase.intro => _intro(context),
            _Phase.card => _card(context),
            _Phase.results => _results(context),
          },
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgIntro(_g),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Flash review',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Look at the card, think, then flip it. Tap "I knew it" or "Not yet". '
                    'There is no timer, so take your time.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: GameIds.mgStart(_g),
                    onPressed: _start,
                    child: const Text('Start'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(GameBannerSlot.preGame),
      ],
    );
  }

  Widget _card(BuildContext context) {
    final p = _s.current;
    if (p == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final pal = MiniGamePalette(context);
    final front = flashPrompt(p.item);
    final back = flashAnswer(p.item);
    final shown = _flipped ? back : front;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Card ${_s.index + 1} of ${_s.total}',
                  key: GameIds.mgProgress(_g),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (_reader != null)
                IconButton(
                  key: GameIds.mgSpeak(_g),
                  tooltip: 'Read the card aloud',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _reader!.read(
                    shown,
                    audioRef: _flipped ? null : p.item.audio,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: _flipped ? 'Answer. $back' : 'Question. $front',
              child: ExcludeSemantics(
                child: Card(
                  key: GameIds.mgCard(_g),
                  color: _flipped ? pal.surface : pal.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _flipped ? 'Answer' : 'Question',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _flipped ? pal.text : pal.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            shown,
                            key: GameIds.mgPrompt(_g),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: _flipped ? pal.text : pal.onPrimary,
                            ),
                          ),
                          if (_flipped && p.item.explanation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              p.item.explanation,
                              key: GameIds.mgFeedback(_g),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: pal.text,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _flipped
              ? Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: GameIds.mgKnew(_g),
                      onPressed: () => _mark(true),
                      child: const Text('I knew it'),
                    ),
                    OutlinedButton(
                      key: GameIds.mgNotYet(_g),
                      onPressed: () => _mark(false),
                      child: const Text('Not yet'),
                    ),
                  ],
                )
              : FilledButton(
                  key: GameIds.mgFlip(_g),
                  onPressed: () => setState(() => _flipped = true),
                  child: const Text('Flip the card'),
                ),
        ),
      ],
    );
  }

  Widget _results(BuildContext context) {
    final theme = Theme.of(context);
    final r = _run;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgResults(_g),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    container: true,
                    label:
                        'Review finished. You knew ${r.known} of ${r.total}. '
                        '${r.notYet} will come back for another look.',
                    child: Text(
                      'You knew ${r.known} of ${r.total}',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (r.notYet > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${r.notYet} will come back for another look.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: GameIds.mgDone(_g),
                    onPressed: widget.onExit,
                    child: const Text('Done'),
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
