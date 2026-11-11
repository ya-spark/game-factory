import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services.dart';
import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart' show MiniGamePalette;
import 'minigame_parts.dart';

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
    this.recordedClip,
  });
  final QuizSession session;
  final VoidCallback onExit;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final ReadAloud? reader;
  final RecordedClipPlayer? recordedClip;

  @override
  State<FlashReviewScreen> createState() => _FlashReviewScreenState();
}

class _FlashReviewScreenState extends State<FlashReviewScreen> {
  static const String _g = flashReviewId;
  final FlashReviewRun _run = FlashReviewRun();
  _Phase _phase = _Phase.intro;
  bool _flipped = false;
  ReadAloud? _reader;

  QuizSession get _s => widget.session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader, widget.recordedClip);
  }

  @override
  void dispose() {
    _reader?.stop();
    super.dispose();
  }

  void _start() =>
      setState(() => _phase = _s.finished ? _Phase.results : _Phase.card);

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

  Widget _banner(AdPlacement placement) {
    final s = context
        .dependOnInheritedWidgetOfExactType<ServicesScope>()
        ?.services;
    if (s == null) return const SizedBox.shrink();
    return KeyedSubtree(
      key: TestIds.mgBanner(_g),
      child: s.ads.buildBanner(placement),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TestIds.mgScreen(_g),
      appBar: AppBar(
        title: const Text('Flash review'),
        leading: IconButton(
          key: TestIds.mgExit(_g),
          tooltip: 'Leave Flash review',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.card => _card(context),
          _Phase.results => _results(context),
        },
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
              key: TestIds.mgIntro(_g),
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
                    key: TestIds.mgStart(_g),
                    onPressed: _start,
                    child: const Text('Start'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(AdPlacement.preGame),
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
                  key: TestIds.mgProgress(_g),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (_reader != null)
                IconButton(
                  key: TestIds.mgSpeak(_g),
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
                  key: TestIds.mgCard(_g),
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
                            key: TestIds.mgPrompt(_g),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: _flipped ? pal.text : pal.onPrimary,
                            ),
                          ),
                          if (_flipped && p.item.explanation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              p.item.explanation,
                              key: TestIds.mgFeedback(_g),
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
                      key: TestIds.mgKnew(_g),
                      onPressed: () => _mark(true),
                      child: const Text('I knew it'),
                    ),
                    OutlinedButton(
                      key: TestIds.mgNotYet(_g),
                      onPressed: () => _mark(false),
                      child: const Text('Not yet'),
                    ),
                  ],
                )
              : FilledButton(
                  key: TestIds.mgFlip(_g),
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
              key: TestIds.mgResults(_g),
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
                    key: TestIds.mgDone(_g),
                    onPressed: widget.onExit,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(AdPlacement.postGame),
      ],
    );
  }
}
