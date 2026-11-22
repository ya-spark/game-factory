import 'package:flutter/material.dart';

import '../door_runner_ids.dart';
import 'door_runner_style.dart';

/// Touch only: hold this bar to slow the doors (the Down key on a keyboard).
class DoorRunnerSlowZone extends StatefulWidget {
  const DoorRunnerSlowZone({super.key, required this.onSlow});
  final void Function(bool held) onSlow;

  @override
  State<DoorRunnerSlowZone> createState() => _DoorRunnerSlowZoneState();
}

class _DoorRunnerSlowZoneState extends State<DoorRunnerSlowZone> {
  bool _down = false;

  void _set(bool v) {
    setState(() => _down = v);
    widget.onSlow(v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Semantics(
        button: true,
        label: 'Hold to slow the doors',
        child: Listener(
          key: DoorRunnerIds.slow,
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _set(true),
          onPointerUp: (_) => _set(false),
          onPointerCancel: (_) => _set(false),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _down ? 0.24 : 0.12),
              border: Border.all(
                color: DrColors.lilac.withValues(alpha: 0.8),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: drGlow(
                DrColors.lilac,
                alpha: _down ? 0.6 : 0.3,
                blur: 14,
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_downward, color: DrColors.cyan),
                  SizedBox(width: 8),
                  Text(
                    'Hold to slow down',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Covers the field while paused. The game behind does not move.
class DoorRunnerPauseOverlay extends StatelessWidget {
  const DoorRunnerPauseOverlay({
    super.key,
    required this.onResume,
    required this.onQuit,
  });
  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xB30B0626),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              letterSpacing: 6,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: DrColors.lilac, blurRadius: 22)],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 300,
            child: DrButton(
              key: DoorRunnerIds.resume,
              colors: const [Color(0xFFFFB02E), Color(0xFFFF6B3D)],
              onPressed: onResume,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white),
                  SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Resume (Esc / Space)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: DoorRunnerIds.quit,
            onPressed: onQuit,
            child: Text(
              'Quit (L)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big 3-2-1 before play starts or resumes (older level), like Wingy's countdown.
class DoorRunnerCountdown extends StatelessWidget {
  const DoorRunnerCountdown({super.key, required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: DrColors.cyan, blurRadius: 28)],
          ),
        ),
      ),
    );
  }
}

/// The start prompt before the first question: "TAP TO RUN".
class DoorRunnerReadyPrompt extends StatelessWidget {
  const DoorRunnerReadyPrompt({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onStart,
      child: const Center(
        child: Text(
          'TAP TO RUN',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 22,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
