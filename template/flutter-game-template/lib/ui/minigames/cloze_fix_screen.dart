import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// Cloze and grammar fix: free with ads, Game and Study mode. Plays `cloze` items (choose the
/// word that fills the gap) and grammar `mcq` items (choose the corrected sentence).
/// [harder] is for Champion.
MiniGame clozeFixGameFor({bool harder = false}) => MiniGame(
  id: clozeFixId,
  title: 'Fill the gap',
  itemTypes: const {ItemType.cloze, ItemType.mcq},
  minPool: 4,
  build: (ctx) => ClozeFixScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
    study: ctx.mode == MiniGameMode.study,
  ),
);

final MiniGame clozeFixGame = clozeFixGameFor();

class ClozeFixScreen extends StatefulWidget {
  const ClozeFixScreen({
    super.key,
    required this.session,
    required this.onExit,
    required this.level,
    this.study = false,
    this.onAnswered,
    this.onScore,
    this.random,
  });
  final QuizSession session;
  final VoidCallback onExit;
  final MiniGameLevel level;

  /// Study mode: calm, no timer, wrong tries can be corrected.
  final bool study;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;

  @override
  State<ClozeFixScreen> createState() => _ClozeFixScreenState();
}

class _ClozeFixScreenState extends State<ClozeFixScreen> {
  final Map<String, ClozeQuestion> _questions = {};

  @override
  Widget build(BuildContext context) {
    final st = ClozeFixSettings.forLevel(widget.level);
    return ChoiceGameScreen(
      gameId: clozeFixId,
      title: 'Fill the gap',
      howTo:
          'Read the sentence, then tap the word that fits the gap. For a '
          'sentence with a mistake, tap the corrected version.',
      session: widget.session,
      level: widget.level,
      secondsPerQuestion: widget.study ? 0 : st.secondsPerQuestion,
      retry: !widget.level.older || widget.study,
      random: widget.random,
      onExit: widget.onExit,
      onAnswered: widget.onAnswered,
      onScore: widget.onScore,
      promptOf: (p) => _questions[p.id]?.text ?? '',
      layout: (p, r) {
        final q = buildCloze(p, widget.session.items, st, r);
        if (q == null) return null;
        _questions[p.id] = q;
        return [
          for (var i = 0; i < q.options.length; i++)
            ChoiceOption(q.options[i], q.correct.contains(i)),
        ];
      },
      fieldBuilder: (context, f) => _OptionList(field: f),
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.field});
  final ChoiceField field;

  @override
  Widget build(BuildContext context) {
    final pal = MiniGamePalette(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < field.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _button(context, pal, i),
            ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, MiniGamePalette pal, int i) {
    final f = field;
    final o = f.options[i];
    final off = f.disabled.contains(i);
    final shownRight = f.revealed && o.correct;
    final (fill, fg) = off
        ? (pal.surface, pal.text.withValues(alpha: 0.7))
        : shownRight
        ? (pal.success, pal.bg)
        : (pal.primary, pal.onPrimary);
    final enabled = !off && !f.answered;
    final status = off
        ? 'not this one'
        : shownRight
        ? 'the right answer'
        : '';
    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: enabled,
      label: status.isEmpty ? o.label : '${o.label}, $status',
      onTap: enabled ? () => f.onPick(i) : null,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pal.border, width: shownRight ? 3 : 1),
        ),
        child: InkWell(
          key: TestIds.mgChoice(f.gameId, i),
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => f.onPick(i) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  o.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: fg, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
