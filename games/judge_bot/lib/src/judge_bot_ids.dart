import 'package:flutter/widgets.dart';

/// Judge bot's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class JudgeBotIds {
  static Key lampTrue(String g) => Key('$g.lamp.true');
  static Key lampFalse(String g) => Key('$g.lamp.false');
  static Key ticket(String g) => Key('$g.ticket');
  static Key ticketQuestion(String g) => Key('$g.ticket.question');
  static Key stamp(String g) => Key('$g.stamp');
  static Key robot(String g) => Key('$g.robot');
  static Key streak(String g) => Key('$g.streak');
  static Key bulb(String g, int i) => Key('$g.bulb.$i');
  static Key howTo(String g) => Key('$g.how_to');
  static Key howToButton(String g) => Key('$g.how_to_button');
  static Key howToClose(String g) => Key('$g.how_to_close');
  static Key introHeading(String g) => Key('$g.intro_heading');
  static Key bestStreak(String g) => Key('$g.best_streak');
  static Key judgedRight(String g) => Key('$g.judged_right');
  static Key reviewList(String g) => Key('$g.review');
  static Key review(String g, int i) => Key('$g.review.$i');
  static Key fast(String g) => Key('$g.fast');
  static Key nextKeys(String g) => Key('$g.next_keys');
}
