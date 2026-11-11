import '../engine/engine.dart';
import 'minigames/balloon_pop_screen.dart';
import 'minigames/door_runner_screen.dart';
import 'quick_quiz_screen.dart';

/// The minigames of this app. A generated game adds its own games here (one `RegistryEntry` per
/// game, with the modes and year levels it supports). Quick quiz is in every learning game.
final MiniGameRegistry appGames = MiniGameRegistry([
  RegistryEntry(quickQuizGame),
  // Shared minigames (Game mode only). An app chooses which to keep; Champion uses
  // `doorRunnerGameFor(harder: true)` and `balloonPopGameFor(harder: true)`.
  RegistryEntry(doorRunnerGame),
  RegistryEntry(balloonPopGame),
]);
