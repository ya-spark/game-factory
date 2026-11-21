/// Shooter rules: targets drift across a gallery and the player shoots the right answer.
/// Plays `mcq` (the options) and `category` (which group is this item in?). Pure Dart.
library;

import 'dart:math';

import 'package:game_core/engine/engine.dart';

const String shooterId = 'shooter';

class ShooterSettings {
  const ShooterSettings({
    required this.maxTargets,
    required this.secondsPerQuestion,
    required this.swaySeconds,
    required this.large,
  });
  final int maxTargets;

  /// Time to shoot; 0 means no timer.
  final int secondsPerQuestion;

  /// Seconds a target takes to sway across and back.
  final double swaySeconds;
  final bool large;

  factory ShooterSettings.forLevel(MiniGameLevel l) {
    if (!l.older) {
      return const ShooterSettings(
        maxTargets: 3,
        secondsPerQuestion: 0,
        swaySeconds: 8,
        large: true,
      );
    }
    return ShooterSettings(
      maxTargets: 4,
      secondsPerQuestion: l.harder ? 15 : 25,
      swaySeconds: l.harder ? 3.5 : 5,
      large: false,
    );
  }
}

/// One target: its label and whether it is the right answer.
class Target {
  const Target(this.label, this.correct);
  final String label;
  final bool correct;
}

/// The entry of a `category` item the game asks about. Fixed for an item (by its id), so the
/// prompt and the targets always agree.
Map<String, Object?>? categoryEntry(ContentItem item) {
  final items = item.json['items'];
  if (item.type != ItemType.category || items is! List || items.isEmpty) {
    return null;
  }
  final e = items[item.id.hashCode.abs() % items.length];
  return e is Map ? e.cast<String, Object?>() : null;
}

/// The question shown for an item: the `mcq` prompt, or which group a category entry is in.
String shooterPrompt(ContentItem item) {
  if (item.type == ItemType.category) {
    final e = categoryEntry(item);
    return e == null ? '' : 'Shoot the group for "${e['text']}".';
  }
  return mcqPrompt(item);
}

/// The targets for one question, at most [max]. Null when the item cannot be played.
List<Target>? layoutTargets(ContentItem item, int max, Random random) {
  if (item.type == ItemType.mcq) {
    final options = mcqOptions(item);
    final right = mcqCorrectIndexes(item);
    if (right.length != 1 || options.length < 2) return null;
    if (right.first < 0 || right.first >= options.length) return null;
    final wrong = [
      for (var i = 0; i < options.length; i++)
        if (!right.contains(i)) i,
    ]..shuffle(random);
    final n = min(max, options.length);
    return [
      Target(options[right.first], true),
      for (final i in wrong.take(n - 1)) Target(options[i], false),
    ]..shuffle(random);
  }
  if (item.type == ItemType.category) {
    final e = categoryEntry(item);
    final cats = [
      for (final c in (item.json['categories'] as List? ?? const [])) '$c',
    ];
    if (e == null || cats.length < 2 || !cats.contains('${e['category']}')) {
      return null;
    }
    final wrong = [
      for (final c in cats)
        if (c != '${e['category']}') c,
    ]..shuffle(random);
    final n = min(max, cats.length);
    return [
      Target('${e['category']}', true),
      for (final c in wrong.take(n - 1)) Target(c, false),
    ]..shuffle(random);
  }
  return null;
}

/// Whether the shooter can play [item]: a single-answer `mcq` of 2 to 4 options or a `category`
/// item of 2 to 4 groups. Size class is the game's `sizes` limit (short items only).
bool shooterPlaysItem(ContentItem item) =>
    layoutTargets(item, 4, Random(0)) != null;
