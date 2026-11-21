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

  /// The theme changes every time this many more lines have been cleared.
  /// Its own constant: not the scoring stage (which steps every 5 lines).
  static const int themeEveryLines = 10;

  /// Rotation index for a game that started at [startIndex] and has cleared [lines] lines.
  static int indexFor(int startIndex, int lines) =>
      (startIndex + lines ~/ themeEveryLines) % ids.length;

  static String idFor(int startIndex, int lines) =>
      ids[indexFor(startIndex, lines)];
}
