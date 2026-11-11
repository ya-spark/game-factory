import '../engine/engine.dart';
import 'quick_quiz_screen.dart';

/// The minigames of this app. A generated game adds its own games here (one `RegistryEntry` per
/// game, with the modes and year levels it supports). Quick quiz is in every learning game.
final MiniGameRegistry appGames = MiniGameRegistry([
  RegistryEntry(quickQuizGame),
]);
