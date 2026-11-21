import 'package:flutter/material.dart';

import '../door_runner_ids.dart';
import 'door_runner_extras.dart';
import 'door_runner_keyboard.dart';
import 'door_runner_style.dart';

/// Places the Door runner pieces. Window 1024 px and wider: the play column (at most 760 px,
/// centred) with a 300 px ad rail at the right and the key hints under the field. Narrower:
/// the slim ad strip at the top, the whole width for play and the touch slow zone at the bottom.
/// (A local breakpoint: this app keeps its phone layout elsewhere; R2 moves it to
/// `responsive.dart`.)
class DoorRunnerFrame extends StatelessWidget {
  const DoorRunnerFrame({
    super.key,
    required this.hud,
    required this.question,
    required this.field,
    required this.slowZone,
    this.overlay,
    this.world = 0,
  });
  final int world;
  final Widget hud;
  final Widget question;
  final Widget field;
  final Widget slowZone;

  /// Pause overlay, drawn over the field only.
  final Widget? overlay;

  static const double railFrom = 1024;
  static const double playMaxWidth = 760;

  @override
  Widget build(BuildContext context) {
    final sky = DrColors.world(world);
    return Material(
      key: DoorRunnerIds.frame,
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: sky,
            stops: const [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= railFrom;
              final play = Column(
                children: [
                  hud,
                  question,
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: field),
                        if (overlay != null) Positioned.fill(child: overlay!),
                      ],
                    ),
                  ),
                  if (wide) const DoorRunnerKeyHints() else slowZone,
                ],
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(
                      child: Align(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: playMaxWidth,
                          ),
                          child: play,
                        ),
                      ),
                    ),
                    const DoorRunnerAdSlot(rail: true),
                  ],
                );
              }
              return Column(
                children: [
                  const DoorRunnerAdSlot(rail: false),
                  Expanded(child: play),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
