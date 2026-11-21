import 'rules/mahjong_rules.dart';

/// The daily puzzle's tier -> level tables of this game (the hub's DailyPuzzle aliases them).
/// Mahjong tiers by tier of the day (M3): hints and shuffles follow the tier.
const List<MahjongTier> mahjongDailyTiers = [
  MahjongTier.easy,
  MahjongTier.medium,
  MahjongTier.hard,
  MahjongTier.expert,
];

/// Which size rank (0 = smallest) of [mahjongLayoutsOf] the tier plays: the smallest layout for
/// Easy, Hard and Expert, the fifth smallest of the first nine for Medium.
const List<int> mahjongDailyRank = [0, 4, 0, 0];

/// The layouts of [tier], smallest first.
List<MahjongLayout> mahjongLayoutsOf(MahjongTier tier) =>
    [...tier.layouts]
      ..sort((a, b) => a.positions.length.compareTo(b.positions.length));
