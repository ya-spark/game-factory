import 'package:flutter/material.dart';

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
  });

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
        IconButton(
          key: exitKey,
          tooltip: 'Leave $title',
          icon: const Icon(Icons.close),
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
          IconButton(
            key: pauseKey,
            tooltip: paused ? 'Resume' : 'Pause',
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
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
  });

  final VoidCallback onResume;
  final Key? resumeKey;

  /// Key of the covering box (tests look for it).
  final Key? overlayKey;

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
                child: const Text('Resume'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
