# Word builder (game package `game_word_builder`)

Status: BUILT. The game lives once in `game-factory/games/word_builder/` (SH1, owner 2026-11-21); apps and the web list it in their registry and bring content, theme and services. Nothing is copied. Rules in `lib/src/rules/`, the screen in `lib/src/word_builder_screen.dart`, test IDs in `GameIds` (game_core) and `lib/src/word_builder_ids.dart` where the game has its own. It asks its container only through `GameHost` (`game_core/lib/host`).

The text below was collected from the apps' docs when the game moved; refine it here from now on (this file is the only copy of the game's behaviour).

## How to play (as shown to the child)
- Build the answer from the letter tiles. Use the hint if you need it.
- After a miss, the correct spelling is shown.
- Tips:
  - Say the word to yourself as you build it.
  - Older levels build the word and press Check.
