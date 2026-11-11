import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// Balloon pop: free, Game mode only, plays multiple-choice and numeric items.
/// [harder] is for Champion (older level, tighter settings).
MiniGame balloonPopGameFor({bool harder = false}) => MiniGame(
  id: balloonPopId,
  title: 'Balloon pop',
  itemTypes: const {ItemType.mcq, ItemType.numeric},
  minPool: 4,
  modes: const {MiniGameMode.game},
  build: (ctx) => BalloonPopScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
  ),
);

final MiniGame balloonPopGame = balloonPopGameFor();

class BalloonPopScreen extends StatelessWidget {
  const BalloonPopScreen({
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
  Widget build(BuildContext context) {
    final st = BalloonPopSettings.forLevel(level);
    return ChoiceGameScreen(
      gameId: balloonPopId,
      title: 'Balloon pop',
      howTo: level.older
          ? 'Pop the balloon with the right answer before time runs out.'
          : 'Pop the balloon with the right answer. If it is not that one, try another.',
      session: session,
      level: level,
      secondsPerQuestion: st.secondsPerQuestion,
      retry: !level.older,
      random: random,
      onExit: onExit,
      onAnswered: onAnswered,
      onScore: onScore,
      layout: (p, r) {
        final b = layoutBalloons(p.item, st.balloons, r);
        return b == null
            ? null
            : [for (final x in b) ChoiceOption(x.label, x.correct)];
      },
      fieldBuilder: (context, f) =>
          _BalloonField(field: f, riseSeconds: st.riseSeconds, large: st.large),
    );
  }
}

class _BalloonField extends StatefulWidget {
  const _BalloonField({
    required this.field,
    required this.riseSeconds,
    required this.large,
  });
  final ChoiceField field;
  final double riseSeconds;
  final bool large;

  @override
  State<_BalloonField> createState() => _BalloonFieldState();
}

class _BalloonFieldState extends State<_BalloonField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.riseSeconds * 1000).round()),
  );
  bool _running = false;

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    // Balloons float while a question is open; with reduced motion, or once answered, they rest.
    final move = !f.reduceMotion && !f.answered;
    if (move && !_running) {
      _running = true;
      _rise.repeat();
    } else if (!move && _running) {
      _running = false;
      _rise.stop();
    }
    final pal = MiniGamePalette(context);
    final theme = Theme.of(context);
    final n = f.options.length;
    return LayoutBuilder(
      builder: (context, box) {
        final base = widget.large ? 104.0 : 80.0;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final d = min(base * max(1.0, scale * 0.85), box.maxWidth / n * 1.4);
        final h = d * 1.25;
        final travel = max(0.0, box.maxHeight - h);
        return AnimatedBuilder(
          animation: _rise,
          builder: (_, _) {
            final t = move ? _rise.value : 0.5;
            return Stack(
              children: [
                for (var i = 0; i < n; i++)
                  _balloon(pal, theme, f, i, n, d, h, travel, t, box.maxWidth),
              ],
            );
          },
        );
      },
    );
  }

  Widget _balloon(
    MiniGamePalette pal,
    ThemeData theme,
    ChoiceField f,
    int i,
    int n,
    double d,
    double h,
    double travel,
    double t,
    double width,
  ) {
    final o = f.options[i];
    final off = f.disabled.contains(i);
    final shownRight = f.revealed && o.correct;
    final popped = f.answered && !o.correct;
    // Resting balloons sit at staggered heights.
    final height = f.reduceMotion || f.answered
        ? (i.isEven ? 0.3 : 0.6)
        : balloonHeight(i, n, t);
    final colors = [(pal.primary, pal.onPrimary), (pal.accent, pal.onAccent)];
    final (fill, fg) = off
        ? (pal.surface, pal.text.withValues(alpha: 0.7))
        : shownRight
        ? (pal.success, pal.bg)
        : colors[i % 2];
    final left = (balloonLane(i, n) * width - d / 2)
        .clamp(0.0, max(0.0, width - d))
        .toDouble();
    final status = off
        ? 'popped, not this one'
        : shownRight
        ? 'the right balloon'
        : popped
        ? 'floated away'
        : '';
    return Positioned(
      left: left,
      bottom: travel * height,
      width: d,
      height: h,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        enabled: !off && !f.answered,
        label: status.isEmpty ? o.label : '${o.label}, $status',
        onTap: off || f.answered ? null : () => f.onPick(i),
        child: GestureDetector(
          key: TestIds.mgChoice(f.gameId, i),
          behavior: HitTestBehavior.opaque,
          onTap: off || f.answered ? null : () => f.onPick(i),
          child: Opacity(
            opacity: popped ? 0.35 : 1,
            child: CustomPaint(
              painter: _BalloonPainter(fill, pal.border, shownRight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: h * 0.12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      o.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

/// A balloon drawn in code: an oval, a small knot and a string. No figures.
class _BalloonPainter extends CustomPainter {
  _BalloonPainter(this.fill, this.edge, this.mark);
  final Color fill;
  final Color edge;
  final bool mark;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width, size.height * 0.82);
    canvas.drawOval(body, Paint()..color = fill);
    canvas.drawOval(
      body,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = mark ? 4 : 2,
    );
    final knot = Path()
      ..moveTo(size.width / 2, size.height * 0.82)
      ..lineTo(size.width / 2 - 6, size.height * 0.88)
      ..lineTo(size.width / 2 + 6, size.height * 0.88)
      ..close();
    canvas.drawPath(knot, Paint()..color = fill);
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.88),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = edge
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BalloonPainter o) =>
      o.fill != fill || o.edge != edge || o.mark != mark;
}
