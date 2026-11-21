import 'package:flutter/widgets.dart';

/// MemoryMatch's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class MemoryMatchIds {
  static Key matchCard(int i) => Key('match.card.$i');
  static const matchExit = Key('match.exit');
  static const matchFeedback = Key('match.feedback');
  static const matchNext = Key('match.next');
  static const matchProgress = Key('match.progress');
  static const matchPrompt = Key('match.prompt');
  static const matchScreen = Key('match.screen');
  static const matchSpeak = Key('match.speak');
  static const matchStars = Key('match.stars');
  static const matchSummary = Key('match.summary');
  static const matchTimer = Key('match.timer');
}
