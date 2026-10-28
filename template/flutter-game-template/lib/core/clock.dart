/// Injectable time source so tests (and the clock guard) control "now".
typedef Clock = DateTime Function();

/// Calendar day number (days since 1970-01-01) of the *local* date of [t].
int dayIndexOf(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Backwards-clock guard.
///
/// Rewards, streaks and challenges depend on the date. If the player sets the device clock
/// back, naive code would let them re-claim rewards. We persist the latest time ever seen
/// and never let "trusted now" go below it. Trade-off: moving the clock far *forward* and
/// back locks daily features until the real date catches up; acceptable for an offline game.
class ClockGuard {
  const ClockGuard();

  /// Returns the time to use, given the device time [now] and the persisted [lastSeenMs]
  /// (UTC milliseconds, 0 if none).
  DateTime trusted(DateTime now, int lastSeenMs) {
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMs);
    return now.isBefore(lastSeen) ? lastSeen : now;
  }

  /// True when the device clock is behind the last time we saw.
  bool isTampered(DateTime now, int lastSeenMs) =>
      now.millisecondsSinceEpoch < lastSeenMs;
}
