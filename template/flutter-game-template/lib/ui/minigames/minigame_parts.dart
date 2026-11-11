import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/speech/speech_service.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Parts shared by the Memory match and Sort into bins screens (views only; the rules are pure
/// Dart under `lib/engine/minigames/`).

/// The year level of the interface: the theme's level when there is one, else older.
bool isYoungerLevel(BuildContext context) =>
    ThemeTokens.maybeOf(context)?.level == InterfaceLevel.younger;

/// True when the theme or the system asks for less motion.
bool reduceMotionOf(BuildContext context) =>
    (ThemeTokens.maybeOf(context)?.reduceMotion ?? false) ||
    MediaQuery.maybeOf(context)?.disableAnimations == true;

/// Reads aloud on request. Resolves the reader from the [ServicesScope] when not given.
ReadAloud? resolveReader(
  BuildContext context,
  ReadAloud? given,
  RecordedClipPlayer? clip,
) {
  if (given != null) return given;
  final services = context
      .dependOnInheritedWidgetOfExactType<ServicesScope>()
      ?.services;
  return services == null
      ? null
      : ReadAloud(speech: services.speech, recorded: clip);
}

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
              child: const Text('Done'),
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
