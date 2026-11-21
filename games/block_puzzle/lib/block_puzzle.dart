/// BlockPuzzle: a game. A container shows the game screen and provides a [BlockPuzzleServices] above it
/// with [BlockPuzzleServicesScope]. Spec: `docs/SPEC.md`.
library;

export 'src/core/audio/audio_service.dart';

export 'package:game_core/kit/audio/voice_arbiter.dart';

export 'src/core/clock.dart';
export 'src/core/retention/achievements.dart';
export 'src/core/retention/daily_challenges.dart';
export 'src/core/retention/daily_reward.dart';
export 'src/core/retention/streaks.dart';
export 'src/core/save/save_data.dart';
export 'src/game/flame/block_puzzle_game.dart';
export 'src/game/flame/special_overlay.dart';
export 'src/game/layout.dart';
export 'src/game/rules/best_move.dart';
export 'src/game/rules/board.dart';
export 'src/game/rules/boosts.dart';
export 'src/game/rules/game_state.dart';
export 'src/game/rules/piece.dart';
export 'src/game/rules/piece_generator.dart';
export 'src/game/rules/snap.dart';
export 'src/game/rules/start_board.dart';
export 'src/game/rules/theme_rotation.dart';
export 'src/game/themes/block_theme.dart';
export 'src/game/tips.dart';
export 'src/host/ad_service.dart';
export 'src/host/profile_store.dart';
export 'src/host/routes.dart';
export 'src/host/services.dart';
export 'src/ui/best_move_dialog.dart';
export 'src/ui/boost_widgets.dart';
export 'src/ui/game_over_panel.dart';
export 'src/ui/game_screen.dart';
export 'src/ui/home_hero.dart';
export 'src/ui/share_card.dart';
export 'src/ui/test_ids.dart';
export 'src/ui/theme_background.dart';
export 'src/ui/widgets.dart';
