# game_wind_up_dash

Wind-up dash (id `wind_up_dash`; was Runner): a toy wind-up car rolls by itself, the child hops it over toy bricks and floor gaps and picks up paper stars. Five courses and a free run. A Mind hub game in `game-factory/games/`; the containers list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/wind_up_dash.dart`.
- Rules (pure Dart, `lib/src/rules/`): `dash_courses.dart` (courses, track), `dash_rules.dart` (the car), `dash_meter.dart` (spring), `dash_stars.dart` (score, coins, course stars). Screen: `lib/src/wind_up_dash_screen.dart`; code art: `lib/src/ui/wind_up_art.dart`.
- Needs Flutter and `game_core` (shared kit, Mind kit and host contract). A container adds `game_wind_up_dash` as a git dependency at one commit of `game-factory`, pins `game_core` with `dependency_overrides` to the same commit, and provides a `GameHost` (`GameHostScope`) above the game.
