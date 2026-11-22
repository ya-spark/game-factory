import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/content/mastery.dart';
import '../../engine/content/trail.dart';
import '../layout/window_class.dart';
import 'constellation_ids.dart';

/// The skill trail drawn as constellations (owner, 2026-11-21): each topic is a small
/// constellation, each rung a star. Shows skill progress only. Drawn in code (no images),
/// reachable with Tab and arrow keys, every star has a screen-reader label and a stable key.
/// Pure view: the caller passes the rungs ([Trail.build]) and gets taps through [onSelect].
class ConstellationTrail extends StatelessWidget {
  const ConstellationTrail({
    super.key,
    required this.nodes,
    required this.onSelect,
    this.topicTitles = const {},
    this.selectedKey,
  });

  /// Rungs in teaching order; grouped by topic here.
  final List<TrailNode> nodes;

  /// Called with the tapped (or activated) rung. Locked rungs are passed too: the caller
  /// decides (the web is all open, so it normally lets everything through).
  final ValueChanged<TrailNode> onSelect;

  /// Optional display name per topic key (`subject/year/topic`); the id is used otherwise.
  final Map<String, String> topicTitles;

  final String? selectedKey;

  /// Groups [nodes] by topic, keeping the teaching order.
  static Map<String, List<TrailNode>> groupByTopic(List<TrailNode> nodes) {
    final out = <String, List<TrailNode>>{};
    for (final n in nodes) {
      (out[n.skill.topicKey] ??= []).add(n);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.skill.rung.compareTo(b.skill.rung));
    }
    return out;
  }

  static String _titleCase(String id) => id
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final groups = groupByTopic(nodes);
    final cls = WindowClass.ofContext(context);
    final cols = switch (cls) {
      WindowClass.compact => 1,
      WindowClass.medium => 2,
      WindowClass.expanded => 3,
    };
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(cls)),
          child: LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              final w = c.maxWidth.isFinite
                  ? (c.maxWidth - gap * (cols - 1)) / cols
                  : 320.0;
              return Wrap(
                key: ConstellationIds.root,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final e in groups.entries)
                    SizedBox(
                      width: w,
                      child: _TopicCard(
                        topicKey: e.key,
                        title:
                            topicTitles[e.key] ??
                            _titleCase(e.value.first.skill.topic),
                        rungs: e.value,
                        onSelect: onSelect,
                        selectedKey: selectedKey,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Spoken state of a rung.
String stateLabel(SkillState s) => switch (s) {
  SkillState.locked => 'locked',
  SkillState.unseen => 'not started',
  SkillState.practising => 'practising, 1 of 3 stars',
  SkillState.secure => 'secure, 2 of 3 stars',
  SkillState.mastered => 'mastered, 3 of 3 stars',
};

/// Star centres inside a topic card, as fractions of its drawing area (a gentle zigzag).
List<Offset> starSpots(int count) {
  if (count <= 1) return const [Offset(0.5, 0.5)];
  return [
    for (var i = 0; i < count; i++)
      Offset(0.14 + 0.72 * i / (count - 1), i.isEven ? 0.62 : 0.34),
  ];
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topicKey,
    required this.title,
    required this.rungs,
    required this.onSelect,
    required this.selectedKey,
  });

  final String topicKey;
  final String title;
  final List<TrailNode> rungs;
  final ValueChanged<TrailNode> onSelect;
  final String? selectedKey;

  static const double _height = 150;
  static const double _hit = 56;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = rungs.where((n) => n.stars >= 2).length;
    final spots = starSpots(rungs.length);
    return Semantics(
      container: true,
      label: '$title, $done of ${rungs.length} rungs secure',
      child: Container(
        key: ConstellationIds.topicKeyOf(topicKey),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1530),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFE8ECFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: _height,
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = Size(c.maxWidth, _height);
                  Offset at(int i) => Offset(
                    spots[i].dx * size.width,
                    spots[i].dy * size.height,
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: ConstellationLinesPainter(
                              points: [
                                for (var i = 0; i < rungs.length; i++) at(i),
                              ],
                              lit: [for (final n in rungs) n.stars >= 1],
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < rungs.length; i++)
                        Positioned(
                          left: at(i).dx - _hit / 2,
                          top: at(i).dy - _hit / 2,
                          width: _hit,
                          height: _hit,
                          child: FocusTraversalOrder(
                            order: NumericFocusOrder(i.toDouble()),
                            child: _StarButton(
                              node: rungs[i],
                              selected: rungs[i].key == selectedKey,
                              focusColor: scheme.primary,
                              onSelect: onSelect,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Row(
              children: [
                for (final n in rungs)
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        n.skill.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: n.isLocked
                              ? const Color(0xFF7C86B0)
                              : const Color(0xFFC9D1F5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarButton extends StatefulWidget {
  const _StarButton({
    required this.node,
    required this.selected,
    required this.focusColor,
    required this.onSelect,
  });

  final TrailNode node;
  final bool selected;
  final Color focusColor;
  final ValueChanged<TrailNode> onSelect;

  @override
  State<_StarButton> createState() => _StarButtonState();
}

class _StarButtonState extends State<_StarButton> {
  bool _focused = false;

  void _activate() => widget.onSelect(widget.node);

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    return Semantics(
      button: true,
      selected: widget.selected,
      identifier: 'constellation.star.${n.key}',
      label: '${n.skill.name}, ${stateLabel(n.state)}',
      onTap: _activate,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          key: ConstellationIds.star(n.key),
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                PreviousFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
            NextFocusIntent: CallbackAction<NextFocusIntent>(
              onInvoke: (_) => FocusScope.of(context).nextFocus(),
            ),
            PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
              onInvoke: (_) => FocusScope.of(context).previousFocus(),
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _activate,
            child: CustomPaint(
              painter: StarPainter(
                stars: n.stars,
                locked: n.isLocked,
                focused: _focused,
                selected: widget.selected,
                focusColor: widget.focusColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lines joining the stars of a topic; a line is bright when both its ends have progress.
class ConstellationLinesPainter extends CustomPainter {
  const ConstellationLinesPainter({required this.points, required this.lit});

  final List<Offset> points;
  final List<bool> lit;

  @override
  void paint(Canvas canvas, Size size) {
    // A few fixed background specks so a sky is felt even before progress.
    final speck = Paint()..color = const Color(0x33FFFFFF);
    for (var i = 0; i < 14; i++) {
      final x = (i * 53 % 97) / 97 * size.width;
      final y = (i * 37 % 89) / 89 * size.height;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.4 : 0.9, speck);
    }
    for (var i = 0; i + 1 < points.length; i++) {
      final on = lit[i] && lit[i + 1];
      canvas.drawLine(
        points[i],
        points[i + 1],
        Paint()
          ..strokeWidth = on ? 2.4 : 1.2
          ..strokeCap = StrokeCap.round
          ..color = on ? const Color(0xCCFFE08A) : const Color(0x447C86B0),
      );
    }
  }

  @override
  bool shouldRepaint(ConstellationLinesPainter old) =>
      old.points != points || old.lit != lit;
}

/// One star: dim outline when not started or locked, then 1 to 3 glow rings as it is learnt.
class StarPainter extends CustomPainter {
  const StarPainter({
    required this.stars,
    required this.locked,
    required this.focused,
    required this.selected,
    required this.focusColor,
  });

  final int stars;
  final bool locked;
  final bool focused;
  final bool selected;
  final Color focusColor;

  static Path starPath(Offset c, double outer, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -3.14159265 / 2 + i * 3.14159265 / 5;
      final pt = Offset(c.dx + r * _cos(a), c.dy + r * _sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  static double _sin(double a) => Offset.fromDirection(a).dy;
  static double _cos(double a) => Offset.fromDirection(a).dx;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide * 0.3;
    final path = starPath(c, base, base * 0.45);
    if (stars > 0) {
      for (var i = 0; i < stars; i++) {
        canvas.drawCircle(
          c,
          base * (1.15 + 0.2 * i),
          Paint()..color = Color(0xFFFFE08A).withValues(alpha: 0.16 - 0.04 * i),
        );
      }
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFE08A));
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = locked ? const Color(0xFF4A5380) : const Color(0xFF9AA6D8),
      );
    }
    if (locked) {
      // A small bar under the star marks a rung not yet open; never colour alone.
      canvas.drawLine(
        c + Offset(-base * 0.5, base * 1.25),
        c + Offset(base * 0.5, base * 1.25),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0xFF4A5380),
      );
    }
    if (focused || selected) {
      canvas.drawCircle(
        c,
        size.shortestSide * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = focused ? 3 : 2
          ..color = focused ? focusColor : const Color(0xFFFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(StarPainter o) =>
      o.stars != stars ||
      o.locked != locked ||
      o.focused != focused ||
      o.selected != selected;
}
