# game_domino_chain

Domino chain (was Series builder): one of the games in `game-factory/games/`; apps and the web are containers that list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/domino_chain.dart` (`dominoChainGame`, `dominoChainGameFor(hard:)`, `dominoChainId`, `DominoChainScreen`, the rules).
- A container depends on this package and on `game_core` at one pinned commit of `game-factory` (see `../door_runner/README.md` for the pubspec lines) and provides a `GameHost`.
- Renamed from `series_builder` (owner rule 2026-11-22: folder, package and id are the name). The web moves old saved scores through `renamedGameIds` (game_core) and builds the paused apps with `games-web/scripts/patch_renamed_games.py`.
