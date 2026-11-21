/// Test support for blockfall: a fake host and the game's bots and harness. Containers use it in their own
/// tests of the game (add `flutter_test`, which this library imports).
library;

export 'src/testing/blockfall_bot.dart';
export 'src/testing/blockfall_scenario.dart';
export 'src/testing/fake_host.dart';
export 'src/testing/game_harness.dart';
