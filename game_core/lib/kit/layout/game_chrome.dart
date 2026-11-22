import 'package:flutter/material.dart';

import '../keys/key_labels.dart';

/// The small controls over a game, instead of a title bar: exit on the left, the game's name,
/// and a pause button while a round is on. Keys come from the game (hard rule 4).
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.title,
    required this.onExit,
    required this.exitKey,
    this.onPause,
    this.pauseKey,
    this.paused = false,
    this.trailing = const [],
    this.exitKeyName = 'L',
    this.pauseKeyName = 'Esc',
  });

  /// The keys printed on the buttons (B-09). The game must wire them: L leaves, Esc pauses.
  final String exitKeyName;
  final String pauseKeyName;

  final String title;
  final VoidCallback onExit;
  final Key exitKey;

  /// Null hides the pause button (no round is on).
  final VoidCallback? onPause;
  final Key? pauseKey;
  final bool paused;

  /// Extra controls on the right (score, read aloud).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KeyedIconButton(
          key: exitKey,
          tooltip: 'Leave $title',
          icon: Icons.close,
          keyName: exitKeyName,
          onPressed: onExit,
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...trailing,
        if (onPause != null)
          KeyedIconButton(
            key: pauseKey,
            tooltip: paused ? 'Resume' : 'Pause',
            icon: paused ? Icons.play_arrow : Icons.pause,
            keyName: pauseKeyName,
            onPressed: onPause,
          ),
      ],
    );
  }
}

/// Covers the game while it is paused.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    this.resumeKey,
    this.overlayKey,
    this.onLeave,
    this.leaveKey,
    this.resumeKeyName = 'Esc / Space',
    this.leaveKeyName = 'L',
  });

  /// The keys printed on the buttons (B-09). The game must wire them: Esc or Space resumes, L leaves.
  final String resumeKeyName;
  final String leaveKeyName;

  final VoidCallback onResume;
  final Key? resumeKey;

  /// Key of the covering box (tests look for it).
  final Key? overlayKey;

  /// Adds a "Leave game" button under Resume (null: no button).
  final VoidCallback? onLeave;
  final Key? leaveKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        key: overlayKey,
        color: theme.colorScheme.scrim.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paused',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: resumeKey,
                onPressed: onResume,
                child: Text(withKey('Resume', resumeKeyName)),
              ),
              if (onLeave != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: leaveKey,
                  onPressed: onLeave,
                  child: Text(
                    withKey('Leave game', leaveKeyName),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
