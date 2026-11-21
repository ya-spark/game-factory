/// Wingy: a one-tap flyer. A container shows the game screen and provides a [WingyServices]
/// (profile, ads, share, leaderboard, analytics, config) above it with [WingyServicesScope].
/// Spec: `docs/SPEC.md`.
library;

export 'src/core/audio/audio_service.dart';

export 'package:game_core/kit/audio/voice_arbiter.dart';

export 'src/core/clock.dart';
export 'src/core/retention/achievements.dart';
export 'src/core/retention/daily_challenges.dart';
export 'src/core/retention/daily_reward.dart';
export 'src/core/retention/streaks.dart';
export 'src/core/save/save_data.dart';
export 'src/core/skins/flyer_skins.dart';
export 'src/core/tips/tip_service.dart';
export 'src/game/flame/wingy_game.dart';
export 'src/game/flame/wingy_painter.dart';
export 'src/game/rules/gap_generator.dart';
export 'src/game/rules/spire.dart';
export 'src/game/rules/wingy_run.dart';
export 'src/game/rules/world.dart';
export 'src/game/tips.dart';
export 'src/host/ad_service.dart';
export 'src/host/profile_store.dart';
export 'src/host/routes.dart';
export 'src/host/services.dart';
export 'src/ui/game_over_panel.dart';
export 'src/ui/game_screen.dart';
export 'src/ui/home_hero.dart';
export 'src/ui/share_card.dart';
export 'src/ui/test_ids.dart';
export 'src/ui/widgets.dart';
