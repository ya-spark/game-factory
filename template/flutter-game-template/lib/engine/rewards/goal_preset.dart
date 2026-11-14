import 'rewards.dart';

/// A parent-chosen goal size per child (C4). Only the item counts change; the coin payouts and
/// the weekly coin cap stay as configured, so a parent cannot inflate coins by choosing Light.
enum GoalPreset {
  light('Light', 3, 15),
  steady('Steady', 5, 25),
  big('Big', 8, 40);

  const GoalPreset(this.label, this.dailyItems, this.weeklyItems);
  final String label;
  final int dailyItems;
  final int weeklyItems;

  /// Steady equals the app.config.yaml defaults.
  static const GoalPreset defaultPreset = steady;

  static GoalPreset parse(Object? v) {
    for (final p in values) {
      if (p.name == v) return p;
    }
    return defaultPreset;
  }
}

extension GoalPresetRewards on RewardsConfig {
  /// This config with the item goals of [preset]. Coins, cap and everything else unchanged.
  RewardsConfig withPreset(GoalPreset preset) => RewardsConfig(
    starsEnabled: starsEnabled,
    perFirstPass: perFirstPass,
    topicBonus: topicBonus,
    streakBonus: streakBonus,
    weeklyCapPerChild: weeklyCapPerChild,
    topicCoins: topicCoins,
    streakMilestones: streakMilestones,
    dailyGoalItems: preset.dailyItems,
    dailyGoalCoins: dailyGoalCoins,
    weeklyGoalItems: preset.weeklyItems,
    weeklyGoalCoins: weeklyGoalCoins,
    newQuestionsGoal: newQuestionsGoal,
    newQuestionsCoins: newQuestionsCoins,
    newTopicCoins: newTopicCoins,
    reviseGoal: reviseGoal,
    reviseCoins: reviseCoins,
  );
}
