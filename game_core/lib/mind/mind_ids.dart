import 'package:flutter/widgets.dart';

/// Test IDs of the calm and arcade parts; [game] is the game id. The strings are the contract.
abstract final class MindIds {
  static Key zenResults(String game) => Key('$game.result.zen');
  static Key zenNote(String game) => Key('$game.zenNote');
  static Key calmLevel(String game, String level) => Key('$game.level.$level');
  static Key calmBanner(String game, String where) =>
      Key('$game.banner.$where');
  static Key calmControl(String game, String name) => Key('$game.$name');
  static Key calmResultStars(String game) => Key('$game.result.stars');
  static Key arcade(String game, String name) => Key('$game.$name');
  static Key arcadeBanner(String game, String where) =>
      Key('$game.banner.$where');
}
