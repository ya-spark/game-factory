# game_wingy

Wingy: a one-tap flyer. One of the games in `game-factory/games/`; apps and the web are containers that show it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/wingy.dart` (`GameScreen`, `HomeHero`, `WingyServices`, `WingyServicesScope`, `SaveData`, ...).
- Wingy needs only Flutter, Flame and audioplayers. A container adds `game_wingy` as a git dependency at one commit of `game-factory` and provides a `WingyServices` with `WingyServicesScope` above the game.
- Sounds are package assets (`packages/game_wingy/assets/...`); players use their own `AudioCache(prefix: '')`. Check sound on a device after changing this.
