import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../kit/ds_buttons.dart';
import '../kit/ds_chips.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';

/// The winding path of topic nodes on the Study "Map" page. Nothing is locked: every node can
/// be tapped, and [onTap] decides what it does.
class TopicMapPath extends StatelessWidget {
  const TopicMapPath({super.key, required this.nodes, required this.onTap});
  final List<MapNode> nodes;
  final void Function(MapNode node) onTap;

  /// Sideways steps of the path, repeated: left, middle, right, middle.
  static const List<double> _bends = [-1, 0, 1, 0];

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final size = (t.minTouch * 1.3).clamp(56.0, 96.0);
    return Semantics(
      container: true,
      label: '${nodes.length} topics, in the order to learn them',
      child: Column(
        key: TestIds.mapPath,
        children: [
          for (var i = 0; i < nodes.length; i++) ...[
            if (i > 0) Container(width: 4, height: t.sp('md'), color: t.border),
            Align(
              alignment: Alignment(_bends[i % _bends.length] * 0.5, 0),
              child: _Node(
                node: nodes[i],
                index: i,
                count: nodes.length,
                size: size,
                onTap: () => onTap(nodes[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _icon(MapNodeState s) => switch (s) {
  MapNodeState.notOpen => 'chevron_right',
  MapNodeState.learning => 'book',
  MapNodeState.gettingThere => 'bars',
  MapNodeState.mastered => 'star',
};

/// What a screen reader says: "Topic 3 of 6: Fractions, Getting there, 4 to revise".
String mapNodeLabel(MapNode n, int index, int count) => [
  'Topic ${index + 1} of $count: ${n.name}',
  n.stateLabel,
  if (n.toRevise > 0) '${n.toRevise} to revise',
].join(', ');

class _Node extends StatelessWidget {
  const _Node({
    required this.node,
    required this.index,
    required this.count,
    required this.size,
    required this.onTap,
  });
  final MapNode node;
  final int index;
  final int count;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final open = node.isOpen;
    final fill = switch (node.state) {
      MapNodeState.notOpen => t.surfaceAlt,
      MapNodeState.mastered => t.success,
      _ => t.surface,
    };
    final fg = node.state == MapNodeState.mastered ? t.onPrimary : t.text;
    return Semantics(
      key: TestIds.mapNode(node.key),
      container: true,
      button: true,
      label: mapNodeLabel(node, index, count),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.cardRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouch, maxWidth: 280),
          child: Opacity(
            opacity: open ? 1 : 0.75,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: open ? t.primary : t.border,
                      width: open ? 3 : 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: DsIcon(
                    _icon(node.state),
                    size: size * 0.45,
                    color: fg,
                  ),
                ),
                SizedBox(width: t.sp('sm')),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(node.name, style: t.styles['body']!),
                      Text(
                        node.stateLabel,
                        style: t.styles['caption']!.copyWith(
                          color: t.textMuted,
                        ),
                      ),
                      if (open) _Pips(node: node),
                      if (node.toRevise > 0)
                        Padding(
                          padding: EdgeInsets.only(top: t.sp('xs')),
                          child: DsLabelChip(
                            key: TestIds.mapRevise(node.key),
                            label: '${node.toRevise} to revise',
                            icon: 'revise',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three pips; filled up to the mastery level. Shown instantly (no animation).
class _Pips extends StatelessWidget {
  const _Pips({required this.node});
  final MapNode node;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Row(
      key: TestIds.mapPips(node.key),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: EdgeInsets.only(right: t.sp('xs')),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < node.pips ? t.primary : Colors.transparent,
              border: Border.all(color: t.primary, width: 2),
            ),
          ),
      ],
    );
  }
}

/// The sheet a node opens: progress, mastery, revise count, accuracy (when allowed) and the
/// two buttons. [onPractise] and [onRevise] close the sheet themselves in the caller.
class TopicMapSheet extends StatelessWidget {
  const TopicMapSheet({
    super.key,
    required this.node,
    required this.showAccuracy,
    required this.onPractise,
    required this.onRevise,
  });
  final MapNode node;
  final bool showAccuracy;
  final VoidCallback onPractise;
  final VoidCallback onRevise;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final caption = t.styles['body']!;
    return SafeArea(
      child: SingleChildScrollView(
        key: TestIds.mapSheet,
        padding: EdgeInsets.all(t.sp('lg')),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(node.name, style: t.styles['heading']!),
            ),
            SizedBox(height: t.sp('sm')),
            if (!node.isOpen)
              Text(
                'Opens as you go. Keep practising and more questions in this '
                'topic will open.',
                key: TestIds.mapSheetClosed,
                style: caption,
              )
            else ...[
              Text('${node.passed} of ${node.total} passed', style: caption),
              Text(node.stateLabel, style: caption),
              Text(
                node.toRevise > 0
                    ? '${node.toRevise} to revise'
                    : 'Nothing to revise',
                style: caption,
              ),
              if (showAccuracy && node.accuracyPercent != null)
                Text('${node.accuracyPercent}% correct', style: caption),
              SizedBox(height: t.sp('md')),
              DsButton(
                id: 'map.practise',
                label: 'Practise',
                onPressed: onPractise,
                expand: true,
              ),
              if (node.toRevise > 0) ...[
                SizedBox(height: t.sp('sm')),
                DsButton(
                  id: 'map.revise',
                  label: 'Revise this topic',
                  kind: DsButtonKind.secondary,
                  icon: 'revise',
                  onPressed: onRevise,
                  expand: true,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
