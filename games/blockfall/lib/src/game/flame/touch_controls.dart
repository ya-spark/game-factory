import 'dart:math';

import 'blockfall_layout.dart';

/// What the touch scheme can do to the game.
class ControlSink {
  const ControlSink({
    required this.moveLeft,
    required this.moveRight,
    required this.rotate,
    required this.softDrop,
    required this.hardDrop,
  });
  final void Function() moveLeft;
  final void Function() moveRight;
  final void Function() rotate;
  final void Function(bool on) softDrop;
  final void Function() hardDrop;
}

enum _Mode { undecided, horizontal, down, ignored }

/// Pure-Dart state machine for one finger on the well (plain doubles, no Flutter).
///
/// - tap (under 10 px, under 250 ms): rotate
/// - horizontal drag: one column per cell width travelled since the last move
/// - slow downward drag: soft drop while down, released on lift
/// - downward fling at 1200 px/s or more: hard drop
/// - swipe up: nothing
class TouchControls {
  TouchControls({required this.cellWidth, required this.sink});

  /// Width of one well cell in pixels; updated when the layout changes.
  double cellWidth;
  final ControlSink sink;

  bool _down = false;
  _Mode _mode = _Mode.undecided;
  double _startX = 0, _startY = 0, _anchorX = 0;
  int _startMillis = 0;
  bool _softOn = false;

  bool get isDown => _down;

  void pointerDown(double x, double y, int millis) {
    _down = true;
    _mode = _Mode.undecided;
    _startX = x;
    _startY = y;
    _anchorX = x;
    _startMillis = millis;
    _softOn = false;
  }

  void pointerMove(double x, double y) {
    if (!_down) return;
    if (_mode == _Mode.undecided) {
      final dx = x - _startX, dy = y - _startY;
      if (sqrt(dx * dx + dy * dy) <= GestureThresholds.tapMaxMove) return;
      if (dx.abs() >= dy.abs()) {
        _mode = _Mode.horizontal;
      } else if (dy > 0) {
        _mode = _Mode.down;
        _softOn = true;
        sink.softDrop(true);
      } else {
        _mode = _Mode.ignored;
      }
    }
    if (_mode == _Mode.horizontal) {
      final step = cellWidth - 1e-6;
      while (x - _anchorX >= step) {
        sink.moveRight();
        _anchorX += cellWidth;
      }
      while (_anchorX - x >= step) {
        sink.moveLeft();
        _anchorX -= cellWidth;
      }
    }
  }

  /// [velocityY] is the vertical release velocity in px/s (positive = downwards).
  void pointerUp(double x, double y, int millis, double velocityY) {
    if (!_down) return;
    pointerMove(x, y);
    _down = false;
    switch (_mode) {
      case _Mode.undecided:
        if (millis - _startMillis <= GestureThresholds.tapMaxMillis) {
          sink.rotate();
        }
      case _Mode.down:
        if (_softOn) sink.softDrop(false);
        _softOn = false;
        if (velocityY >= GestureThresholds.flingVelocity) sink.hardDrop();
      case _Mode.horizontal:
      case _Mode.ignored:
        break;
    }
    _mode = _Mode.undecided;
  }

  void cancel() {
    if (_softOn) sink.softDrop(false);
    _softOn = false;
    _down = false;
    _mode = _Mode.undecided;
  }
}
