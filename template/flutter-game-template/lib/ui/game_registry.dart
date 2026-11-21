import 'package:game_core/engine/engine.dart';

import 'package:game_flash_review/flash_review.dart';

import 'quick_quiz_screen.dart';

/// The games of this container. `scripts/new_game.py --games a,b` adds one `RegistryEntry` per
/// game package (from `game-factory/games/`) with the modes and year levels it supports. Quick
/// quiz is in every learning game.
final MiniGameRegistry appGames = MiniGameRegistry([
  RegistryEntry(quickQuizGame),
  RegistryEntry(flashReviewGame),
]);
