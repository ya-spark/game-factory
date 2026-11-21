# game_snake

Snake: a Mind hub game in `game-factory/games/`; the hubs are containers that list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/snake.dart`.
- Needs Flutter and `game_core` (shared kit, Mind kit and host contract). A container adds `game_snake` as a git dependency at one commit of `game-factory`, pins `game_core` with `dependency_overrides` to the same commit, and provides a `GameHost` (`GameHostScope`) above the game.
