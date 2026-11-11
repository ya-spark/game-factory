import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// Equation builder: free with ads, Game and Study mode, plays `numeric` items whose answer is
/// a whole number. The child builds any expression from the tiles that equals the target.
/// [harder] is for Champion.
MiniGame equationBuilderGameFor({bool harder = false}) => MiniGame(
  id: equationBuilderId,
  title: 'Equation builder',
  itemTypes: const {ItemType.numeric},
  minPool: 4,
  build: (ctx) => EquationBuilderScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
    study: ctx.mode == MiniGameMode.study,
  ),
);

final MiniGame equationBuilderGame = equationBuilderGameFor();

class EquationBuilderScreen extends StatefulWidget {
  const EquationBuilderScreen({
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
  State<EquationBuilderScreen> createState() => _EquationBuilderScreenState();
}

class _EquationBuilderScreenState extends State<EquationBuilderScreen> {
  final Map<String, EquationPuzzle> _puzzles = {};

  @override
  Widget build(BuildContext context) {
    final st = EquationSettings.forLevel(widget.level);
    final gentle = !widget.level.older || widget.study;
    return ChoiceGameScreen(
      gameId: equationBuilderId,
      title: 'Equation builder',
      howTo:
          'Tap number and sign tiles to build a sum that makes the target. '
          'Any sum that works is right, and you do not need every tile.',
      session: widget.session,
      level: widget.level,
      secondsPerQuestion: widget.study ? 0 : st.secondsPerQuestion,
      retry: gentle,
      random: widget.random,
      onExit: widget.onExit,
      onAnswered: widget.onAnswered,
      onScore: widget.onScore,
      promptOf: (p) {
        final t = equationTarget(p.item);
        return t == null
            ? 'Build the target'
            : 'Make $t with the tiles. You can use some or all of them.';
      },
      layout: (p, r) {
        final puzzle = buildEquation(p.item, st, r);
        if (puzzle == null) return null;
        _puzzles[p.id] = puzzle;
        return [
          ChoiceOption(puzzle.solutionText, true),
          const ChoiceOption('Not yet', false),
        ];
      },
      fieldBuilder: (context, f) {
        final id = widget.session.items[f.questionIndex].id;
        return _EquationField(
          key: ValueKey('eq.${f.questionIndex}'),
          field: f,
          puzzle: _puzzles[id]!,
        );
      },
    );
  }
}

class _EquationField extends StatefulWidget {
  const _EquationField({super.key, required this.field, required this.puzzle});
  final ChoiceField field;
  final EquationPuzzle puzzle;

  @override
  State<_EquationField> createState() => _EquationFieldState();
}

class _EquationFieldState extends State<_EquationField> {
  /// Indexes into the puzzle tiles, in the order the child tapped them.
  final List<int> _chosen = [];
  String _hint = '';

  List<String> get _tokens => [for (final i in _chosen) widget.puzzle.tiles[i]];

  void _tap(int i) {
    if (widget.field.answered) return;
    setState(() {
      _chosen.contains(i) ? _chosen.remove(i) : _chosen.add(i);
      _hint = '';
    });
  }

  void _check() {
    final f = widget.field;
    if (f.answered) return;
    if (equationHitsTarget(_tokens, widget.puzzle.target)) {
      f.onPick(0);
    } else if (!f.disabled.contains(1)) {
      f.onPick(1);
    } else {
      setState(() => _hint = 'Not yet. Change a tile and check again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final pal = MiniGamePalette(context);
    final theme = Theme.of(context);
    final tokens = _tokens;
    final value = evaluateTokens(tokens);
    final live = value == null
        ? ''
        : '= ${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(2)}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            label: tokens.isEmpty
                ? 'Your sum is empty'
                : 'Your sum: ${tokens.map(spokenTile).join(' ')} $live',
            child: Container(
              key: TestIds.mgSlot(f.gameId, 0),
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border.all(color: pal.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExcludeSemantics(
                child: Text(
                  tokens.isEmpty
                      ? 'Tap tiles to build your sum'
                      : '${tokens.join(' ')} $live',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: pal.text,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: TestIds.mgClear(f.gameId),
                  onPressed: f.answered || _chosen.isEmpty
                      ? null
                      : () => setState(_chosen.clear),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: TestIds.mgCheck(f.gameId),
                  onPressed: f.answered || tokens.isEmpty ? null : _check,
                  child: const Text('Check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < widget.puzzle.tiles.length; i++)
                _tile(pal, i),
            ],
          ),
          const SizedBox(height: 16),
          if (_hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(_hint, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(MiniGamePalette pal, int i) {
    final t = widget.puzzle.tiles[i];
    final used = _chosen.contains(i);
    final op = isOperator(t);
    final fill = used ? pal.surface : (op ? pal.accent : pal.primary);
    final fg = used
        ? pal.text.withValues(alpha: 0.7)
        : (op ? pal.onAccent : pal.onPrimary);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${spokenTile(t)}${used ? ', in your sum' : ''}',
      onTap: () => _tap(i),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: pal.border),
        ),
        child: InkWell(
          key: TestIds.mgTile(widget.field.gameId, i),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _tap(i),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  t,
                  style: Theme.of(context).textTheme.headlineSmall
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
