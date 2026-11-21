import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../door_runner_ids.dart';
import 'door_runner_keyboard.dart';
import 'door_runner_style.dart';

/// Places the Door runner pieces inside the shared `GameFrame`: the play column is centred (at
/// most 760 wide). Window 1024 and wider: the key hints under the field. Narrower: the touch slow
/// zone at the bottom. No ad is shown or kept free while a run is played.
class DoorRunnerFrame extends StatelessWidget {
  const DoorRunnerFrame({
    super.key,
    required this.hud,
    required this.question,
    required this.field,
    required this.slowZone,
    this.overlay,
    this.world = 0,
    this.hints,
  });
  final int world;
  final Widget hud;
  final Widget question;
  final Widget field;
  final Widget slowZone;

  /// Pause overlay, drawn over the field only.
  final Widget? overlay;

  /// The key hints under the field, always shown (the race); null: the one-player rule, hints on a
  /// wide window and the touch slow zone below it.
  final Widget? hints;

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
          child: GameFrame(
            maxWidth: playMaxWidth,
            showAds: false,
            phoneBanner: null,
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, box) {
                final wide =
                    WindowClass.of(MediaQuery.sizeOf(context).width) ==
                    WindowClass.expanded;
                return Column(
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
                    if (hints != null)
                      hints!
                    else if (wide)
                      const DoorRunnerKeyHints()
                    else
                      slowZone,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
