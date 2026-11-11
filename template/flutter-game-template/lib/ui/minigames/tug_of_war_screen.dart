import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// Tug-of-war quiz: coin-locked (200 coins) in the Craft apps, Game mode only, plays `mcq`
/// items. [harder] is for Champion.
MiniGame tugOfWarGameFor({bool harder = false}) => MiniGame(
  id: tugOfWarId,
  title: 'Tug of war',
  itemTypes: const {ItemType.mcq},
  minPool: 4,
  modes: const {MiniGameMode.game},
  access: GameAccess.coins,
  coinPrice: tugOfWarCoinPrice,
  build: (ctx) => TugOfWarScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
  ),
);

final MiniGame tugOfWarGame = tugOfWarGameFor();

class TugOfWarScreen extends StatefulWidget {
  const TugOfWarScreen({
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
  State<TugOfWarScreen> createState() => _TugOfWarScreenState();
}

class _TugOfWarScreenState extends State<TugOfWarScreen> {
  late final TugOfWarRun _run = TugOfWarRun(widget.level);

  void _answered(AnswerResult r, QuizSession s) {
    // Younger: the child keeps trying until right, so the rope only ever moves their way.
    setState(() => _run.answer(correct: widget.level.older ? r.correct : true));
    widget.onAnswered?.call(r, s);
  }

  @override
  Widget build(BuildContext context) {
    final st = _run.settings;
    final older = widget.level.older;
    return ChoiceGameScreen(
      gameId: tugOfWarId,
      title: 'Tug of war',
      howTo: older
          ? 'Answer right to pull the rope to your side. A wrong or slow answer lets it slip back. '
                'Get it to your end to win a round.'
          : 'Answer right to pull the rope to your side. If it is not that one, try another.',
      session: widget.session,
      level: widget.level,
      secondsPerQuestion: st.secondsPerQuestion,
      retry: !older,
      random: widget.random,
      onExit: widget.onExit,
      onAnswered: _answered,
      onScore: (score) => widget.onScore?.call(score),
      layout: (p, r) {
        final o = layoutTugOptions(p.item, st.options, r);
        return o == null
            ? null
            : [for (final x in o) ChoiceOption(x.label, x.correct)];
      },
      fieldBuilder: (context, f) => _TugField(field: f, run: _run),
    );
  }
}

class _TugField extends StatelessWidget {
  const _TugField({required this.field, required this.run});
  final ChoiceField field;
  final TugOfWarRun run;

  String get _status {
    final reach = run.settings.reach;
    final p = run.position;
    final where = p == 0
        ? 'in the middle'
        : p > 0
        ? '$p of $reach steps toward you'
        : '${-p} of $reach steps toward the quiz';
    return 'Rope $where. Rounds won ${run.roundsWon}, lost ${run.roundsLost}.';
  }

  @override
  Widget build(BuildContext context) {
    final pal = MiniGamePalette(context);
    final theme = Theme.of(context);
    final f = field;
    final end = run.lastEnd;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Semantics(
            container: true,
            label: _status,
            child: ExcludeSemantics(
              child: SizedBox(
                key: TestIds.mgRope(f.gameId),
                height: 64,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RopePainter(
                    position: run.position,
                    reach: run.settings.reach,
                    me: pal.primary,
                    them: pal.accent,
                    rope: pal.text,
                    marker: pal.success,
                    edge: pal.border,
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Won ${run.roundsWon}  ·  Lost ${run.roundsLost}',
            style: theme.textTheme.labelLarge,
          ),
          if (end != TugRoundEnd.none && f.answered)
            Semantics(
              liveRegion: true,
              child: Text(
                end == TugRoundEnd.won
                    ? 'You pulled it all the way. Round won!'
                    : 'The rope slipped to the other end. New round!',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < f.options.length; i++) _option(context, pal, i),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, MiniGamePalette pal, int i) {
    final f = field;
    final o = f.options[i];
    final off = f.disabled.contains(i);
    final shownRight = f.revealed && o.correct;
    final (fill, fg) = off
        ? (pal.surface, pal.text.withValues(alpha: 0.7))
        : shownRight
        ? (pal.success, pal.bg)
        : (pal.primary, pal.onPrimary);
    final status = off
        ? 'not this one'
        : shownRight
        ? 'the right answer'
        : '';
    final enabled = !off && !f.answered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        enabled: enabled,
        label: status.isEmpty ? o.label : '${o.label}, $status',
        onTap: enabled ? () => f.onPick(i) : null,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: pal.border, width: shownRight ? 3 : 1),
          ),
          child: InkWell(
            key: TestIds.mgChoice(f.gameId, i),
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => f.onPick(i) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    o.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two shapes at the ends, a rope between them and a marker on it. Shapes only, no figures.
class _RopePainter extends CustomPainter {
  _RopePainter({
    required this.position,
    required this.reach,
    required this.me,
    required this.them,
    required this.rope,
    required this.marker,
    required this.edge,
  });
  final int position;
  final int reach;
  final Color me;
  final Color them;
  final Color rope;
  final Color marker;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const end = 22.0;
    final left = end * 2;
    final right = size.width - end * 2;
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = rope
        ..strokeWidth = 4,
    );
    // The quiz's end on the left (a square), the child's end on the right (a circle).
    final box = Rect.fromCenter(
      center: Offset(end, y),
      width: end * 1.6,
      height: end * 1.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
      Paint()..color = them,
    );
    canvas.drawCircle(
      Offset(size.width - end, y),
      end * 0.9,
      Paint()..color = me,
    );
    // Tick marks for each step, the middle one taller.
    for (var k = -reach; k <= reach; k++) {
      final x = left + (right - left) * (k + reach) / (2 * reach);
      canvas.drawLine(
        Offset(x, y - (k == 0 ? 14 : 8)),
        Offset(x, y + (k == 0 ? 14 : 8)),
        Paint()
          ..color = edge
          ..strokeWidth = 2,
      );
    }
    final mx = left + (right - left) * (position + reach) / (2 * reach);
    canvas.drawCircle(Offset(mx, y), 13, Paint()..color = marker);
    canvas.drawCircle(
      Offset(mx, y),
      13,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RopePainter o) =>
      o.position != position ||
      o.reach != reach ||
      o.me != me ||
      o.them != them;
}
