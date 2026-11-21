/// Seconds per row fall step by level (levels above 15 use the level 15 value).
const List<double> gravityTable = [
  1.00,
  0.80,
  0.65,
  0.52,
  0.42,
  0.33,
  0.26,
  0.20,
  0.16,
  0.12,
  0.10,
  0.08,
  0.065,
  0.05,
  0.04,
];

double secondsPerRowForLevel(int level) {
  final i = level.clamp(1, gravityTable.length) - 1;
  return gravityTable[i];
}

/// Soft drop falls at 20x the current gravity, never faster than 0.03 s/row.
const double softDropFactor = 20;
const double softDropMinStep = 0.03;

double softDropStep(double secondsPerRow) {
  final s = secondsPerRow / softDropFactor;
  return s < softDropMinStep ? softDropMinStep : s;
}

/// Lock delay and its restart budget.
const double lockDelaySeconds = 0.5;
const int maxLockRestarts = 10;
