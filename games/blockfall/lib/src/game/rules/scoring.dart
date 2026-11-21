/// Pure scoring helpers. All numbers come from the spec (section 3).
const List<int> lineBaseScores = [0, 100, 300, 500, 800];

const int linesPerLevel = 10;
const int comboStep = 50;
const int perfectClearBonus = 1000;
const int softDropPointsPerRow = 1;
const int hardDropPointsPerRow = 2;
const int prismCoinCapPerGame = 40;
const int prismEveryNthPiece = 4;

/// Special cells on dealt pieces: every 9th piece a Boom block, every 13th a golden block
/// (gold wins over boom, boom over prism when they fall on the same piece).
const int boomEveryNthPiece = 9;
const int goldEveryNthPiece = 13;

/// Each extra cell a Boom block removes scores this times the level.
const int blastCellPoints = 5;

/// Gold Rush: line, combo, back-to-back and perfect-clear scores are multiplied for
/// [rushSeconds] of play time; another golden block adds [rushSeconds] up to [rushCapSeconds].
const int rushMultiplier = 2;
const double rushSeconds = 10;
const double rushCapSeconds = 30;

int levelForLines(int totalLines) => 1 + totalLines ~/ linesPerLevel;

/// Lines still needed to reach the next level.
int goalForLines(int totalLines) => linesPerLevel - totalLines % linesPerLevel;

/// Score of one line clear, without combo and perfect clear bonuses.
///
/// [rows] is the number of cleared rows (1..4), [prismRows] how many of them contain a
/// prism (their share is doubled), [level] the level before any level-up from this clear.
int lineClearScore({
  required int rows,
  required int prismRows,
  required int level,
  required bool backToBack,
}) {
  final base = lineBaseScores[rows] * level;
  final extra = (base * prismRows / rows).round();
  var total = base + extra;
  if (backToBack && rows == 4) total = total * 3 ~/ 2;
  return total;
}

int comboBonus({required int combo, required int level}) =>
    combo >= 2 ? comboStep * (combo - 1) * level : 0;
