import 'package:flutter/widgets.dart';

/// The stable test IDs of Parcel train (hard rule 4). The strings are the contract tests rely on.
abstract final class ParcelTrainIds {
  static const screen = Key('parcel_train.screen');
  static const menu = Key('parcel_train.menu');
  static const play = Key('parcel_train.play');
  static const free = Key('parcel_train.free');
  static const howTo = Key('parcel_train.howto');
  static const howToDialog = Key('parcel_train.howto.dialog');
  static const howToClose = Key('parcel_train.howto.close');
  static const wrap = Key('parcel_train.wrap');
  static const best = Key('parcel_train.best');
  static const menuMessage = Key('parcel_train.menu.message');
  static Key course(int i) => Key('parcel_train.course.$i');
  static Key courseStars(int i) => Key('parcel_train.course.$i.stars');
  static const exit = Key('parcel_train.exit');
  static const pause = Key('parcel_train.pause');
  static const paused = Key('parcel_train.paused');
  static const resume = Key('parcel_train.resume');
  static const leave = Key('parcel_train.leave');
  static const field = Key('parcel_train.field');
  static const hud = Key('parcel_train.hud');
  static const parcels = Key('parcel_train.parcels');
  static const score = Key('parcel_train.score');
  static const bumpers = Key('parcel_train.bumpers');
  static const goldenIcon = Key('parcel_train.golden');
  static const stationOpen = Key('parcel_train.station_open');
  static const ready = Key('parcel_train.ready');
  static const derail = Key('parcel_train.derail');
  static const banner = Key('parcel_train.banner');
  static const keys = Key('parcel_train.keys');
  static const pad = Key('parcel_train.pad');
  static Key padKey(String dir) => Key('parcel_train.pad.$dir');
  static const results = Key('parcel_train.results');
  static const resultScore = Key('parcel_train.result.score');
  static const resultStars = Key('parcel_train.result.stars');
  static const resultCoins = Key('parcel_train.result.coins');
  static const next = Key('parcel_train.next');
  static const replay = Key('parcel_train.replay');
  static const again = Key('parcel_train.again');
  static const done = Key('parcel_train.done');
  static const live = Key('parcel_train.live');
}
