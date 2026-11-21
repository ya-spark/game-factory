/// Difficulty settings shared by the shared minigames. Pure Dart.
library;

import 'quiz_session.dart';

/// How a minigame plays for a child. Younger: no timer, no failing, a gentle retry, pictures
/// when the item has them. Older: text and a gentle timer. [harder] (Champion) tightens it.
class MiniGameLevel {
  const MiniGameLevel({required this.older, this.harder = false});
  const MiniGameLevel.younger() : older = false, harder = false;
  const MiniGameLevel.older({this.harder = false}) : older = true;

  /// Years 3 and up.
  final bool older;
  final bool harder;

  bool get timed => older;
}

/// Gentle score: 10 per right answer, plus a small streak bonus for the older level.
int scoreForAnswer({required int streak, required bool older}) =>
    10 + (older ? (streak.clamp(0, 5) * 2) : 0);

/// The level for a session: years 0 to 2 are younger, the rest older. [harder] is Champion's.
MiniGameLevel levelForSession(QuizSession s, {bool harder = false}) {
  final year = s.items.isEmpty ? 3 : s.items.first.year;
  return year <= 2
      ? const MiniGameLevel.younger()
      : MiniGameLevel.older(harder: harder);
}
