import 'dart:math';

import 'package:flutter/material.dart';

import '../host/services.dart';
import '../game/rules/boosts.dart';
import 'test_ids.dart';
import 'widgets.dart';

/// Size of a boost button (dp).
const double boostButtonSize = 48;

/// One round boost button: icon, small count badge, highlighted while armed, grey when it
/// cannot be used right now.
class BoostButton extends StatelessWidget {
  const BoostButton({
    super.key,
    required this.def,
    required this.count,
    required this.armed,
    required this.enabled,
    required this.onTap,
  });

  final BoostDef def;
  final int count;
  final bool armed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = armed
        ? const Color(0xFFFFC145)
        : enabled
        ? const Color(0xFF7B3FD6)
        : const Color(0x55FFFFFF);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: armed,
      label: '${def.name}, $count left',
      excludeSemantics: true,
      child: GestureDetector(
        key: TestIds.gameItem(def.key),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: boostButtonSize,
          height: boostButtonSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                    border: Border.all(
                      color: armed ? Colors.white : const Color(0x88FFFFFF),
                      width: armed ? 3 : 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: CustomPaint(
                      painter: BoostIconPainter(
                        def.id,
                        armed ? const Color(0xFF3B2A00) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  key: TestIds.gameItemCount(def.key),
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: count > 0
                        ? const Color(0xFFFFC145)
                        : const Color(0xFF1E1535),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: count > 0 ? const Color(0xFF3B2A00) : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly icons drawn in code (no assets).
class BoostIconPainter extends CustomPainter {
  BoostIconPainter(this.id, this.color);
  final BoostId id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (id) {
      case BoostId.blast:
        // Star burst.
        final path = Path();
        for (var i = 0; i < 16; i++) {
          final a = -pi / 2 + i * pi / 8;
          final r = (i.isEven ? 0.5 : 0.24) * w;
          final p = Offset(w / 2 + cos(a) * r, h / 2 + sin(a) * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), fill);
      case BoostId.shuffle:
        // Two arrows going opposite ways.
        canvas.drawLine(
          Offset(w * .1, h * .35),
          Offset(w * .85, h * .35),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * .65, h * .15)
            ..lineTo(w * .88, h * .35)
            ..lineTo(w * .65, h * .55),
          line,
        );
        canvas.drawLine(Offset(w * .9, h * .7), Offset(w * .15, h * .7), line);
        canvas.drawPath(
          Path()
            ..moveTo(w * .35, h * .5)
            ..lineTo(w * .12, h * .7)
            ..lineTo(w * .35, h * .9),
          line,
        );
      case BoostId.undo:
        // Curved arrow turning back.
        canvas.drawArc(
          Rect.fromLTWH(w * .2, h * .25, w * .65, h * .6),
          -pi / 2,
          pi * 1.2,
          false,
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * .42, h * .08)
            ..lineTo(w * .2, h * .25)
            ..lineTo(w * .45, h * .42),
          line,
        );
      case BoostId.sweep:
        // A row of blocks with a swoosh through it.
        for (var i = 0; i < 4; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(w * (.06 + i * .24), h * .62, w * .2, h * .24),
              Radius.circular(w * .05),
            ),
            fill,
          );
        }
        canvas.drawLine(Offset(w * .1, h * .3), Offset(w * .8, h * .3), line);
        canvas.drawPath(
          Path()
            ..moveTo(w * .62, h * .12)
            ..lineTo(w * .88, h * .3)
            ..lineTo(w * .62, h * .48),
          line,
        );
      case BoostId.hammer:
        canvas.save();
        canvas.translate(w / 2, h / 2);
        canvas.rotate(-pi / 4);
        canvas.drawLine(
          Offset(0, -h * .1),
          Offset(0, h * .5),
          line..strokeWidth = w * .16,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, -h * .22),
              width: w * .7,
              height: h * .3,
            ),
            Radius.circular(w * .08),
          ),
          fill,
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BoostIconPainter old) =>
      old.id != id || old.color != color;
}

/// "Tap a cell" chip with a Cancel button, shown while Blast or Hammer is armed.
class TargetChip extends StatelessWidget {
  const TargetChip({super.key, required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: TestIds.gameItemChip,
      height: 32,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xE61E1535),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tap a cell',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: TestIds.gameItemCancel,
            style: TextButton.styleFrom(
              minimumSize: const Size(56, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: const Color(0xFFFFC145),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// What the empty-stock sheet returns.
enum RefillChoice { coins, ad, shop }

/// Small sheet for a boost with no stock left: buy with coins, watch an ad, or get coins.
Future<RefillChoice?> showBoostRefillSheet(
  BuildContext context, {
  required BlockPuzzleServices services,
  required BoostDef def,
  required int adRefillsLeft,
}) {
  return showModalBottomSheet<RefillChoice>(
    context: context,
    backgroundColor: const Color(0xFF1E1535),
    builder: (ctx) {
      final coins = services.profile.data.coins;
      final canBuy = coins >= def.price;
      final noAds = services.profile.data.adsRemoved;
      final adLabel = noAds
          ? 'Get +1 free ($adRefillsLeft left)'
          : 'Watch ad for +1';
      return SafeArea(
        child: Padding(
          key: TestIds.gameItemSheet,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${def.name}: none left',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              // What the power does, readable before spending anything.
              Text(
                def.description,
                key: TestIds.gameItemDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: TestIds.gameItemRefillCoins,
                onPressed: canBuy
                    ? () => Navigator.pop(ctx, RefillChoice.coins)
                    : null,
                child: canBuy
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Buy with coins  '),
                            Text('${def.price} '),
                            const CoinIcon(size: 20),
                          ],
                        ),
                      )
                    : const Text('Not enough coins'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: TestIds.gameItemRefillAd,
                onPressed: adRefillsLeft > 0
                    ? () => Navigator.pop(ctx, RefillChoice.ad)
                    : null,
                child: Text(adRefillsLeft > 0 ? adLabel : 'No more refills'),
              ),
              if (!canBuy) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: TestIds.gameItemRefillShop,
                  onPressed: () => Navigator.pop(ctx, RefillChoice.shop),
                  child: const Text('Get coins'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
