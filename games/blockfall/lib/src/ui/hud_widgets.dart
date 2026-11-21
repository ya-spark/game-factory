import 'dart:async';

import 'package:flutter/material.dart';

import '../game/flame/blockfall_flame_game.dart' show previewCells;
import '../game/flame/gem_painter.dart';
import '../game/rules/active_piece.dart';
import '../game/rules/piece_type.dart';
import '../game/rules/powerups.dart';
import '../game/themes/block_theme.dart';
import 'theme_fade.dart';
import 'test_ids.dart';

const Color kTeal = Color(0xFF2EC4B6);
const Color kGold = Color(0xFFFFC145);
const Color kMuted = Color(0xFF7FB7BD);

/// Exposes [value] as the Semantics value of a keyed node (for tests and the bot).
class ValueNode extends StatelessWidget {
  const ValueNode({
    super.key,
    required this.value,
    required this.child,
    this.label,
  });
  final String value;
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    value: value,
    child: ExcludeSemantics(child: child),
  );
}

/// Small preview of a piece (HOLD and NEXT).
class PiecePreview extends StatelessWidget {
  const PiecePreview({
    super.key,
    required this.spec,
    required this.cell,
    required this.theme,
    this.dim = false,
  });
  final BlockTheme theme;

  /// The piece with its special cell, if any.
  final PieceSpec spec;
  final double cell;
  final bool dim;

  PieceType get type => spec.type;

  @override
  Widget build(BuildContext context) {
    final p = previewCells(type, null);
    // The previews cross-fade with the well when the theme changes.
    return Opacity(
      opacity: dim ? 0.35 : 1,
      child: ThemeFade(
        theme: theme,
        builder: (context, from, to, t) => CustomPaint(
          size: Size(p.cols * cell, p.rows * cell),
          painter: _PreviewPainter(spec, cell, from, to, t),
        ),
      ),
    );
  }
}

final ThemeTileCache _previewTiles = ThemeTileCache();

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.spec, this.cell, this.from, this.to, this.t);
  final PieceSpec spec;
  final double cell;
  final BlockTheme from;
  final BlockTheme to;
  final double t;

  PieceType get type => spec.type;

  void _cells(Canvas canvas, BlockTheme theme) {
    final p = previewCells(type, null);
    for (var i = 0; i < p.cells.length; i++) {
      final (c, r) = p.cells[i];
      _previewTiles.draw(
        canvas,
        theme,
        type.colorId,
        Rect.fromLTWH(c * cell, r * cell, cell, cell),
        kind: spec.kindOf(i),
        pulse: 0.25,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) {
      _cells(canvas, to);
      return;
    }
    _cells(canvas, from);
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, t));
    _cells(canvas, to);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.type != type ||
      old.spec.prismCell != spec.prismCell ||
      old.spec.boomCell != spec.boomCell ||
      old.spec.goldCell != spec.goldCell ||
      old.cell != cell ||
      old.from.id != from.id ||
      old.to.id != to.id ||
      old.t != t;
}

/// Rounded dark panel with a thin teal outline and a small caption.
class HudBox extends StatelessWidget {
  const HudBox({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.child,
  });
  final String label;
  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xCC08141B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x662EC4B6)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            color: kMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(child: Center(child: child)),
      ],
    ),
  );
}

/// LEVEL / GOAL read-out.
class StatPanel extends StatelessWidget {
  const StatPanel({
    super.key,
    required this.label,
    required this.value,
    required this.width,
    this.height,
  });
  final String label;
  final int value;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xCC08141B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x662EC4B6)),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: kMuted,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Glowing score in an outlined pill.
class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) => ValueNode(
    key: TestIds.gameScore,
    value: '$score',
    label: 'Score',
    child: Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kTeal, width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x552EC4B6), blurRadius: 22)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: TextStyle(
              color: HudColors.of(context).text,
              shadows: HudColors.of(context).shadows,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          Text(
            'SCORE',
            key: TestIds.gameScoreLabel,
            style: TextStyle(
              fontSize: 9,
              height: 1.1,
              letterSpacing: 3,
              color: HudColors.of(context).subtle,
              shadows: HudColors.of(context).shadows,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bomb drawn with the same painter as the falling bomb.
class BombIcon extends StatelessWidget {
  const BombIcon({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _BombPainter());
}

class _BombPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) =>
      GemPainter.drawBomb(canvas, Offset.zero & size, 0.25);

  @override
  bool shouldRepaint(_BombPainter old) => false;
}

/// One of the three power-up buttons with its stock badge.
class PowerUpButton extends StatelessWidget {
  const PowerUpButton({
    super.key,
    required this.type,
    required this.stock,
    required this.active,
    required this.onTap,
    this.caption,
  });
  final PowerUpType type;
  final int stock;
  final bool active;
  final String? caption;
  final VoidCallback onTap;

  static Key buttonKey(PowerUpType t) => switch (t) {
    PowerUpType.sweep => TestIds.gamePowerUpSweep,
    PowerUpType.slow => TestIds.gamePowerUpSlow,
    PowerUpType.bomb => TestIds.gamePowerUpBomb,
  };

  static Key countKey(PowerUpType t) => switch (t) {
    PowerUpType.sweep => TestIds.gamePowerUpSweepCount,
    PowerUpType.slow => TestIds.gamePowerUpSlowCount,
    PowerUpType.bomb => TestIds.gamePowerUpBombCount,
  };

  static String title(PowerUpType t) => switch (t) {
    PowerUpType.sweep => 'Sweep',
    PowerUpType.slow => 'Slow',
    PowerUpType.bomb => 'Boom',
  };

  static String description(PowerUpType t) => switch (t) {
    PowerUpType.sweep => 'Clears the bottom 3 rows at once.',
    PowerUpType.slow => 'Halves the falling speed for 20 seconds.',
    PowerUpType.bomb => 'Turns the falling piece into a bomb that blasts the 3x3 area where it lands.',
  };

  Widget _icon() => switch (type) {
    PowerUpType.sweep => const Icon(Icons.waves, color: Color(0xFF39D0F2)),
    PowerUpType.slow => const Icon(
      Icons.hourglass_bottom,
      color: Color(0xFFFFC145),
    ),
    PowerUpType.bomb => const BombIcon(),
  };

  @override
  Widget build(BuildContext context) {
    final empty = stock <= 0;
    return Semantics(
      button: true,
      label: title(type),
      child: InkWell(
        key: buttonKey(type),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: active ? const Color(0x3339D0F2) : const Color(0xCC08141B),
            border: Border.all(
              color: active ? const Color(0xFF7FD6FF) : const Color(0x662EC4B6),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(opacity: empty ? 0.5 : 1, child: _icon()),
                  Positioned(
                    right: -16,
                    top: -8,
                    child: ValueNode(
                      key: countKey(type),
                      value: '$stock',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: empty ? const Color(0xFF55646B) : kGold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          empty ? '+' : '$stock',
                          style: const TextStyle(
                            color: Color(0xFF0A1822),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                caption ?? title(type),
                style: const TextStyle(fontSize: 11, color: Color(0xFFCFE9EC)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One on-screen control button; fires on press, optionally repeating while held.
class ControlButton extends StatefulWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPress,
    this.onRelease,
    this.repeat = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPress;
  final VoidCallback? onRelease;
  final bool repeat;

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  Timer? _delay;
  Timer? _timer;
  bool _pressed = false;

  void _down() {
    setState(() => _pressed = true);
    widget.onPress();
    if (widget.repeat) {
      _delay = Timer(const Duration(milliseconds: 260), () {
        _timer = Timer.periodic(
          const Duration(milliseconds: 80),
          (_) => widget.onPress(),
        );
      });
    }
  }

  void _up() {
    _delay?.cancel();
    _timer?.cancel();
    _delay = _timer = null;
    if (_pressed) {
      if (mounted) setState(() => _pressed = false);
      widget.onRelease?.call();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _down(),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _pressed ? const Color(0x552EC4B6) : const Color(0xCC08141B),
          border: Border.all(color: const Color(0x882EC4B6)),
        ),
        child: Icon(widget.icon, color: Colors.white),
      ),
    ),
  );
}
