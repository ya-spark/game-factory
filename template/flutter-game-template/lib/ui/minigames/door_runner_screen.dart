import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// Door runner: free, Game mode only, plays multiple-choice items.
/// [harder] is for Champion (older level, tighter settings).
MiniGame doorRunnerGameFor({bool harder = false}) => MiniGame(
  id: doorRunnerId,
  title: 'Door runner',
  itemTypes: const {ItemType.mcq},
  minPool: 4,
  modes: const {MiniGameMode.game},
  build: (ctx) => DoorRunnerScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
  ),
);

final MiniGame doorRunnerGame = doorRunnerGameFor();

class DoorRunnerScreen extends StatelessWidget {
  const DoorRunnerScreen({
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
    final st = DoorRunnerSettings.forLevel(level);
    return ChoiceGameScreen(
      gameId: doorRunnerId,
      title: 'Door runner',
      howTo: level.older
          ? 'Run to the door with the right answer. Answer quickly to build a streak.'
          : 'Run to the door with the right answer. If it is not that one, try another door.',
      session: session,
      level: level,
      secondsPerQuestion: st.secondsPerQuestion,
      retry: st.retry,
      random: random,
      onExit: onExit,
      onAnswered: onAnswered,
      onScore: onScore,
      layout: (p, r) {
        final doors = layoutDoors(p.item, st.doors, r);
        return doors == null
            ? null
            : [for (final d in doors) ChoiceOption(d.label, d.correct)];
      },
      fieldBuilder: (context, f) =>
          _DoorField(field: f, seconds: st.runSeconds),
    );
  }
}

class _DoorField extends StatefulWidget {
  const _DoorField({required this.field, required this.seconds});
  final ChoiceField field;
  final double seconds;

  @override
  State<_DoorField> createState() => _DoorFieldState();
}

class _DoorFieldState extends State<_DoorField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
  );
  int _q = -1;

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    if (_q != f.questionIndex) {
      _q = f.questionIndex;
      if (f.reduceMotion) {
        _run.value = 1;
      } else {
        _run.forward(from: 0);
      }
    }
    final pal = MiniGamePalette(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < f.options.length; i++)
                  Expanded(child: _door(pal, theme, f, i)),
              ],
            ),
          ),
        ),
        // The path and the runner: a friendly round shape running along to the doors.
        SizedBox(
          height: 72,
          child: AnimatedBuilder(
            animation: _run,
            builder: (_, _) => CustomPaint(
              painter: _RunnerPainter(
                _run.value,
                pal.primary,
                pal.accent,
                pal.border,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _door(MiniGamePalette pal, ThemeData theme, ChoiceField f, int i) {
    final o = f.options[i];
    final off = f.disabled.contains(i);
    final shownRight = f.revealed && o.correct;
    final fill = off ? pal.surface : (shownRight ? pal.success : pal.primary);
    final fg = off
        ? pal.text.withValues(alpha: 0.7)
        : (shownRight ? pal.bg : pal.onPrimary);
    final status = off
        ? 'not this door'
        : shownRight
        ? 'the right door'
        : '';
    return Padding(
      padding: const EdgeInsets.all(6),
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
          child: Container(
            constraints: const BoxConstraints(minHeight: 160, minWidth: 48),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: pal.border, width: shownRight ? 4 : 2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(48),
                bottom: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    o.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 24,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (shownRight)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Icon(Icons.check_circle, color: fg),
                  ),
                if (off)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Icon(Icons.block, color: fg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round, friendly runner (no figure or face) moving along a path.
class _RunnerPainter extends CustomPainter {
  _RunnerPainter(this.t, this.body, this.stripe, this.path);
  final double t;
  final Color body;
  final Color stripe;
  final Color path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 6),
      Offset(size.width, size.height - 6),
      Paint()
        ..color = path
        ..strokeWidth = 4,
    );
    final x = size.width * (0.1 + 0.8 * t);
    final bounce = t >= 1 ? 0.0 : sin(t * pi * 8).abs() * 8;
    final c = Offset(x, size.height - 30 - bounce);
    canvas.drawCircle(c, 20, Paint()..color = body);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 14),
      -0.8,
      1.6,
      false,
      Paint()
        ..color = stripe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(_RunnerPainter old) => old.t != t || old.body != body;
}
