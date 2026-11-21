import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';

/// Shooter: shoot the right answer. Plays short `mcq` and `category` items (the targets are
/// small, so long text is left to the card games). Game mode only.
/// [harder] is for Champion (older level, tighter settings).
MiniGame shooterGameFor({bool harder = false}) => MiniGame(
  id: shooterId,
  title: 'Shooter',
  itemTypes: const {ItemType.mcq, ItemType.category},
  sizes: SizeAccept.shortOnly,
  accepts: (p) => shooterPlaysItem(p.item),
  minPool: 4,
  modes: const {MiniGameMode.game},
  build: (ctx) => ShooterScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
  ),
);

final MiniGame shooterGame = shooterGameFor();

class ShooterScreen extends StatelessWidget {
  const ShooterScreen({
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
    final st = ShooterSettings.forLevel(level);
    return ChoiceGameScreen(
      gameId: shooterId,
      title: 'Shooter',
      howTo: level.older
          ? 'Shoot the target with the right answer before time runs out.'
          : 'Shoot the target with the right answer. If it is not that one, try another.',
      session: session,
      level: level,
      secondsPerQuestion: st.secondsPerQuestion,
      retry: !level.older,
      random: random,
      onExit: onExit,
      onAnswered: onAnswered,
      onScore: onScore,
      promptOf: (p) => shooterPrompt(p.item),
      layout: (p, r) {
        final t = layoutTargets(p.item, st.maxTargets, r);
        return t == null
            ? null
            : [for (final x in t) ChoiceOption(x.label, x.correct)];
      },
      fieldBuilder: (context, f) =>
          _Gallery(field: f, swaySeconds: st.swaySeconds, large: st.large),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.field,
    required this.swaySeconds,
    required this.large,
  });
  final ChoiceField field;
  final double swaySeconds;
  final bool large;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> with TickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.swaySeconds * 1000).round()),
  );
  late final AnimationController _shot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  bool _swaying = false;
  int? _aim;

  /// The target with keyboard focus (Tab), for the focus ring.
  int? _focused;

  /// 0 for the keys 1 and numpad 1, up to 8 for 9; null for any other key.
  static int? _digit(LogicalKeyboardKey k) {
    const rows = [
      [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
      [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
      [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
      [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
      [LogicalKeyboardKey.digit5, LogicalKeyboardKey.numpad5],
    ];
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].contains(k)) return i;
    }
    return null;
  }

  @override
  void dispose() {
    _sway.dispose();
    _shot.dispose();
    super.dispose();
  }

  void _fire(int i) {
    final f = widget.field;
    if (_aim != null || f.answered || f.disabled.contains(i)) return;
    if (f.reduceMotion) return f.onPick(i);
    setState(() => _aim = i);
    _shot.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _aim = null);
      f.onPick(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final move = !f.reduceMotion && !f.answered;
    if (move && !_swaying) {
      _swaying = true;
      _sway.repeat(reverse: true);
    } else if (!move && _swaying) {
      _swaying = false;
      _sway.stop();
    }
    final pal = MiniGamePalette(context);
    final theme = Theme.of(context);
    final n = f.options.length;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final i = _digit(event.logicalKey);
        if (i == null || i >= n) return KeyEventResult.ignored;
        _fire(i);
        return KeyEventResult.handled;
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final w = min(
            (widget.large ? 128.0 : 104.0) * max(1.0, scale * 0.85),
            box.maxWidth * 0.46,
          );
          final h = w * 0.62;
          final cannonY = box.maxHeight - 46;
          final rows = (n / 2).ceil();
          final gap = max(h * 0.4, 12.0);
          double targetX(int i, double sway) {
            final inRow = i % 2 == 0 ? 0 : 1;
            final rowCount = min(2, n - (i ~/ 2) * 2);
            final lane = rowCount == 1 ? 0.5 : (inRow == 0 ? 0.28 : 0.72);
            final drift = f.reduceMotion || f.answered
                ? 0.0
                : (sway - 0.5) * box.maxWidth * 0.12 * (i.isEven ? 1 : -1);
            return (lane * box.maxWidth - w / 2 + drift)
                .clamp(0.0, max(0.0, box.maxWidth - w))
                .toDouble();
          }

          double targetY(int i) => 8 + (i ~/ 2) * (h + gap);

          return AnimatedBuilder(
            animation: Listenable.merge([_sway, _shot]),
            builder: (_, _) {
              final sway = _sway.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: targetX(i, sway),
                      top: min(targetY(i), max(0.0, cannonY - h - 12)),
                      width: w,
                      height: h,
                      child: _target(pal, theme, f, i),
                    ),
                  if (_aim != null)
                    Positioned(
                      left:
                          box.maxWidth / 2 -
                          6 +
                          (targetX(_aim!, sway) + w / 2 - box.maxWidth / 2) *
                              _shot.value,
                      top:
                          cannonY -
                          (cannonY -
                                  (min(targetY(_aim!), cannonY - h - 12) +
                                      h / 2)) *
                              _shot.value,
                      child: Container(
                        key: const Key('shooter.shot'),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pal.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Positioned(
                    left: box.maxWidth / 2 - 22,
                    top: cannonY,
                    width: 44,
                    height: 40,
                    child: CustomPaint(
                      key: const Key('shooter.cannon'),
                      painter: _CannonPainter(pal.primary, pal.border),
                    ),
                  ),
                  if (rows == 0) const SizedBox.shrink(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _target(MiniGamePalette pal, ThemeData theme, ChoiceField f, int i) {
    final o = f.options[i];
    final off = f.disabled.contains(i);
    final shownRight = f.revealed && o.correct;
    final hit = f.answered && !o.correct;
    final (fill, fg) = off
        ? (pal.surface, pal.text.withValues(alpha: 0.7))
        : shownRight
        ? (pal.success, pal.bg)
        : (i.isEven
              ? (pal.primary, pal.onPrimary)
              : (pal.accent, pal.onAccent));
    final status = off
        ? 'shot, not this one'
        : shownRight
        ? 'the right target'
        : hit
        ? 'missed'
        : '';
    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: !off && !f.answered,
      label:
          '${status.isEmpty ? o.label : '${o.label}, $status'}, key ${i + 1}',
      onTap: off || f.answered ? null : () => _fire(i),
      child: FocusableActionDetector(
        enabled: !off && !f.answered,
        onShowFocusHighlight: (v) => setState(
          () => _focused = v ? i : (_focused == i ? null : _focused),
        ),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _fire(i);
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: TestIds.mgChoice(f.gameId, i),
          behavior: HitTestBehavior.opaque,
          onTap: off || f.answered ? null : () => _fire(i),
          child: Opacity(
            opacity: hit ? 0.35 : 1,
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focused == i ? pal.accent : pal.border,
                  width: shownRight || _focused == i ? 4 : 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Stack(
                children: [
                  Center(
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
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Text(
                      '${i + 1}',
                      key: Key('shooter.key.$i'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cannon drawn in code: a barrel and a wheel. No figures.
class _CannonPainter extends CustomPainter {
  _CannonPainter(this.fill, this.edge);
  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final barrel = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.38, 0, size.width * 0.24, size.height * 0.7),
      const Radius.circular(4),
    );
    canvas.drawRRect(barrel, Paint()..color = fill);
    canvas.drawRRect(
      barrel,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.78),
      size.height * 0.22,
      Paint()..color = fill,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.78),
      size.height * 0.22,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CannonPainter old) =>
      old.fill != fill || old.edge != edge;
}
