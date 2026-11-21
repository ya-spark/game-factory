import 'package:flutter/widgets.dart';

/// MemoryMatch's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class MemoryMatchIds {
  static const matchScreen = Key('match.screen');
  static const matchExit = Key('match.exit');
  static const matchStars = Key('match.stars');
  static const matchProgress = Key('match.progress');
  static const matchSpeak = Key('match.speak');
  static Key matchCard(int i) => Key('match.card.$i');
  static const matchFeedback = Key('match.feedback');
  static const matchNext = Key('match.next');
  static const matchPrompt = Key('match.prompt');
  static const matchSummary = Key('match.summary');
  static const matchTimer = Key('match.timer');
}
