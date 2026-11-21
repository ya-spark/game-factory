/// Which theme is showing. Pure Dart: the themes themselves (painters) live in
/// `lib/game/themes/`; the rules only know ids and when they change.
abstract final class ThemeRotation {
  /// Rotation order (table order in the spec); wraps around after the last.
  static const List<String> ids = [
    'gems',
    'cakes',
    'wood',
    'candy',
    'ocean',
    'space',
  ];

  /// Rotation index for a game that started at [startIndex] and is on [level]
  /// (the theme changes on every level-up).
  static int indexFor(int startIndex, int level) =>
      (startIndex + (level < 1 ? 0 : level - 1)) % ids.length;

  static String idFor(int startIndex, int level) =>
      ids[indexFor(startIndex, level)];
}
