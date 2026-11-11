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
export 'content/index.dart';
export 'content/models.dart';
export 'content/numeric.dart';
export 'content/pool_report.dart';
export 'content/progress.dart';
export 'content/repository.dart';
export 'content/spelling.dart';
export 'content/validator.dart';

// Issue 1C1: minigames, rewards, AI tutor hook.
export 'ai/ai_tutor.dart';
export 'minigames/balloon_pop/rules/balloon_pop_rules.dart';
export 'minigames/door_runner/rules/door_runner_rules.dart';
export 'minigames/memory_match/rules/memory_match_rules.dart';
export 'minigames/minigame.dart';
export 'minigames/minigame_level.dart';
export 'minigames/quick_quiz.dart';
export 'minigames/quiz_session.dart';
export 'minigames/sort_bins/rules/sort_bins_rules.dart';
export 'rewards/rewards.dart';
