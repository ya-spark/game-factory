import 'rules/solitaire_rules.dart';

/// The daily puzzle's tier -> level tables of this game (the hub's DailyPuzzle aliases them).
/// Solitaire presets by tier. Only the winnable presets can be a daily deal (the solver must
/// prove it), so Easy (draw one) early in the week and Hard (draw three) at the weekend.
const List<SolitaireLevel> solitaireDailyLevels = [
  SolitaireLevel.easy,
  SolitaireLevel.easy,
  SolitaireLevel.hard,
  SolitaireLevel.hard,
];
