/// Vendored learning engine, content part (issue 1A).
///
/// Self-contained: imports only Dart, `package:yaml`, `package:crypto` and
/// `package:cryptography`, and the `lib/core/` interfaces if it ever needs them.
/// It is copied into each game by the sync script (issue 1C).
library;

export 'content/catalogue.dart';
export 'content/content_source.dart';
export 'content/csv.dart';
export 'content/csv_import.dart';
export 'content/expression.dart';
export 'content/format_limits.dart';
export 'content/index.dart';
export 'content/mastery.dart';
export 'content/models.dart';
export 'content/numeric.dart';
export 'content/pool_report.dart';
export 'content/progress.dart';
export 'content/repository.dart';
export 'content/skills.dart';
export 'content/spelling.dart';
export 'content/topic_map.dart';
export 'content/trail.dart';
export 'content/validator.dart';

// Settings and the grown-ups' progress view (pure Dart).
export 'family/activity_log.dart';
export 'family/exam_session.dart';
export 'family/play_time.dart';
export 'family/progress_report.dart';
export 'family/reminder_plan.dart';
export 'family/text_size.dart';
export 'stats/game_stats.dart';
export 'mind/cognitive_skills.dart';

// Issue 1C1: minigames, rewards, AI tutor hook.
export 'ai/ai_tutor.dart';
export 'minigames/how_to_play_catalogue.dart';
export 'minigames/minigame.dart';
export 'minigames/minigame_level.dart';
export 'minigames/quick_quiz.dart';
export 'minigames/quiz_session.dart';
export 'rewards/goal_preset.dart';
export 'rewards/rewards.dart';
