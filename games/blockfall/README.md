# game_blockfall

Blockfall. One of the games in `game-factory/games/`; apps and the web are containers that show it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/blockfall.dart` (`GameScreen`, `BlockfallServices`, `BlockfallServicesScope`, `SaveData`, ...).
- Needs Flutter, Flame, audioplayers and `game_core` (shared narrator voice and ambience assets). A container adds `game_blockfall` as a git dependency at one commit of `game-factory`, pins `game_core` with `dependency_overrides` to the same commit, and provides a `BlockfallServices` with `BlockfallServicesScope` above the game.
- Sounds are package assets (`packages/game_core/assets/audio/...`); players use their own `AudioCache(prefix: '')`. Check sound on a device after changing this.
