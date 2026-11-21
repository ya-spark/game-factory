import 'package:flutter/material.dart';

import '../game/rules/best_move.dart';
import '../game/themes/block_theme.dart';
import 'test_ids.dart';

/// Game over help: shows, step by step, how the last three blocks could have been played
/// for the most cleared lines.
class BestMoveDialog extends StatefulWidget {
  const BestMoveDialog({super.key, required this.best, required this.theme});

  /// Null when nothing could be placed.
  final BestMove? best;
  final BlockTheme theme;

  @override
  State<BestMoveDialog> createState() => _BestMoveDialogState();
}

class _BestMoveDialogState extends State<BestMoveDialog> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final best = widget.best;
    if (best == null || best.steps.isEmpty) {
      return AlertDialog(
        key: TestIds.bestMoveDialog,
        title: const Text('Best move'),
        content: const Text('No better placement was possible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final step = best.steps[_step];
    final last = _step == best.steps.length - 1;
    final lines = step.clearedRows.length + step.clearedCols.length;
    return AlertDialog(
      key: TestIds.bestMoveDialog,
      title: Text('Best move · step ${_step + 1} of ${best.steps.length}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              key: TestIds.bestMoveBoard,
              painter: _BestMovePainter(step, widget.theme),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lines > 0
                ? 'Clears $lines ${lines == 1 ? 'line' : 'lines'} '
                      '(${best.lines} in total)'
                : 'Sets up the next step',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Back'),
          ),
        if (!last)
          FilledButton(
            key: TestIds.bestMoveNext,
            onPressed: () => setState(() => _step++),
            child: const Text('Next'),
          ),
      ],
    );
  }
}

class _BestMovePainter extends CustomPainter {
  _BestMovePainter(this.step, this.theme);
  final BestMoveStep step;
  final BlockTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final board = step.before;
    final n = board.size;
    final cs = size.width / n;
    final empty = Paint()..color = const Color(0x22000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0x14000000),
    );
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(c * cs, r * cs, cs, cs).deflate(1.5);
        final v = board.at(r, c);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          v == 0 ? empty : (Paint()..color = theme.colorAt(v - 1)),
        );
      }
    }
    // Lines this step completes.
    final line = Paint()..color = const Color(0x66FFD54F);
    for (final r in step.clearedRows) {
      canvas.drawRect(Rect.fromLTWH(0, r * cs, size.width, cs), line);
    }
    for (final c in step.clearedCols) {
      canvas.drawRect(Rect.fromLTWH(c * cs, 0, cs, size.height), line);
    }
    // The piece to place, outlined.
    final fill = Paint()..color = theme.colorAt(step.piece.colorIndex);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white;
    for (final (dr, dc) in step.piece.cells) {
      final rect = Rect.fromLTWH(
        (step.col + dc) * cs,
        (step.row + dr) * cs,
        cs,
        cs,
      ).deflate(1.5);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, edge);
    }
  }

  @override
  bool shouldRepaint(_BestMovePainter old) =>
      old.step != step || old.theme != theme;
}
