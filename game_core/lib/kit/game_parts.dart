/// Parts shared by the games: level and motion settings, read-aloud, a seconds ticker, the round summary.
/// The container's settings come from the [GameHost]; nothing here imports an app.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../host/game_host.dart';
import 'keys/keys.dart';

/// The younger interface level (the container decides; false when there is no host).
bool isYoungerLevel(BuildContext context) =>
    GameHostScope.of(context).youngerLevel(context);

/// True when the container or the system asks for less motion.
bool reduceMotionOf(BuildContext context) =>
    GameHostScope.of(context).reduceMotion(context) ||
    MediaQuery.maybeOf(context)?.disableAnimations == true;

/// Reads aloud on request: [given] (tests) or the container's reader.
GameReadAloud? resolveReader(BuildContext context, GameReadAloud? given) =>
    given ?? GameHostScope.of(context).readAloud(context);

/// Counts seconds while mounted. Stops by itself; never runs for games without a timer.
class SecondsTicker {
  SecondsTicker(this.onTick);
  final void Function() onTick;
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;

  int get seconds => _watch.elapsed.inSeconds;

  void start() {
    _watch.start();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  void stop() {
    _watch.stop();
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    stop();
    _watch.reset();
  }
}

/// The end-of-round summary shared by both games.
class MiniGameSummary extends StatelessWidget {
  const MiniGameSummary({
    super.key,
    required this.summaryKey,
    required this.starsKey,
    required this.doneKey,
    required this.correct,
    required this.answered,
    required this.stars,
    required this.showStars,
    required this.onDone,
  });
  final Key summaryKey;
  final Key starsKey;
  final Key doneKey;
  final int correct;
  final int answered;
  final int stars;
  final bool showStars;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: summaryKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              label: 'Round finished. $correct of $answered done.',
              child: Text(
                '$correct of $answered done',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (showStars) ...[
              const SizedBox(height: 12),
              Text(
                '$stars stars earned',
                key: starsKey,
                style: theme.textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: doneKey,
              onPressed: onDone,
              child: KeyedText(
                'Done',
                GameAction.action,
                alsoSpace: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String clock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The text read for a question: the prompt, then the options numbered.
String questionReadout(String prompt, List<String> options) {
  final b = StringBuffer(prompt);
  for (var i = 0; i < options.length; i++) {
    b.write(' Option ${i + 1}. ${options[i]}.');
  }
  return b.toString();
}
