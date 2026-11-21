# True or false (game package `game_true_false`)

Status: BUILT. The game lives once in `game-factory/games/true_false/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/true_false_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/true_false_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Read each statement, then choose True or False.
- After each answer you often see why.
- Tips:
  - Read the whole statement before you answer.
  - Look for words like always, never and only.
