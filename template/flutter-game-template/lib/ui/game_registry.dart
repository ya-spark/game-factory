import '../engine/engine.dart';
import 'minigames/balloon_pop_screen.dart';
import 'minigames/cloze_fix_screen.dart';
import 'minigames/door_runner_screen.dart';
import 'minigames/equation_builder_screen.dart';
import 'minigames/flash_review_screen.dart';
import 'minigames/true_false_screen.dart';
import 'minigames/tug_of_war_screen.dart';
import 'minigames/word_grid_screen.dart';
import 'quick_quiz_screen.dart';

/// The minigames of this app. A generated game adds its own games here (one `RegistryEntry` per
/// game, with the modes and year levels it supports). Quick quiz is in every learning game.
final MiniGameRegistry appGames = MiniGameRegistry([
  RegistryEntry(quickQuizGame),
  // Shared minigames (Game mode only). An app chooses which to keep; Champion uses
  // `doorRunnerGameFor(harder: true)` and `balloonPopGameFor(harder: true)`.
  RegistryEntry(doorRunnerGame),
  RegistryEntry(balloonPopGame),
  // Tug of war is coin-locked (Game mode), True or false is free (both modes), Flash review is
  // Study mode only and free. Champion uses the `...For(harder: true)` builders.
  RegistryEntry(tugOfWarGame),
  RegistryEntry(trueFalseGame),
  RegistryEntry(flashReviewGame),
  // Equation builder, Cloze fix and Word grid are free with ads, Game and Study mode. They
  // appear only when enough items of their types are open. Champion uses `...For(harder: true)`.
  RegistryEntry(equationBuilderGame),
  RegistryEntry(clozeFixGame),
  RegistryEntry(wordGridGame),
]);
