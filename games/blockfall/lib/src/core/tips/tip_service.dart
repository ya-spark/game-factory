import '../../game/tips.dart';

/// Picks the tip of the day from the date. Pure Dart.
class TipService {
  TipService({List<String>? tips}) : tips = tips ?? gameTips;

  final List<String> tips;

  /// The same tip all day, a different one each day.
  String tipOfTheDay(int dayIndex) => tips[dayIndex % tips.length];
}
