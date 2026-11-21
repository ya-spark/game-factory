# Equation builder (game package `game_equation_builder`)

Status: BUILT. The game lives once in `game-factory/games/equation_builder/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/equation_builder_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/equation_builder_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Build a sum from the tiles so that it equals the target number.
- Any sum that works is a right answer.
- Tips:
  - Start with the biggest tile that fits.
  - Try different tiles if you get stuck.

## From the app spec
- Levels: Foundation to Year 6 see every game above except Tug of war, Equation builder and Word search and
