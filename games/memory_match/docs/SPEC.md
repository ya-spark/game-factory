# Memory match (game package `game_memory_match`)

Status: BUILT. The game lives once in `game-factory/games/memory_match/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/memory_match_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/memory_match_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Flip two cards at a time to find the matching pairs. Each pair is a question and its answer.
- Match every pair to finish the board.
- Tips:
  - Try to remember where each card is.
  - Younger levels have no timer. Older levels add a gentle clock.

## Rules and behaviour (from the app's engine notes at the move)
- Memory match (`memoryMatchGame`, view `lib/ui/minigames/memory_match_screen.dart`, rules
