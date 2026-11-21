import 'package:flutter/material.dart';

import '../door_runner_ids.dart';
import 'door_runner_style.dart';
import 'door_runner_view.dart';

/// The small top strip over the play area: exit and pause on the left (the same place as in
/// Wingy), the score in a glowing pill with the streak chip beside it, hearts on the right.
/// No game title (rule of 2026-11-21).
class DoorRunnerHud extends StatelessWidget {
  const DoorRunnerHud({
    super.key,
    required this.view,
    required this.onExit,
    required this.onPause,
  });
  final DoorRunnerView view;
  final VoidCallback onExit;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          KeyedSubtree(
            key: DoorRunnerIds.exit,
            child: DrRoundButton(
              icon: Icons.close,
              tooltip: 'Exit',
              onPressed: onExit,
            ),
          ),
          const SizedBox(width: 8),
          KeyedSubtree(
            key: DoorRunnerIds.pause,
            child: DrRoundButton(
              icon: view.paused ? Icons.play_arrow : Icons.pause,
              tooltip: view.paused ? 'Resume' : 'Pause',
              onPressed: onPause,
            ),
          ),
          // The score takes the space between; it shrinks before it can touch a button.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: IgnorePointer(child: _ScoreArea(view: view)),
              ),
            ),
          ),
          if (view.hearts != null) _Hearts(view: view),
        ],
      ),
    );
  }
}

class _Hearts extends StatelessWidget {
  const _Hearts({required this.view});
  final DoorRunnerView view;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${view.hearts} of ${view.maxHearts} lives',
      excludeSemantics: true,
      child: Row(
        key: DoorRunnerIds.hearts,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < view.maxHearts; i++)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                i < view.hearts! ? Icons.favorite : Icons.favorite_border,
                size: 26,
                color: DrColors.pink,
                shadows: i < view.hearts!
                    ? [
                        Shadow(
                          color: DrColors.pink.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreArea extends StatelessWidget {
  const _ScoreArea({required this.view});
  final DoorRunnerView view;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Score ${view.score}',
          excludeSemantics: true,
          child: Container(
            key: DoorRunnerIds.score,
            constraints: const BoxConstraints(minWidth: 112),
            height: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: DrColors.lilac, width: 1.5),
              color: const Color(0x22FFFFFF),
              boxShadow: drGlow(DrColors.lilac, alpha: 0.45, blur: 22),
            ),
            child: Text(
              '${view.score}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                shadows: drTextShadow,
              ),
            ),
          ),
        ),
        if (view.streak != null && view.streak! >= 2)
          Semantics(
            label: 'Streak ${view.streak}',
            excludeSemantics: true,
            child: Container(
              key: DoorRunnerIds.streak,
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0x29FFFFFF),
                border: Border.all(color: DrColors.gold.withValues(alpha: 0.7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Color(0xFFFFB347),
                    size: 20,
                  ),
                  Text(
                    'x${view.streak}',
                    style: const TextStyle(
                      color: DrColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
