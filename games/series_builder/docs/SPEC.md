# Series builder (game package `game_series_builder`)

Status: BUILT. The game lives once in `game-factory/games/series_builder/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/series_builder_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/series_builder_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Put the steps in the right order by tapping the tiles one after the other.
- A wrong tile is greyed out and you try again.
- Tips:
  - Find the first step before you start tapping.
  - Older levels add a gentle timer.
