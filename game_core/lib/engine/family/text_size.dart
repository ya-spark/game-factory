/// The text size a player picks in Settings. Pure Dart; the UI multiplies the system text scale
/// by [scale].
library;

enum TextSizeChoice {
  small('Small', 0.9),
  normal('Normal', 1.0),
  large('Large', 1.25);

  const TextSizeChoice(this.label, this.scale);
  final String label;
  final double scale;

  static TextSizeChoice parse(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return normal;
  }
}
