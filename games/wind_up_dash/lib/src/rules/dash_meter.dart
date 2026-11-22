/// The spring meter: stars wind it, a full meter absorbs one block hit. Pure Dart.
library;

/// Stars that fill the meter.
const int springStars = 10;

/// How far a brick bounce throws the car back, in units (it also hops, so it clears the brick).
const double bounceBack = 6;

class SpringMeter {
  SpringMeter([this.stars = 0]);

  /// 0 to [springStars].
  int stars;

  bool get full => stars >= springStars;

  /// The bulbs lit on the meter (one per 2 stars, 0 to 5).
  int get bulbs => stars ~/ 2;

  /// Adds a star. Returns true when this star filled the meter.
  bool add() {
    if (full) return false;
    stars++;
    return full;
  }

  /// Uses the stored bounce; false when the meter is not full.
  bool absorb() {
    if (!full) return false;
    stars = 0;
    return true;
  }

  SpringMeter copy() => SpringMeter(stars);
}
