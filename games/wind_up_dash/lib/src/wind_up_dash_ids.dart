import 'package:flutter/widgets.dart';

/// The stable test IDs of Wind-up dash (hard rule 4). The strings are the contract tests rely on.
abstract final class DashIds {
  static const screen = Key('wind_up_dash.screen');
  static const menu = Key('wind_up_dash.menu');
  static const play = Key('wind_up_dash.play');
  static const free = Key('wind_up_dash.free');
  static const howTo = Key('wind_up_dash.howto');
  static const howToDialog = Key('wind_up_dash.howto.dialog');
  static const howToClose = Key('wind_up_dash.howto.close');
  static const best = Key('wind_up_dash.best');
  static const menuMessage = Key('wind_up_dash.menu.message');
  static Key course(int i) => Key('wind_up_dash.course.$i');
  static Key courseStars(int i) => Key('wind_up_dash.course.$i.stars');
  static const exit = Key('wind_up_dash.exit');
  static const pause = Key('wind_up_dash.pause');
  static const paused = Key('wind_up_dash.paused');
  static const resume = Key('wind_up_dash.resume');
  static const leave = Key('wind_up_dash.leave');
  static const field = Key('wind_up_dash.field');
  static const jump = Key('wind_up_dash.jump');
  static const hud = Key('wind_up_dash.hud');
  static const starsCount = Key('wind_up_dash.stars');
  static const score = Key('wind_up_dash.score');
  static const spring = Key('wind_up_dash.spring');
  static const progress = Key('wind_up_dash.progress');
  static const ready = Key('wind_up_dash.ready');
  static const tryAgain = Key('wind_up_dash.try_again');
  static const hint = Key('wind_up_dash.hint');
  static const banner = Key('wind_up_dash.banner');
  static const keys = Key('wind_up_dash.keys');
  static const results = Key('wind_up_dash.results');
  static const resultScore = Key('wind_up_dash.result.score');
  static const resultStars = Key('wind_up_dash.result.stars');
  static const resultCoins = Key('wind_up_dash.result.coins');
  static const next = Key('wind_up_dash.next');
  static const replay = Key('wind_up_dash.replay');
  static const again = Key('wind_up_dash.again');
  static const done = Key('wind_up_dash.done');
  static const live = Key('wind_up_dash.live');
}
