import 'package:flutter/widgets.dart';

/// Test IDs shared by the games built on the common screens; [g] is the game id, so a game's keys
/// read `<game>.start`, `<game>.choice.0` and so on. A game's own extra keys live in the game.
abstract final class GameIds {
  static Key mgScreen(String g) => Key('$g.screen');
  static Key mgIntro(String g) => Key('$g.intro');
  static Key mgStart(String g) => Key('$g.start');
  static Key mgExit(String g) => Key('$g.exit');
  static Key mgPrompt(String g) => Key('$g.prompt');
  static Key mgProgress(String g) => Key('$g.progress');
  static Key mgScore(String g) => Key('$g.score');
  static Key mgSpeak(String g) => Key('$g.speak');
  static Key mgTimer(String g) => Key('$g.timer');
  static Key mgField(String g) => Key('$g.field');
  static Key mgChoice(String g, int i) => Key('$g.choice.$i');
  static Key mgFeedback(String g) => Key('$g.feedback');
  static Key mgNext(String g) => Key('$g.next');
  static Key mgResults(String g) => Key('$g.results');
  static Key mgStars(String g) => Key('$g.stars');
  static Key mgDone(String g) => Key('$g.done');
  static Key mgBanner(String g) => Key('$g.banner');
  static Key mgPause(String g) => Key('$g.pause');
  static Key mgPaused(String g) => Key('$g.paused');
  static Key mgResume(String g) => Key('$g.resume');
  static Key mgRope(String g) => Key('$g.rope');
  static Key mgCard(String g) => Key('$g.card');
  static Key mgFlip(String g) => Key('$g.flip');
  static Key mgKnew(String g) => Key('$g.knew');
  static Key mgNotYet(String g) => Key('$g.not_yet');
}
