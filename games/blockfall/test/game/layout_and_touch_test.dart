import 'package:game_blockfall/src/game/flame/blockfall_layout.dart';
import 'package:game_blockfall/src/game/flame/touch_controls.dart';
import 'package:flutter_test/flutter_test.dart';

class Log {
  final List<String> calls = [];
  late final ControlSink sink = ControlSink(
    moveLeft: () => calls.add('L'),
    moveRight: () => calls.add('R'),
    rotate: () => calls.add('rot'),
    softDrop: (on) => calls.add(on ? 'soft+' : 'soft-'),
    hardDrop: () => calls.add('hard'),
  );
}

void main() {
  group('BlockfallLayout', () {
    test('fits width and height and keeps square cells', () {
      for (final (w, h) in [(400.0, 560.0), (360.0, 330.0), (800.0, 900.0)]) {
        final l = BlockfallLayout(w, h);
        expect(l.wellHeight, lessThanOrEqualTo(h + 1e-9));
        expect(l.wellWidth, lessThanOrEqualTo(w + 1e-9));
        expect(l.hudHeight + l.gap + l.wellHeight, lessThanOrEqualTo(h + 1e-9));
        expect(l.wellHeight / l.wellWidth, closeTo(2, 0.35));
      }
    });

    test('HUD strip boxes fit across the width', () {
      final l = BlockfallLayout(400, 560);
      expect(
        l.boxWidth * BlockfallLayout.hudBoxes +
            l.gap * (BlockfallLayout.hudBoxes + 1),
        closeTo(400, 1e-9),
      );
    });

    test('columnsFor counts whole cell widths', () {
      final l = BlockfallLayout(400, 560);
      expect(l.columnsFor(l.cell * 3), 3);
      expect(l.columnsFor(-l.cell * 2.5), 2);
      expect(l.columnsFor(l.cell * 0.9), 0);
    });
  });

  group('WellGeometry', () {
    test('hidden rows have no origin; row 2 is the top of the canvas', () {
      final g = WellGeometry(206, 412);
      expect(g.cellOrigin(0, 0), isNull);
      expect(g.cellOrigin(1, 5), isNull);
      final top = g.cellOrigin(2, 0)!;
      expect(top.$1, closeTo(g.left, 1e-9));
      expect(top.$2, closeTo(g.top, 1e-9));
      final bottom = g.cellOrigin(21, 9)!;
      expect(bottom.$2 + g.cell, closeTo(g.top + g.wellPixelHeight, 1e-9));
      expect(bottom.$1 + g.cell, closeTo(g.left + g.wellPixelWidth, 1e-9));
    });

    test('well is centered in the canvas', () {
      final g = WellGeometry(300, 500);
      expect(g.left * 2 + g.wellPixelWidth, closeTo(300, 1e-9));
      expect(g.top * 2 + g.wellPixelHeight, closeTo(500, 1e-9));
    });
  });

  group('TouchControls', () {
    late Log log;
    late TouchControls t;
    setUp(() {
      log = Log();
      t = TouchControls(cellWidth: 20, sink: log.sink);
    });

    test('tap rotates', () {
      t.pointerDown(100, 100, 1000);
      t.pointerUp(103, 102, 1100, 0);
      expect(log.calls, ['rot']);
    });

    test('slow tap does not rotate', () {
      t.pointerDown(100, 100, 1000);
      t.pointerUp(100, 100, 1300, 0);
      expect(log.calls, isEmpty);
    });

    test('tap exactly at the time limit still rotates', () {
      t.pointerDown(100, 100, 0);
      t.pointerUp(100, 100, GestureThresholds.tapMaxMillis, 0);
      expect(log.calls, ['rot']);
    });

    test('horizontal drag moves one column per cell width, both ways', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(130, 101);
      expect(log.calls, ['R']);
      t.pointerMove(160, 101);
      expect(log.calls, ['R', 'R', 'R']);
      t.pointerMove(100, 101);
      expect(log.calls.skip(3), ['L', 'L', 'L']);
      t.pointerUp(100, 101, 900, 0);
      expect(log.calls.last, 'L');
      expect(log.calls.contains('rot'), isFalse);
    });

    test('drag of exactly three cell widths moves three columns', () {
      t.pointerDown(200, 100, 0);
      t.pointerMove(140, 100);
      t.pointerUp(140, 100, 300, 0);
      expect(log.calls, ['L', 'L', 'L']);
    });

    test('slow downward drag soft drops until release', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(101, 130);
      expect(log.calls, ['soft+']);
      t.pointerMove(101, 200);
      t.pointerUp(101, 200, 2000, 300);
      expect(log.calls, ['soft+', 'soft-']);
    });

    test('fast fling downward hard drops', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(100, 150);
      t.pointerUp(100, 300, 100, 2000);
      expect(log.calls, ['soft+', 'soft-', 'hard']);
    });

    test('fling just below the threshold does not hard drop', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(100, 150);
      t.pointerUp(100, 300, 100, 1199);
      expect(log.calls, ['soft+', 'soft-']);
    });

    test('fling at the threshold hard drops', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(100, 150);
      t.pointerUp(100, 300, 100, 1200);
      expect(log.calls.last, 'hard');
    });

    test('swipe up does nothing', () {
      t.pointerDown(100, 200, 0);
      t.pointerMove(100, 120);
      t.pointerUp(100, 50, 100, -2500);
      expect(log.calls, isEmpty);
    });

    test('cancel releases soft drop', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(100, 160);
      t.cancel();
      expect(log.calls, ['soft+', 'soft-']);
      expect(t.isDown, isFalse);
    });

    test('a horizontal drag followed by a fast flick does not hard drop', () {
      t.pointerDown(100, 100, 0);
      t.pointerMove(140, 100);
      t.pointerUp(140, 250, 100, 3000);
      expect(log.calls.contains('hard'), isFalse);
    });
  });
}
