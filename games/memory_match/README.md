# game_memory_match

Memory match: one of the games in `game-factory/games/`; apps and the web are containers that list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/memory_match.dart`.
- A container depends on this package and on `game_core` at one pinned commit of `game-factory` (see `../door_runner/README.md` for the pubspec lines) and provides a `GameHost`.
