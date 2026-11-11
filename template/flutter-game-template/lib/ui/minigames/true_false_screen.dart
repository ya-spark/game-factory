import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// True or false: free with ads, Game and Study mode, plays `mcq` items. Choice 0 is True,
/// choice 1 is False. [harder] is for Champion.
MiniGame trueFalseGameFor({bool harder = false}) => MiniGame(
  id: trueFalseId,
  title: 'True or false',
  itemTypes: const {ItemType.mcq},
  minPool: 4,
  build: (ctx) => TrueFalseScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
  ),
);

final MiniGame trueFalseGame = trueFalseGameFor();

class TrueFalseScreen extends StatefulWidget {
  const TrueFalseScreen({
    super.key,
    required this.session,
    required this.onExit,
    required this.level,
    this.onAnswered,
    this.onScore,
    this.random,
  });
  final QuizSession session;
  final VoidCallback onExit;
  final MiniGameLevel level;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;

  @override
  State<TrueFalseScreen> createState() => _TrueFalseScreenState();
}

class _TrueFalseScreenState extends State<TrueFalseScreen> {
  final Map<String, Statement> _statements = {};

  @override
  Widget build(BuildContext context) {
    final older = widget.level.older;
    final st = TrueFalseSettings.forLevel(widget.level);
    return ChoiceGameScreen(
      gameId: trueFalseId,
      title: 'True or false',
      howTo: older
          ? 'Read the statement and tap True or False. Quick answers keep your streak going.'
          : 'Read the statement and tap True or False. If it is not that one, try the other.',
      session: widget.session,
      level: widget.level,
      secondsPerQuestion: st.secondsPerQuestion,
      retry: !older,
      random: widget.random,
      onExit: widget.onExit,
      onAnswered: widget.onAnswered,
      onScore: widget.onScore,
      promptOf: (p) => _statements[p.id]?.text ?? mcqPrompt(p.item),
      layout: (p, r) {
        final s = buildStatement(p.item, r);
        if (s == null) return null;
        _statements[p.id] = s;
        return [
          ChoiceOption('True', s.isTrue),
          ChoiceOption('False', !s.isTrue),
        ];
      },
      fieldBuilder: (context, f) => _TrueFalseField(field: f),
    );
  }
}

class _TrueFalseField extends StatelessWidget {
  const _TrueFalseField({required this.field});
  final ChoiceField field;

  @override
  Widget build(BuildContext context) {
    final pal = MiniGamePalette(context);
    return LayoutBuilder(
      builder: (context, box) {
        final children = [
          for (var i = 0; i < field.options.length; i++)
            _button(context, pal, i),
        ];
        // Side by side when there is room; stacked at large text so nothing overflows.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = box.maxWidth < 360 || scale > 1.3;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: stacked
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final c in children)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: c,
                        ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    for (final c in children)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: c,
                        ),
                      ),
                  ],
                ),
        );
      },
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
        : i == 0
        ? (pal.primary, pal.onPrimary)
        : (pal.accent, pal.onAccent);
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
            constraints: const BoxConstraints(minHeight: 88),
            child: Center(
              child: Text(
                o.label,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
