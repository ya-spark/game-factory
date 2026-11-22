# game_equation_builder (Bridge builder)

Bridge builder: one of the games in `game-factory/games/`; apps and the web are containers that list it (SH1, owner 2026-11-21). It is the rewrite (U3, owner 2026-11-22) of the earlier Equation builder. The child sees the title "Bridge builder"; the package, the game id `equation_builder` and the folder keep the old name so saved progress and best scores survive.

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/equation_builder.dart`.
- Rules (pure Dart): `lib/src/rules/equation_builder_rules.dart` (sum, target, tiles; unchanged) and `lib/src/rules/bridge_rules.dart` (slots, stages, scenery, stars).
- Art is drawn in code (`lib/src/ui/bridge_art.dart`, `CustomPainter`); there are no asset files, so nothing to list in `assets/LICENSES.md`. A Figma kit prompt is in `game-studio/docs/art-prompts/bridge-builder-figma-prompt.md`.
- A container depends on this package and on `game_core` at one pinned commit of `game-factory` (see `../door_runner/README.md` for the pubspec lines) and provides a `GameHost`.
