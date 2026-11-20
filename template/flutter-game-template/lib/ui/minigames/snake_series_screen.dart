import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import 'choice_game.dart';

/// Snake for series: eat the items in the right order. Plays short `series`, `word` and `numeric`
/// items. Game mode only. Eating the wrong item costs a life (older level) but never ends the
/// run for steering; the younger level never fails.
MiniGame snakeSeriesGameFor({bool harder = false}) => MiniGame(
  id: snakeSeriesId,
  title: 'Snake',
  itemTypes: const {ItemType.series, ItemType.word, ItemType.numeric},
  sizes: SizeAccept.shortOnly,
  accepts: (p) => snakePlaysItem(p.item),
  minPool: 3,
  modes: const {MiniGameMode.game},
  build: (ctx) => SnakeSeriesScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
  ),
);

final MiniGame snakeSeriesGame = snakeSeriesGameFor();

/// Done and not-done, as the shared choice screen knows them.
const List<ChoiceOption> _outcome = [
  ChoiceOption('Done', true),
  ChoiceOption('Not this time', false),
];

class SnakeSeriesScreen extends StatelessWidget {
  const SnakeSeriesScreen({
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
    final st = SnakeSettings.forLevel(level);
    return ChoiceGameScreen(
      gameId: snakeSeriesId,
      title: 'Snake',
      howTo: level.older
          ? 'Steer the snake to eat the items in the right order. A wrong item costs a life.'
          : 'Steer the snake to eat the items in the right order. Take your time.',
      session: session,
      level: level,
      secondsPerQuestion: 0,
      retry: false,
      random: random,
      onExit: onExit,
      onAnswered: onAnswered,
      onScore: onScore,
      promptOf: (p) => snakeTask(p.item)?.prompt ?? '',
      layout: (p, r) => snakeTask(p.item) == null ? null : _outcome,
      fieldBuilder: (context, f) => _SnakeField(
        key: ValueKey('snake.${f.questionIndex}'),
        field: f,
        settings: st,
        task: snakeTask(session.items[f.questionIndex].item)!,
        random: random,
      ),
    );
  }
}

class _SnakeField extends StatefulWidget {
  const _SnakeField({
    super.key,
    required this.field,
    required this.settings,
    required this.task,
    this.random,
  });
  final ChoiceField field;
  final SnakeSettings settings;
  final SnakeTask task;
  final Random? random;

  @override
  State<_SnakeField> createState() => _SnakeFieldState();
}

class _SnakeFieldState extends State<_SnakeField> {
  late final SnakeBoard _board = SnakeBoard(
    task: widget.task,
    settings: widget.settings,
    random: widget.random ?? Random(),
  );
  Timer? _tick;
  bool _reported = false;

  bool get _stepByTap => widget.field.reduceMotion;

  @override
  void initState() {
    super.initState();
    if (!_stepByTap) {
      _tick = Timer.periodic(
        Duration(milliseconds: widget.settings.tickMillis),
        (_) => _advance(),
      );
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _advance() {
    if (_reported || !mounted) return;
    final e = _board.step();
    setState(() {});
    if (e == SnakeEvent.done || e == SnakeEvent.lost) {
      _reported = true;
      _tick?.cancel();
      // Hand the result to the screen after this frame, so the last move is seen.
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) widget.field.onPick(e == SnakeEvent.done ? 0 : 1);
      });
    }
  }

  void _go(SnakeDir d) {
    if (_reported) return;
    _board.turn(d);
    if (_stepByTap) {
      _advance();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = MiniGamePalette(context);
    final theme = Theme.of(context);
    final lives = widget.settings.lives;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Eaten ${_board.eaten} of ${widget.task.labels.length}'
            '${lives > 0 ? '   Lives ${max(0, lives - _board.mistakes)}' : ''}',
            key: const Key('snake.status'),
            style: theme.textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanEnd: (d) {
              final v = d.velocity.pixelsPerSecond;
              if (v.dx.abs() > v.dy.abs()) {
                _go(v.dx > 0 ? SnakeDir.right : SnakeDir.left);
              } else {
                _go(v.dy > 0 ? SnakeDir.down : SnakeDir.up);
              }
            },
            child: CustomPaint(
              key: const Key('snake.board'),
              size: Size.infinite,
              painter: _BoardPainter(
                board: _board,
                pal: pal,
                textStyle: theme.textTheme.titleSmall!,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (d, icon, label) in const [
                (SnakeDir.left, Icons.arrow_back, 'left'),
                (SnakeDir.up, Icons.arrow_upward, 'up'),
                (SnakeDir.down, Icons.arrow_downward, 'down'),
                (SnakeDir.right, Icons.arrow_forward, 'right'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton.filledTonal(
                    key: Key('snake.dir.$label'),
                    tooltip: 'Steer $label',
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 52,
                    ),
                    onPressed: () => _go(d),
                    icon: Icon(icon),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.pal,
    required this.textStyle,
  }) : stamp = Object.hash(
         board.eaten,
         board.mistakes,
         Object.hashAll(board.body),
       );
  final SnakeBoard board;
  final MiniGamePalette pal;
  final TextStyle textStyle;
  final int stamp;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = board.settings.cols;
    final rows = board.settings.rows;
    final cell = min(size.width / cols, size.height / rows);
    final ox = (size.width - cell * cols) / 2;
    final oy = (size.height - cell * rows) / 2;
    final grid = Paint()..color = pal.border.withValues(alpha: 0.25);
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(
        Offset(ox + c * cell, oy),
        Offset(ox + c * cell, oy + rows * cell),
        grid,
      );
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(
        Offset(ox, oy + r * cell),
        Offset(ox + cols * cell, oy + r * cell),
        grid,
      );
    }
    Rect rect(Cell c) =>
        Rect.fromLTWH(ox + c.c * cell, oy + c.r * cell, cell, cell).deflate(2);
    for (final e in board.foods.entries) {
      final rr = RRect.fromRectAndRadius(
        rect(e.key),
        Radius.circular(cell * 0.2),
      );
      canvas.drawRRect(rr, Paint()..color = pal.accent);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = pal.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: e.value,
          style: textStyle.copyWith(
            color: pal.onAccent,
            fontWeight: FontWeight.bold,
            fontSize: cell * (e.value.length > 2 ? 0.3 : 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cell - 4);
      tp.paint(
        canvas,
        Offset(
          rect(e.key).left + (rect(e.key).width - tp.width) / 2,
          rect(e.key).top + (rect(e.key).height - tp.height) / 2,
        ),
      );
    }
    for (var i = board.body.length - 1; i >= 0; i--) {
      final rr = RRect.fromRectAndRadius(
        rect(board.body[i]),
        Radius.circular(cell * 0.3),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..color = i == 0 ? pal.primary : pal.primary.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.stamp != stamp || old.board != board;
}
